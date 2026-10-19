library denizen_ai;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/llama/llama.dart' show ChatMessage;
import 'src/services/offline_ai_service.dart';
import 'src/services/model_download_service.dart';
import 'src/models/offline_model.dart';
import 'src/models/default_offline_models.dart';
import 'src/rag/embedding_provider.dart';
import 'src/rag/vector_storage_service.dart';
import 'src/orchestrator/denizen_orchestrator.dart';
import 'src/tools/denizen_tool_registry.dart';
import 'src/tools/denizen_tool_session.dart';
import 'src/vision/denizen_vision_session.dart';
import 'src/audio/denizen_voice_session.dart';
import 'src/config/ubuntu_edge_config.dart';

export 'src/orchestrator/denizen_orchestrator.dart';
export 'src/grammar/denizen_grammar.dart';
export 'src/tools/denizen_tool.dart';
export 'src/tools/denizen_tool_registry.dart';
export 'src/tools/denizen_tool_session.dart';
export 'src/vision/denizen_vision_session.dart';
export 'src/audio/denizen_voice_session.dart';
export 'src/audio/offline_audio_service.dart';
export 'src/rag/embedding_provider.dart';
export 'src/rag/tflite_embedding_provider.dart';
export 'src/rag/vector_storage_service.dart';
export 'src/rag/document_ingestion_service.dart';
export 'src/models/offline_model.dart';
export 'src/models/default_offline_models.dart';
export 'src/models/offline_context_params.dart';
export 'src/models/offline_completion_params.dart';
export 'src/services/model_download_service.dart';
export 'src/services/offline_ai_service.dart';
export 'src/services/device_hardware_service.dart';
export 'src/vision/vision_results.dart';
export 'src/config/ubuntu_edge_config.dart';
export 'src/llama/llama.dart' show ChatMessage, LlamaController, GenerationConfig;


/// The core entry point for the Denizen AI SDK.
/// Abstracts away complex offline AI tasks like model management, 
/// text generation, and context management.
/// 
/// Note: This is designed as a Singleton. On-device resource limits 
/// (specifically RAM and CPU) prevent multiple offline LLMs from running 
/// concurrently without crashing the host application. Enforcing a single 
/// instance ensures clean lifecycle and resource management.
class DenizenAI {
  static final DenizenAI _instance = DenizenAI._internal();

  // ---------------------------------------------------------------------------
  // Ubuntu Edge Platform — static configuration hook
  // ---------------------------------------------------------------------------

  static UbuntuEdgeConfig? _edgeConfig;

  /// Optionally configure the Ubuntu Edge Platform integration.
  ///
  /// Call this **once** at app startup (before [runApp]) to unlock Ubuntu Edge
  /// Platform features such as smart cloud fallback, OTA model delta updates,
  /// and the 50+ language multilingual gateway.
  ///
  /// Omitting this call leaves the SDK in fully-offline MIT mode — no changes
  /// to existing code are required.
  ///
  /// **Note (Preview):** Ubuntu Edge Platform services are currently in active development.
  /// Setting this config today ensures your app is forward-compatible.
  /// All inference and storage operate 100% locally on-device.
  ///
  /// ```dart
  /// void main() {
  ///   DenizenAI.configure(
  ///     edgeConfig: UbuntuEdgeConfig(
  ///       apiKey: 'ue-YOUR_API_KEY',
  ///       enableCloudFallback: true,
  ///       enableOtaModelUpdates: true,
  ///     ),
  ///   );
  ///   runApp(const MyApp());
  /// }
  /// ```
  @experimental
  static void configure({UbuntuEdgeConfig? edgeConfig}) {
    _edgeConfig = edgeConfig;
    if (edgeConfig != null) {
      debugPrint(
        '[DenizenAI] Ubuntu Edge Platform configured (Preview/Forward-Compatibility). '
        'Active features: ${edgeConfig.featureSummary}. '
        'Note: Ubuntu Edge cloud backend is currently in preview. All inference runs 100% locally on-device.',
      );
    }
  }

  /// Whether an [UbuntuEdgeConfig] has been provided via [configure].
  static bool get isEdgeConfigured => _edgeConfig != null;

  /// The active [UbuntuEdgeConfig], or `null` if [configure] was not called.
  ///
  /// Used internally by sessions and services to determine whether to
  /// attempt Ubuntu Edge Platform feature paths.
  static UbuntuEdgeConfig? get edgeConfig => _edgeConfig;

  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  /// Get the singleton instance of DenizenAI.
  factory DenizenAI() => _instance;

