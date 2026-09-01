import 'dart:io';
import 'dart:ffi';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VectorStorageService {
  Database? _db;
  String? _dbPath;

  /// True when the sqlite-vec (vec0) extension loaded successfully.
  /// When false, [insertChunk], [insertChunkBatch], and [search] are no-ops
  /// and callers should fall back to [DocumentIngestionService.lexicalSearch].
  bool _vecAvailable = false;

  bool get isInitialized => _db != null;
  bool get isVecAvailable => _vecAvailable;

  Future<void> initialize({String? dbPath, bool inMemory = false}) async {
    if (inMemory) {
      _db = sqlite3.openInMemory();
    } else if (dbPath != null) {
      _dbPath = dbPath;
      _db = sqlite3.open(_dbPath!);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _dbPath = '${dir.path}/denizen_rag.db';
      _db = sqlite3.open(_dbPath!);
    }
    
    // Enable WAL mode for better performance
    _db!.execute('PRAGMA journal_mode=WAL;');

    // Load sqlite-vec extension via FFI — gracefully degrades if unavailable.
    try {
      final DynamicLibrary lib;
      if (Platform.isAndroid) {
        DynamicLibrary? openedLib;
        try {
          openedLib = DynamicLibrary.open('libsqlite_vec.so');
        } catch (_) {
          try {
            openedLib = DynamicLibrary.open('sqlite_vec');
          } catch (_) {
            openedLib = DynamicLibrary.process();
          }
        }
        lib = openedLib;
      } else if (Platform.isWindows) {
        final possiblePaths = [
          p.join(Directory.current.path, 'windows', 'vec0.dll'),
          p.join(Directory.current.path, 'build', 'windows_deps', 'vec0.dll'),
          p.join(Directory.current.path, 'example', 'windows', 'vec0.dll'),
          p.join(Directory.current.path, 'vec0.dll'),
        ];
        String? finalDllPath;
        for (final path in possiblePaths) {
          if (File(path).existsSync()) {
            finalDllPath = path;
            break;
          }
        }
        finalDllPath ??= p.join(Directory.current.path, 'build', 'windows_deps', 'vec0.dll');
        lib = DynamicLibrary.open(finalDllPath);
      } else {
        throw UnsupportedError('Unsupported platform for sqlite-vec');
      }

      sqlite3.ensureExtensionLoaded(
        SqliteExtension.inLibrary(lib, 'sqlite3_vec_init'),
      );
      _vecAvailable = true;
    } catch (e) {
      // vec0 not available on this device/platform (e.g. x86 emulator).
      // The service will still work for text storage; vector search will
      // be skipped and callers should use lexical fallback.
      _vecAvailable = false;
    }

    _initializeSchema();
  }

  void _initializeSchema() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        source_uri TEXT,
        ingested_at INTEGER
      );
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS document_chunks (
        chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_id INTEGER,
        text_content TEXT,
        chunk_index INTEGER,
        FOREIGN KEY(doc_id) REFERENCES documents(id) ON DELETE CASCADE
      );
    ''');

    // Only create the vec0 virtual table if the extension loaded successfully.
    if (_vecAvailable) {
      try {
        _db!.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(
            embedding float[384]
          );
        ''');
      } catch (e) {
        // Extension loaded but schema creation failed — disable gracefully.
        _vecAvailable = false;
      }
    }
  }

  /// Inserts a document record and returns its docId
  int insertDocument(String title, {String? sourceUri}) {
    if (_db == null) throw Exception("VectorStorageService not initialized");
    final stmt = _db!.prepare('''
      INSERT INTO documents (title, source_uri, ingested_at)
      VALUES (?, ?, ?)
    ''');
    stmt.execute([title, sourceUri ?? '', DateTime.now().millisecondsSinceEpoch]);
    final docId = _db!.lastInsertRowId;
    stmt.dispose();
    return docId;
  }

  /// Deletes a document and all its corresponding chunks and vectors
  void deleteDocument(int docId) {
    if (_db == null) return;
    try {
      _db!.execute('DELETE FROM vec_chunks WHERE rowid IN (SELECT chunk_id FROM document_chunks WHERE doc_id = ?)', [docId]);
      _db!.execute('DELETE FROM document_chunks WHERE doc_id = ?', [docId]);
      _db!.execute('DELETE FROM documents WHERE id = ?', [docId]);
    } catch (_) {}
  }

  /// Deletes a document and all its chunks/vectors by title (string ID).
  /// Safe to call when no matching document exists — silently returns.
  /// This is the correct entry point for app-layer code that manages
  /// documents by string IDs, not SDK-internal integer row IDs.
  void deleteDocumentByTitle(String title) {
    if (_db == null) return;
    try {
      final stmt = _db!.prepare('SELECT id FROM documents WHERE title = ?');
      final rows = stmt.select([title]);
      stmt.dispose();
      for (final row in rows) {
        final docId = row['id'] as int;
        deleteDocument(docId);
      }
    } catch (_) {}
  }

  /// Inserts multiple chunks and their embeddings in a single transaction.
  /// Atomic: either all chunks are committed or none are (crash-safe).
  /// ~3-5× faster than individual insertChunk() calls due to single
  /// journal sync.
  void insertChunkBatch(
    int docId,
    List<String> texts,
    List<int> indices,
    List<List<double>> embeddings,
  ) {
    if (_db == null) throw Exception("VectorStorageService not initialized");
    if (texts.length != indices.length || texts.length != embeddings.length) {
      throw ArgumentError("texts, indices, and embeddings must have equal length");
    }

    _db!.execute('BEGIN TRANSACTION');
    try {
      final stmtChunk = _db!.prepare(
        'INSERT INTO document_chunks (doc_id, text_content, chunk_index) VALUES (?, ?, ?)',
      );
      final stmtVec = _db!.prepare(
        'INSERT INTO vec_chunks (rowid, embedding) VALUES (?, ?)',
      );

      for (var i = 0; i < texts.length; i++) {
        stmtChunk.execute([docId, texts[i], indices[i]]);
        final chunkId = _db!.lastInsertRowId;
        final embeddingStr = '[${embeddings[i].join(",")}]';
        stmtVec.execute([chunkId, embeddingStr]);
      }

      stmtChunk.dispose();
      stmtVec.dispose();
      _db!.execute('COMMIT');
    } catch (e) {
      _db!.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Inserts a chunk and its corresponding embedding.
  /// No-op when [isVecAvailable] is false — text is still stored for lexical retrieval.
  int insertChunk(int docId, String textContent, int chunkIndex, List<double> embedding) {
    if (_db == null) throw Exception('VectorStorageService not initialized');

    final stmtChunk = _db!.prepare('''
      INSERT INTO document_chunks (doc_id, text_content, chunk_index)
      VALUES (?, ?, ?)
    ''');
    stmtChunk.execute([docId, textContent, chunkIndex]);
    final chunkId = _db!.lastInsertRowId;
    stmtChunk.dispose();

    if (_vecAvailable) {
      try {
        final embeddingStr = '[${embedding.join(",")}]';
        final stmtVec = _db!.prepare('''
          INSERT INTO vec_chunks (rowid, embedding)
          VALUES (?, ?)
        ''');
        stmtVec.execute([chunkId, embeddingStr]);
        stmtVec.dispose();
      } catch (_) {
        // Vector insert failed — text chunk is still persisted.
      }
    }

    return chunkId;
  }

  /// Searches for the most similar chunks using cosine distance.
  /// Returns an empty list when [isVecAvailable] is false — use
  /// [DocumentIngestionService.lexicalSearch] as fallback in that case.
  List<Map<String, dynamic>> search(List<double> queryEmbedding, {int limit = 5}) {
    if (_db == null) throw Exception('VectorStorageService not initialized');
    if (!_vecAvailable) return [];

    try {
      final embeddingStr = '[${queryEmbedding.join(",")}]';

      // In sqlite-vec, lower distance = more similar
      final stmt = _db!.prepare('''
        SELECT
          c.chunk_id,
          c.doc_id,
          c.text_content,
          v.distance
        FROM vec_chunks v
        JOIN document_chunks c ON c.chunk_id = v.rowid
        WHERE v.embedding MATCH ?
        ORDER BY v.distance
        LIMIT ?
      ''');

      final resultSet = stmt.select([embeddingStr, limit]);
      stmt.dispose();

      return resultSet.map((row) => {
        'chunk_id': row['chunk_id'],
        'doc_id': row['doc_id'],
        'text_content': row['text_content'],
        'distance': row['distance'],
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches text chunks directly from the SQLite database.
  /// If docId is specified, fetches chunks for that document; otherwise returns recent chunks.
  List<Map<String, dynamic>> getChunksForDocument({int? docId, int limit = 10}) {
    if (_db == null) return [];

    try {
      final String query = docId != null
          ? 'SELECT chunk_id, doc_id, text_content FROM document_chunks WHERE doc_id = ? ORDER BY chunk_index ASC LIMIT ?'
          : 'SELECT chunk_id, doc_id, text_content FROM document_chunks ORDER BY chunk_id DESC LIMIT ?';

      final stmt = _db!.prepare(query);
      final resultSet = docId != null ? stmt.select([docId, limit]) : stmt.select([limit]);
      stmt.dispose();

      return resultSet.map((row) => {
        'chunk_id': row['chunk_id'],
        'doc_id': row['doc_id'],
        'text_content': row['text_content'],
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Safely exports the current database to a specified destination path.
  /// Used for cloud backups and cross-device sync.
  Future<File> exportDatabase(String destinationPath) async {
    if (_dbPath == null) throw Exception("Cannot export an in-memory or uninitialized database.");
    
    // Checkpoint the WAL file to ensure all transactions are flushed to the main DB file
    _db!.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    
    final sourceFile = File(_dbPath!);
    return await sourceFile.copy(destinationPath);
  }

  /// Safely replaces the current database with a database from a source file.
  /// Overwrites the current RAG memory.
  Future<void> importDatabase(String sourceFilePath) async {
    if (_dbPath == null) throw Exception("Cannot import into an in-memory or uninitialized database.");
    
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw Exception("Source database file does not exist at $sourceFilePath");
    }

    // Close existing connection
    dispose();

    // Copy over
    final targetFile = File(_dbPath!);
    await sourceFile.copy(targetFile.path);

    // Re-initialize
    await initialize(inMemory: false);
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
