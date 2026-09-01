import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import 'package:denizen_ai/src/rag/embedding_provider.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';

class DocumentIngestionService {
  final EmbeddingProvider _embeddingProvider;
  final VectorStorageService _storageService;

  DocumentIngestionService(this._embeddingProvider, this._storageService);

  // ─── Public Text Utilities ────────────────────────────────────

  /// Cleans extracted text: collapses whitespace, removes control characters,
  /// and strips common PDF artefacts (ligatures, binary noise).
  static String sanitizeText(String raw) {
    return raw
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'[ﬁﬀﬂﬃﬄ]'), '') // PDF ligature artefacts
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ─── File Ingestion ───────────────────────────────────────────

  /// Ingests a raw file directly (.txt, .md, .pdf, .json, .csv, .log, etc.).
  /// Text extraction runs in a background isolate. PDF extraction uses a
  /// regex-based parser safe for use in Dart isolates (no platform channels).
  /// Pass [preExtractedText] to supply text already extracted on the main
  /// thread (e.g. via Syncfusion); when provided, the isolate skips I/O and
  /// goes straight to chunking.
  Future<void> ingestFile(
    int docId,
    File file, {
    int chunkSizeWords = 200,
    int overlapWords = 30,
    int maxChunks = 100,
    String? preExtractedText,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('File does not exist: ${file.path}');
    }

    final filePath = file.path;

    // Extract text in background isolate to prevent UI thread hangs.
    // NOTE: do NOT call Syncfusion or any Flutter platform channel here.
    final content = await Isolate.run(() {
      // Use pre-extracted text if the caller already ran a richer extractor
      // on the main thread (e.g. Syncfusion PdfTextExtractor).
      if (preExtractedText != null && preExtractedText.trim().isNotEmpty) {
        return sanitizeText(preExtractedText);
      }

      final targetFile = File(filePath);
      final ext = p.extension(filePath).toLowerCase();

      if (ext == '.pdf') {
        final bytes = targetFile.readAsBytesSync();
        return sanitizeText(_extractTextFromPdfBytes(bytes));
      } else {
        try {
          return sanitizeText(targetFile.readAsStringSync());
        } catch (_) {
          final bytes = targetFile.readAsBytesSync();
          return sanitizeText(_extractPrintableStrings(bytes));
        }
      }
    });

    if (content.trim().isEmpty) {
      throw FormatException(
        "Could not extract readable text from file '${p.basename(file.path)}'.",
      );
    }

    return ingestText(
      docId,
      content,
      chunkSizeWords: chunkSizeWords,
      overlapWords: overlapWords,
      maxChunks: maxChunks,
    );
  }

  // ─── PDF Text Extraction (isolate-safe, no platform channels) ──

  static String _extractTextFromPdfBytes(List<int> bytes) {
    final rawStr = String.fromCharCodes(bytes);
    final sb = StringBuffer();

    // Tj operator — single string: (Hello World) Tj
    final tjRegex = RegExp(r'\(([^)]+)\)\s*Tj', multiLine: true);
    for (final m in tjRegex.allMatches(rawStr)) {
      final g = m.group(1);
      if (g != null && g.trim().isNotEmpty) sb.writeln(g.trim());
    }

    // TJ operator — array: [(Hello) -200 (World)] TJ
    final arrayTjRegex = RegExp(
      r'\[\s*(((?:\([^)]+\)\s*|-?\d+\s*)+))\]\s*TJ',
      multiLine: true,
    );
    for (final m in arrayTjRegex.allMatches(rawStr)) {
      final rawGroup = m.group(1) ?? '';
      final innerRegex = RegExp(r'\(([^)]+)\)');
      for (final inner in innerRegex.allMatches(rawGroup)) {
        final text = inner.group(1);
        if (text != null && text.trim().isNotEmpty) {
          sb.write(text.trim());
          sb.write(' ');
        }
      }
      sb.writeln();
    }

    // ET blocks (text between BT ... ET markers)
    final btEtRegex = RegExp(r'BT\s*([\s\S]*?)\s*ET', multiLine: true);
    for (final block in btEtRegex.allMatches(rawStr)) {
      final blockContent = block.group(1) ?? '';
      // Extract any quoted strings within BT/ET that weren't caught above
      final strRegex = RegExp(r'\(([^)]{1,300})\)');
      for (final m in strRegex.allMatches(blockContent)) {
        final text = m.group(1)?.trim() ?? '';
        if (text.length >= 2 && !text.startsWith('/')) {
          sb.writeln(text);
        }
      }
    }

    if (sb.length < 50) {
      return _extractPrintableStrings(bytes);
    }

    return sb.toString();
  }

  static String _extractPrintableStrings(List<int> bytes) {
    final rawStr = String.fromCharCodes(bytes);
    final asciiRegex = RegExp(r"[A-Za-z0-9\s.,!?:;()'\-]{4,}");
    final sb = StringBuffer();

    for (final m in asciiRegex.allMatches(rawStr)) {
      final s = m.group(0)!.trim();
      if (s.length >= 4 &&
          !s.startsWith('/Font') &&
          !s.startsWith('/ProcSet') &&
          !s.startsWith('/Type') &&
          !s.startsWith('/Catalog') &&
          !s.startsWith('/Pages') &&
          !s.startsWith('/vector') &&
          !s.startsWith('vec0') &&
          !s.startsWith('FlateDecode') &&
          !s.startsWith('stream')) {
        sb.writeln(s);
      }
    }

    return sb.toString();
  }

  // ─── Text Ingestion (chunk → embed → store) ───────────────────

  /// Ingests a raw text document by splitting it into overlapping chunks,
  /// embedding each chunk, and storing it in the vector database.
  Future<void> ingestText(
    int docId,
    String fullText, {
    int chunkSizeWords = 200,
    int overlapWords = 30,
    int maxChunks = 100,
  }) async {
    if (!_storageService.isInitialized) {
      throw StateError(
        'VectorStorageService must be initialized before ingestion.',
      );
    }

    // Chunk text in background isolate to prevent UI thread hangs
    final chunks = await Isolate.run(() {
      return _createSlidingWindowChunks(
        fullText,
        chunkSizeWords,
        overlapWords,
        maxChunks: maxChunks,
      );
    });

    if (chunks.isEmpty) return;

    // Use embedBatch for faster performance
    List<List<double>> embeddings;
    try {
      embeddings = await _embeddingProvider.embedBatch(chunks);
    } catch (_) {
      embeddings = [];
      for (final chunkText in chunks) {
        embeddings.add(await _embeddingProvider.embed(chunkText));
      }
    }

    for (int i = 0; i < chunks.length; i++) {
      _storageService.insertChunk(docId, chunks[i], i, embeddings[i]);
    }
  }

  // ─── Lexical Retrieval (no sqlite-vec required) ───────────────

  /// Retrieves the [topK] most relevant chunks from [allChunks] using
  /// word set-intersection scoring. This is a fast, dependency-free
  /// fallback that works without sqlite-vec and without TFLite — safe
  /// to call on the main thread.
  ///
  /// Suitable for on-device use when the vec0 extension is unavailable
  /// (e.g. x86 emulators, devices missing the .so).
  static List<String> lexicalSearch(
    String query,
    List<String> allChunks, {
    int topK = 3,
    int minScore = 1,
  }) {
    if (allChunks.isEmpty || query.trim().isEmpty) return [];

    final stopWords = {
      'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
      'should', 'may', 'might', 'shall', 'can', 'to', 'of', 'in', 'on',
      'at', 'by', 'for', 'with', 'about', 'and', 'or', 'but', 'not', 'it',
      'its', 'this', 'that', 'i', 'you', 'he', 'she', 'we', 'they',
    };

    final queryWords = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toSet();

    if (queryWords.isEmpty) return allChunks.take(topK).toList();

    final scored = allChunks.map((chunk) {
      final chunkWords = chunk
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .toSet();
      final hits = queryWords.intersection(chunkWords).length;
      // Normalise by chunk length to avoid always picking the longest chunk
      final score = hits / (1 + chunkWords.length * 0.01);
      return (chunk: chunk, score: score, hits: hits);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored
        .where((e) => e.hits >= minScore)
        .take(topK)
        .map((e) => e.chunk)
        .toList();
  }

  // ─── Chunking ─────────────────────────────────────────────────

  /// Creates overlapping text chunks using a sliding window approach.
  static List<String> _createSlidingWindowChunks(
    String text,
    int chunkSize,
    int overlapSize, {
    int maxChunks = 100,
  }) {
    if (text.trim().isEmpty) return [];

    final words = text.split(RegExp(r'\s+'));
    final List<String> chunks = [];

    int start = 0;
    while (start < words.length) {
      int end = (start + chunkSize).clamp(0, words.length);
      chunks.add(words.sublist(start, end).join(' '));
      if (end == words.length) break;
      start = end - overlapSize;
      if (chunks.length >= maxChunks) break;
    }

    return chunks;
  }
}