  final OfflineAIService _aiService;

  /// Access the model manager to download, load, and manage GGUF models.
  final DenizenModelManager models;

  DenizenAI._internal()
      : _aiService = OfflineAIService.instance,
        models = DenizenModelManager(
          ModelDownloadService.instance,
          OfflineAIService.instance,
        );

  /// Returns true if a model is currently loaded in memory.
  bool get isModelLoaded => _aiService.isModelLoaded;

  /// **UNSTABLE / ADVANCED API**
  /// 
  /// Exposes the underlying [OfflineAIService] for lower-level operations. 
  /// Directly interacting with this service bypasses the safety guarantees 
  /// and orchestrations (such as automated context management) provided by the SDK.
  /// Use with caution.
  OfflineAIService get engine => _aiService;

  /// Create a new stateful session for conversation tracking and context management.
  DenizenSession createSession({
    String? systemPrompt,
    int? maxTokens,
  }) {
    return DenizenSession(
      _aiService,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    );
  }

  /// Create a RAG-enabled session that automatically queries the vector DB
  /// and injects relevant knowledge chunks into the system prompt context.
  DenizenRagSession createRagSession({
    required EmbeddingProvider embeddingProvider,
    required VectorStorageService storageService,
    String? baseSystemPrompt,
    int? maxTokens,
  }) {
    return DenizenRagSession(
      _aiService,
      embeddingProvider,
      storageService,
      baseSystemPrompt: baseSystemPrompt,
      maxTokens: maxTokens,
    );
  }

  /// Create a Tool-enabled session that automatically handles local function calling.
  DenizenToolSession createToolSession({
    required DenizenToolRegistry registry,
    String? systemPrompt,
    int? maxTokens,
  }) {
    return DenizenToolSession(
      _aiService,
      registry,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    );
  }

  /// Creates a [DenizenVisionSession] for multimodal image analysis.
  /// 
  /// **Status:** Experimental (v2.0 Preview).
  /// Requires a multimodal model with visual projector (e.g. LLaVA mmproj).
  @experimental
  DenizenVisionSession createVisionSession({String? systemPrompt}) {
    return DenizenVisionSession(systemPrompt: systemPrompt);
  }

  /// Creates a [DenizenVoiceSession] for offline audio transcription and chat.
  DenizenVoiceSession createVoiceSession({String? systemPrompt}) {
    return DenizenVoiceSession(systemPrompt: systemPrompt);
  }

  // =========================================================================
  // STATE MANAGEMENT (PHASE 5: CLOUD SYNC & KNOWLEDGE BUNDLING)
  // =========================================================================

  /// Loads a pre-embedded `.sqlite` knowledge database from the app's `assets/` folder.
  /// This loads bundled domain-specific knowledge out of the box into the application's
  /// active temporary vector storage.
  ///
  /// **Status:** Experimental.
  @experimental
  Future<void> loadBundledKnowledge(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/temp_bundled_rag.db');
    
    await tempFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    
    final orchestrator = DenizenOrchestrator();
    if (!orchestrator.isReady) {
      throw StateError("DenizenOrchestrator is not running. Start DenizenOrchestrator before importing knowledge.");
    }
  }

  /// Exports the current RAG vector database to a safe destination path.
  /// Useful for backing up user AI state to Google Drive/iCloud.
  ///
  /// **Status:** Experimental (Targeted for Denizen AI v1.1).
  /// Requires DenizenOrchestrator cross-isolate DB lock coordination.
  @experimental
  Future<File> exportMemoryDatabase(String destinationPath) async {
    final orchestrator = DenizenOrchestrator();
    if (!orchestrator.isReady) {
      throw StateError("DenizenOrchestrator is not running. Start DenizenOrchestrator before exporting memory.");
    }
    throw UnsupportedError(
      "Cross-isolate memory export is scheduled for Denizen AI v1.1. "
      "Direct vector database backup is currently experimental.",
    );
  }

  /// Restores a previously backed-up RAG vector database from a file path.
  /// Overwrites current memory.
  ///
  /// **Status:** Experimental (Targeted for Denizen AI v1.1).
  /// Requires DenizenOrchestrator cross-isolate DB lock coordination.
  @experimental
  Future<void> restoreMemoryDatabase(String sourceFilePath) async {
    final orchestrator = DenizenOrchestrator();
    if (!orchestrator.isReady) {
      throw StateError("DenizenOrchestrator is not running. Start DenizenOrchestrator before restoring memory.");
    }
    throw UnsupportedError(
      "Cross-isolate memory restore is scheduled for Denizen AI v1.1. "
      "Direct vector database restore is currently experimental.",
    );
  }
}


/// Exception thrown when the device is out of storage space and eviction fails.
class StorageQuotaException implements Exception {
  final String message;
  StorageQuotaException(this.message);
  @override
  String toString() => 'StorageQuotaException: $message';
}

/// Exception thrown when network constraints are violated.
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

/// Progress data representing an ongoing model download.
class DenizenDownloadProgress {
  /// The fractional progress from `0.0` (start) to `1.0` (complete).
  final double progress;

  /// Number of bytes downloaded so far.
  final int bytesDownloaded;

  /// Total size of the model file in bytes.
  final int totalBytes;

  /// Returns the percentage of download completed (0.0 to 100.0).
  double get percent => progress * 100.0;

  DenizenDownloadProgress({
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
  });
}

/// Facade for managing models (Downloading, Loading, Eviction)
class DenizenModelManager {
  final ModelDownloadService _downloadService;
  final OfflineAIService _aiService;

  DenizenModelManager(this._downloadService, this._aiService);

  /// Look up model from recommendations by ID, shorthand ID, or filename
  OfflineModel? _lookUpModel(String modelId) {
    try {
      final recommended = DefaultOfflineModels.getAllRecommendedModels();
      final idLower = modelId.toLowerCase().trim();
      for (final m in recommended) {
        final mIdLower = m.id.toLowerCase();
        final mIdBase = mIdLower.replaceAll('-q4', '').replaceAll('-q8', '');
        final fnLower = (m.filename ?? '').toLowerCase();
        if (mIdLower == idLower ||
            mIdBase == idLower ||
            fnLower == idLower ||
            fnLower == '$idLower.gguf') {
          return m;
        }
      }
    } catch (_) {}

    final filename = modelId.endsWith('.gguf') ? modelId : '$modelId.gguf';
    return OfflineModel(
      id: modelId,
      name: modelId,
      author: 'local',
      size: 400000000,
      filename: filename,
      contextSize: 2048,
      isDownloaded: true,
      downloadProgress: 100,
    );
  }

  Future<SharedPreferences?> _getPrefsSafely() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('⚠️ SharedPreferences unavailable: $e');
      return null;
    }
  }

  /// Perform LRU storage eviction to reclaim space.
  Future<void> _performLRUEviction(int requiredBytes, {required String excludingModelId}) async {
    final prefs = await _getPrefsSafely();
    
    // Get all downloaded model paths
    final List<String> downloadedPaths = await _downloadService.getDownloadedModelPaths();
    if (downloadedPaths.isEmpty) return;

    final List<OfflineModel> recommendedModels = DefaultOfflineModels.getAllRecommendedModels();
    final List<String> residentModels = prefs?.getStringList('denizen_resident_models') ?? [];

    // Find models we can evict
    final List<Map<String, dynamic>> evictableCandidates = [];
    
    for (final path in downloadedPaths) {
      final file = File(path);
      final filename = file.uri.pathSegments.last;
      
      // Look up matching recommended model
      OfflineModel? matchingModel;
      try {
        matchingModel = recommendedModels.firstWhere((m) => m.filename == filename);
      } catch (_) {}
      
      final id = matchingModel?.id ?? filename;
      
      // Skip if this is the model we are trying to load right now
      if (id == excludingModelId) continue;
      
      // Skip if marked as resident
      if (residentModels.contains(id)) continue;
      
      // Skip if it is currently loaded/active in memory
      if (_aiService.isModelLoaded && _aiService.loadedModelPath == path) continue;
      
      // Get last accessed timestamp (default to 0 if not set)
      final lastAccessed = prefs?.getInt('denizen_last_accessed_$id') ?? 0;
      
      evictableCandidates.add({
        'path': path,
        'id': id,
        'lastAccessed': lastAccessed,
        'size': await file.length(),
      });
    }

    // Sort by last accessed timestamp ascending (oldest first)
    evictableCandidates.sort((a, b) => (a['lastAccessed'] as int).compareTo(b['lastAccessed'] as int));

    // Evict models until we have enough space
    for (final candidate in evictableCandidates) {
      final available = await _downloadService.getAvailableStorageBytes();
      const buffer = 500 * 1024 * 1024; // 500MB safety buffer
      if (available > (requiredBytes + buffer)) {
        break; // We have enough space now!
      }
      
      final path = candidate['path'] as String;
      final id = candidate['id'] as String;
      final size = candidate['size'] as int;
      
      debugPrint('🗑️ Storage Eviction: Deleting model $id ($path) to free up ${(size / (1024 * 1024)).toStringAsFixed(1)} MB');
      await _downloadService.deleteModel(path);
      
      // Clean up pref timestamp
      await prefs?.remove('denizen_last_accessed_$id');
    }
  }

  /// Load a model by ID. If it is not present on the device, 
  /// it will automatically download it.
  Future<void> load(String modelId, {
    bool requireWifi = false, 
    void Function(DenizenDownloadProgress progress)? onProgress,
    bool requireResidency = false,
  }) async {
    // 1. Look up the model definition
    final OfflineModel? model = _lookUpModel(modelId);
    if (model == null) {
      throw ArgumentError('Model not found in recommendations: $modelId');
    }

    final prefs = await _getPrefsSafely();

    // Track residency configuration persistently
    final List<String> residentModels = prefs?.getStringList('denizen_resident_models') ?? [];
    if (requireResidency) {
      if (!residentModels.contains(modelId)) {
        residentModels.add(modelId);
        await prefs?.setStringList('denizen_resident_models', residentModels);
      }
    } else {
      if (residentModels.contains(modelId)) {
        residentModels.remove(modelId);
        await prefs?.setStringList('denizen_resident_models', residentModels);
      }
    }

    // 2. Determine paths
    final storageDir = await _downloadService.getModelStorageDirectory();
    final modelDir = Directory('${storageDir.path}/models/${model.author}');
    final finalFile = File('${modelDir.path}/${model.filename}');
    String targetPath = finalFile.path;

    // 2b. Check for pre-downloaded model in /data/local/tmp, /sdcard/Download or /storage/emulated/0/Download
    if (!await finalFile.exists() && (model.filename != null)) {
      for (final altPath in [
        '/data/local/tmp/${model.filename}',
        '/sdcard/Download/${model.filename}',
        '/storage/emulated/0/Download/${model.filename}',
      ]) {
        final altFile = File(altPath);
        if (await altFile.exists() && (await altFile.length()) > 1024 * 1024) {
          debugPrint('📦 Found pre-pushed model directly at $altPath');
          targetPath = altFile.path;
          break;
        }
      }
    }

    // 3. Update last accessed timestamp
    await prefs?.setInt('denizen_last_accessed_$modelId', DateTime.now().millisecondsSinceEpoch);

    // 4. Check if file already exists locally at targetPath
    final targetFileObj = File(targetPath);
    bool exists = await targetFileObj.exists() && (await targetFileObj.length()) > 1024 * 1024;
    
    // For vision models, also assert mmproj exists
    if (exists && model.isVision && model.vision != null) {
      final storageDir = await _downloadService.getModelStorageDirectory();
      final mmprojFile = File('${storageDir.path}/models/${model.author}/${model.vision!.mmprojFilename}');
      final mmprojExists = await mmprojFile.exists() && (await mmprojFile.length()) > 1024 * 1024;
      if (!mmprojExists) {
        exists = false;
      }
    }
    
    if (!exists) {
      // 5. Handle Storage/Eviction logic before download (including mmproj if vision)
      final int requiredBytes = model.totalSizeBytes;
      final bool hasSpace = await _downloadService.hasEnoughStorage(requiredBytes);
      
      if (!hasSpace) {
        // Run LRU Eviction
        await _performLRUEviction(requiredBytes, excludingModelId: modelId);
      }

      // Check space again
      final bool hasSpacePostEviction = await _downloadService.hasEnoughStorage(requiredBytes);
      if (!hasSpacePostEviction) {
        throw StorageQuotaException('Insufficient storage space to download model $modelId (${model.totalSizeMB.toStringAsFixed(1)} MB required). Eviction could not reclaim enough space because other cached models are marked as resident.');
      }

      // 6. Gated Download based on wifi if required
      if (requireWifi) {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (!connectivityResult.contains(ConnectivityResult.wifi)) {
          throw NetworkException('Wifi connection required to download model, but current connection is not Wifi.');
        }
      }

      // 7. Perform the download with paired multi-file and integrity support
      final downloadStream = _downloadService.downloadOfflineModel(
        model: model,
      );

      await for (final downloadProgress in downloadStream) {
        if (downloadProgress.stage == ModelDownloadStage.failed) {
          throw Exception('Download failed: ${downloadProgress.error}');
        }
        
        if (onProgress != null) {
          // Translate to DenizenDownloadProgress
          final progressPercent = downloadProgress.progress / 100.0;
          onProgress(DenizenDownloadProgress(
            progress: progressPercent,
            bytesDownloaded: downloadProgress.downloadedBytes ?? 0,
            totalBytes: downloadProgress.totalBytes ?? model.totalSizeBytes,
          ));
        }
      }

      // After download completes, targetPath is finalFile.path
      targetPath = finalFile.path;
    }

    // 8. Load the model into OfflineAIService (using loadVisionModel if vision)
    final bool loadSuccess;
    if (model.isVision && model.vision != null) {
      final storageDir = await _downloadService.getModelStorageDirectory();
      final mmprojPath = '${storageDir.path}/models/${model.author}/${model.vision!.mmprojFilename}';
      loadSuccess = await _aiService.loadVisionModel(
        modelPath: targetPath,
        mmprojPath: mmprojPath,
        model: model,
      );
    } else {
      loadSuccess = await _aiService.loadModel(
        modelPath: targetPath,
        model: model,
      );
    }

    if (!loadSuccess) {
      throw Exception('Failed to load model into inference engine.');
    }
  }

  /// Download a model directly from a custom URL with progress tracking.
  Future<OfflineModel> downloadModel({
    required String url,
    required String modelId,
    required String fileName,
    String author = 'custom',
    void Function(DenizenDownloadProgress progress)? onProgress,
  }) async {
    final downloadStream = _downloadService.downloadModel(
      url: url,
      modelId: modelId,
      fileName: fileName,
      author: author,
    );

    await for (final downloadProgress in downloadStream) {
      if (downloadProgress.stage == ModelDownloadStage.failed) {
        throw Exception('Download failed: ${downloadProgress.error}');
      }
      if (onProgress != null) {
        onProgress(DenizenDownloadProgress(
          progress: downloadProgress.progress / 100.0,
          bytesDownloaded: downloadProgress.downloadedBytes ?? 0,
          totalBytes: downloadProgress.totalBytes ?? 0,
        ));
      }
    }

    final storageDir = await _downloadService.getModelStorageDirectory();
    final modelFile = File('${storageDir.path}/models/$author/$fileName');
    final fileSize = await modelFile.exists() ? await modelFile.length() : 0;

    return OfflineModel(
      id: modelId,
      name: fileName,
      author: author,
      size: fileSize,
      downloadUrl: url,
      filename: fileName,
      contextSize: 2048,
      isDownloaded: true,
      downloadProgress: 100,
    );
  }

  /// Load an [OfflineModel] directly into the inference engine.
  Future<bool> loadModel(OfflineModel model, {int contextSize = 2048, int gpuLayers = 0}) async {
    File? modelFile;

    // 1. Check explicit localPath if present
    if (model.localPath != null && await File(model.localPath!).exists()) {
      modelFile = File(model.localPath!);
    } else {
      // 2. Check standard storage directory
      final storageDir = await _downloadService.getModelStorageDirectory();
      final standardFile = File('${storageDir.path}/models/${model.author}/${model.filename}');
      if (await standardFile.exists()) {
        modelFile = standardFile;
      } else {
        // 3. Check pre-pushed paths
        for (final altPath in [
          '/data/local/tmp/${model.filename}',
          '/sdcard/Download/${model.filename}',
          '/storage/emulated/0/Download/${model.filename}',
        ]) {
          final altFile = File(altPath);
          if (await altFile.exists()) {
            modelFile = altFile;
            break;
          }
        }
      }
    }
    
    if (modelFile == null || !await modelFile.exists()) {
      throw Exception('Model file does not exist locally for model ${model.id}');
    }

    return await _aiService.loadModel(
      modelPath: modelFile.path,
      model: model.copyWith(contextSize: contextSize),
    );
  }

  /// Load a local GGUF model directly from a [File] path into memory.
  Future<bool> loadFromFile(File modelFile, {OfflineModel? model, int contextSize = 2048, int gpuLayers = 0}) async {
    if (!await modelFile.exists()) {
      throw Exception('Model file does not exist at ${modelFile.path}');
    }

    final filename = modelFile.uri.pathSegments.last;
    final size = await modelFile.length();
    final resolvedModel = model ?? OfflineModel(
      id: filename,
      name: filename,
      author: 'local',
      size: size,
      filename: filename,
      contextSize: contextSize,
      isDownloaded: true,
      downloadProgress: 100,
    );

    return await _aiService.loadModel(
      modelPath: modelFile.path,
      model: resolvedModel,
    );
  }

  /// Checks if a model with the given ID (or filename) is already downloaded locally.
  Future<bool> isDownloaded(String modelId) async {
    final model = _lookUpModel(modelId);
    final filename = model?.filename ?? modelId;
    final author = model?.author ?? 'Alibaba';

    final storageDir = await _downloadService.getModelStorageDirectory();
    final modelFile = File('${storageDir.path}/models/$author/$filename');
    if (await modelFile.exists() && (await modelFile.length()) > 1024 * 1024) {
      return true;
    }

    final downloadedPaths = await _downloadService.getDownloadedModelPaths();
    return downloadedPaths.any((p) => p.endsWith(filename));
  }

  /// Returns a list of all models currently downloaded on device.
  Future<List<OfflineModel>> getDownloadedModels() async {
    final downloadedPaths = await _downloadService.getDownloadedModelPaths();
    final recommended = DefaultOfflineModels.getAllRecommendedModels();
    final List<OfflineModel> result = [];

    for (final path in downloadedPaths) {
      final filename = File(path).uri.pathSegments.last;
      OfflineModel? match;
      try {
        match = recommended.firstWhere((m) => m.filename == filename);
      } catch (_) {}

      if (match != null) {
        result.add(match.copyWith(isDownloaded: true, downloadProgress: 100));
      } else {
        final file = File(path);
        final size = await file.length();
        result.add(OfflineModel(
          id: filename,
          name: filename,
          author: 'local',
          size: size,
          filename: filename,
          isDownloaded: true,
          downloadProgress: 100,
        ));
      }
    }
    return result;
  }

  /// Deletes a cached model from local device storage by model ID or path.
  Future<void> deleteModel(String modelId) async {
    final model = _lookUpModel(modelId);
    final filename = model?.filename ?? modelId;

    final downloadedPaths = await _downloadService.getDownloadedModelPaths();
    for (final path in downloadedPaths) {
      if (path.endsWith(filename) || path == modelId) {
        await _downloadService.deleteModel(path);
        final prefs = await _getPrefsSafely();
        await prefs?.remove('denizen_last_accessed_$modelId');
        break;
      }
    }
  }
}

/// Exception thrown when the prompt or history exceeds the context budget.
class ContextOverflowException implements Exception {
  final String message;
  ContextOverflowException(this.message);
  @override
  String toString() => 'ContextOverflowException: $message';
}

/// The role of the message sender in a chat session.
enum DenizenRole {
  system,
  user,
  assistant,
}

/// An immutable representation of a single chat turn.
class DenizenMessage {
  final DenizenRole role;
  final String content;

  DenizenMessage({
    required this.role,
    required this.content,
  });
}

/// A stateful chat session representing a continuous thread of conversation.
/// Manages chat history and enforces context boundaries (sliding window truncation).
class DenizenSession {
  final OfflineAIService _aiService;
  final List<DenizenMessage> _history = [];
  final int? _maxTokensOverride;

  /// Sequential queue to ensure chat turns execute in strict FIFO order
  @protected
  final AsyncSequentialQueue sessionQueue = AsyncSequentialQueue();

  /// Get the current message history in this session.
  List<DenizenMessage> get history => List.unmodifiable(_history);

  DenizenSession(
    this._aiService, {
    String? systemPrompt,
    int? maxTokens,
  }) : _maxTokensOverride = maxTokens {
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      _history.add(DenizenMessage(
        role: DenizenRole.system,
        content: systemPrompt,
      ));
    }
  }

  /// Estimates the token count of a message.
  /// Uses a safe, conservative heuristic (1 token ~ 4 characters) for Phase 1.
  int _estimateTokens(DenizenMessage message) {
    return (message.content.length / 4).ceil();
  }

  /// Calculates the total estimated tokens across all messages in the session.
  int _totalEstimatedTokens() {
    return _history.fold(0, (sum, msg) => sum + _estimateTokens(msg));
  }

  /// Truncates conversation history if it exceeds the context budget.
  /// Preserves the system prompt (always at index 0) and the newest user message
  /// while sliding the window by popping the oldest user/assistant turns.
  void _enforceContextLimit(int resolvedLimit) {
    final safetyBuffer = (resolvedLimit * 0.15).round().clamp(128, 256);
    final maxAllowed = resolvedLimit - safetyBuffer;

    // We keep looping to evict old messages until we are under the token budget.
    while (_totalEstimatedTokens() > maxAllowed) {
      if (_history.isEmpty) break;

      if (_history.first.role == DenizenRole.system) {
        // If system prompt + newest user prompt remain, trim system prompt text to release memory budget
        if (_history.length <= 2) {
          final sysContent = _history.first.content;
          if (sysContent.length > 300) {
            final trimmed = sysContent.substring(0, 300);
            _history[0] = DenizenMessage(
              role: DenizenRole.system,
              content: '$trimmed\n[Context trimmed for memory budget.]',
            );
          }
          break;
        }
        // Evict older conversation turns in pairs (User + Assistant) to free memory
        if (_history.length >= 4) {
          _history.removeAt(1); // Drop oldest user message
          _history.removeAt(1); // Drop oldest assistant reply
        } else {
          _history.removeAt(1);
        }
      } else {
        // No system prompt. Evict older history messages to free memory
        if (_history.length <= 1) {
          break;
        }
        if (_history.length >= 3) {
          _history.removeAt(0); // Drop oldest user message
          _history.removeAt(0); // Drop oldest assistant reply
        } else {
          _history.removeAt(0);
        }
      }
    }
  }

  /// Resolves the context limit dynamically based on override or actual loaded native engine limit.
  int get _resolvedContextLimit {
    return _maxTokensOverride ?? _aiService.loadedContextSize;
  }

  /// Convert DenizenRole to underlying ChatMessage role string.
  String _roleToString(DenizenRole role) {
    switch (role) {
      case DenizenRole.system:
        return 'system';
      case DenizenRole.user:
        return 'user';
      case DenizenRole.assistant:
        return 'assistant';
    }
  }

  /// Prepare LLM inputs from session history.
  List<ChatMessage> _prepareChatMessages() {
    return _history.map((msg) => ChatMessage(
      role: _roleToString(msg.role),
      content: msg.content,
    )).toList();
  }

  /// Internal non-streaming turn execution (protected for subclasses).
  @protected
  Future<String> chatInternal(String prompt) async {
    final userMessage = DenizenMessage(role: DenizenRole.user, content: prompt);
    _history.add(userMessage);

    final resolvedLimit = _resolvedContextLimit;

    try {
      // Apply sliding window context eviction
      _enforceContextLimit(resolvedLimit);
    } on ContextOverflowException {
      // Rollback the failed user message so the session is left in a usable state
      _history.removeLast();
      rethrow;
    }

    try {
      final messages = _prepareChatMessages();
      final response = await _aiService.generateHistoryChat(
        messages: messages,
      );

      _history.add(DenizenMessage(role: DenizenRole.assistant, content: response));
      return response;
    } catch (e) {
      // If prompt generation fails, keep user message but do not add assistant reply
      rethrow;
    }
  }

  /// Internal streaming turn execution (protected for subclasses).
  @protected
  Stream<String> streamChatInternal(String prompt) async* {
    final userMessage = DenizenMessage(role: DenizenRole.user, content: prompt);
    _history.add(userMessage);

    final resolvedLimit = _resolvedContextLimit;

    try {
      // Apply sliding window context eviction
      _enforceContextLimit(resolvedLimit);
    } on ContextOverflowException {
      // Rollback the failed user message so the session is left in a usable state
      _history.removeLast();
      rethrow;
    }

    final messages = _prepareChatMessages();
    final responseBuffer = StringBuffer();
    bool completedSuccessfully = false;

    try {
      final stream = _aiService.generateHistoryChatStream(
        messages: messages,
      );

      await for (final token in stream) {
        responseBuffer.write(token);
        yield token;
      }
      completedSuccessfully = true;
    } finally {
      if (completedSuccessfully) {
        // Only append completed assistant message to history on success
        _history.add(DenizenMessage(
          role: DenizenRole.assistant,
          content: responseBuffer.toString(),
        ));
      }
      // If cancelled/failed, we discard the partial reply to protect history cleanliness.
    }
  }

  /// Send a non-streaming message to the model within this session.
  Future<String> chat(String prompt, {int? docId, List<String>? directChunks}) {
    return sessionQueue.run(() => chatInternal(prompt));
  }

  /// Send a streaming message to the model within this session.
  Stream<String> streamChat(String prompt, {int? docId, List<String>? directChunks}) {
    return sessionQueue.runStream(() => streamChatInternal(prompt));
  }

  /// Alias for [chat]. Send a non-streaming message to the model.
  Future<String> sendMessage(String prompt) => chat(prompt);

  /// Alias for [streamChat]. Send a streaming message to the model.
  Stream<String> sendMessageStream(String prompt) => streamChat(prompt);
}

/// A RAG-enabled chat session that automatically intercepts user queries, 
/// retrieves relevant document chunks from the vector database, and augments 
/// the context window with the findings before generating a response.
class DenizenRagSession extends DenizenSession {
  final EmbeddingProvider _embeddingProvider;
  final VectorStorageService _storageService;
  final String _baseSystemPrompt;

  DenizenRagSession(
    super.aiService,
    this._embeddingProvider,
    this._storageService, {
    String? baseSystemPrompt,
    super.maxTokens,
  }) : _baseSystemPrompt = baseSystemPrompt ?? 'You are a helpful AI assistant.',
       super(systemPrompt: baseSystemPrompt ?? 'You are a helpful AI assistant.');

  void injectKnowledgeText(List<String> rawChunks, {String? basePrompt}) {
    if (rawChunks.isEmpty) {
      if (_history.isNotEmpty && _history.first.role == DenizenRole.system) {
        _history[0] = DenizenMessage(
          role: DenizenRole.system,
          content: basePrompt ?? _baseSystemPrompt,
        );
      }
      return;
    }

    final StringBuffer knowledgeBuffer = StringBuffer();
    knowledgeBuffer.writeln(basePrompt ?? _baseSystemPrompt);
    knowledgeBuffer.writeln('\n[CRITICAL CONTEXT DOCUMENTS]');
    knowledgeBuffer.writeln('Use the following retrieved document material as your knowledge base to answer the user question:');
    
    for (var i = 0; i < rawChunks.length; i++) {
      knowledgeBuffer.writeln('\n--- Context Snippet ${i + 1} ---');
      knowledgeBuffer.writeln(rawChunks[i]);
    }
    knowledgeBuffer.writeln('\n[INSTRUCTION]: Answer the user question directly using ONLY the above context. If the answer is present in the context, state it clearly.');

    if (_history.isNotEmpty && _history.first.role == DenizenRole.system) {
      _history[0] = DenizenMessage(
        role: DenizenRole.system,
        content: knowledgeBuffer.toString(),
      );
    } else {
      _history.insert(0, DenizenMessage(
        role: DenizenRole.system,
        content: knowledgeBuffer.toString(),
      ));
    }
  }

  void _injectKnowledge(List<Map<String, dynamic>> chunks) {
    final rawText = chunks
        .map((c) => c['text_content']?.toString() ?? '')
        .where((t) => t.trim().isNotEmpty)
        .toList();
    injectKnowledgeText(rawText);
  }

  @override
  Future<String> chat(String prompt, {int? docId, List<String>? directChunks}) {
    return sessionQueue.run(() async {
      if (directChunks != null) {
        injectKnowledgeText(directChunks);
        return chatInternal(prompt);
      }

      List<Map<String, dynamic>> chunks = [];
      try {
        final queryEmbedding = await _embeddingProvider.embed(prompt);
        if (_storageService.isInitialized) {
          chunks = _storageService.search(queryEmbedding, limit: 3);
        }
        if (chunks.isEmpty) {
          chunks = _storageService.getChunksForDocument(docId: docId, limit: 3);
        }
      } catch (e) {
        debugPrint('⚠️ RAG retrieval failed: $e. Using direct database fallback.');
        chunks = _storageService.getChunksForDocument(docId: docId, limit: 3);
      }
      
      _injectKnowledge(chunks);
      return chatInternal(prompt);
    });
  }

  @override
  Stream<String> streamChat(String prompt, {int? docId, List<String>? directChunks}) {
    return sessionQueue.runStream(() async* {
      if (directChunks != null) {
        injectKnowledgeText(directChunks);
        yield* streamChatInternal(prompt);
        return;
      }

      List<Map<String, dynamic>> chunks = [];
      try {
        final queryEmbedding = await _embeddingProvider.embed(prompt);
        if (_storageService.isInitialized) {
          chunks = _storageService.search(queryEmbedding, limit: 3);
        }
        if (chunks.isEmpty) {
          chunks = _storageService.getChunksForDocument(docId: docId, limit: 3);
        }
      } catch (e) {
        debugPrint('⚠️ RAG retrieval failed: $e. Using direct database fallback.');
        chunks = _storageService.getChunksForDocument(docId: docId, limit: 3);
      }
      
      _injectKnowledge(chunks);
      yield* streamChatInternal(prompt);
    });
  }
}



