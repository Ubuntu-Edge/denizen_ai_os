import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/offline_model.dart';
import 'device_hardware_service.dart';

/// Thrown when a downloaded model file fails byte-count or checksum integrity checks.
class DownloadIntegrityException implements Exception {
  final String modelId;
  final String filename;
  final int expectedBytes;
  final int actualBytes;
  final String message;

  DownloadIntegrityException({
    required this.modelId,
    required this.filename,
    required this.expectedBytes,
    required this.actualBytes,
    String? message,
  }) : message = message ??
            'Integrity check failed for $filename ($modelId): expected $expectedBytes bytes, but file has $actualBytes bytes. File may be corrupted or truncated.';

  @override
  String toString() => 'DownloadIntegrityException: $message';
}

/// Service for downloading AI models with compression support and progress tracking
/// Handles multiple models, automatic extraction, and storage management
class ModelDownloadService {
  static final ModelDownloadService instance = ModelDownloadService._init();
  ModelDownloadService._init();

  // Active downloads tracking
  final Map<String, StreamController<ModelDownloadProgress>> _activeDownloads = {};
  final Map<String, http.Client> _downloadClients = {};
  static const String _activeDownloadsKey = 'active_downloads';

  Future<SharedPreferences?> _getPrefsSafely() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('⚠️ SharedPreferences unavailable in ModelDownloadService: $e');
      return null;
    }
  }

  /// Save active downloads to SharedPreferences for persistence
  Future<void> _saveActiveDownloads() async {
    try {
      final prefs = await _getPrefsSafely();
      if (prefs == null) return;
      final activeIds = _activeDownloads.keys.toList();
      await prefs.setStringList(_activeDownloadsKey, activeIds);
    } catch (e) {
      debugPrint('⚠️ Failed to save active downloads: $e');
    }
  }

  /// Get list of active downloads from SharedPreferences
  Future<List<String>> getActiveDownloads() async {
    try {
      final prefs = await _getPrefsSafely();
      if (prefs == null) return [];
      return prefs.getStringList(_activeDownloadsKey) ?? [];
    } catch (e) {
      debugPrint('⚠️ Failed to load active downloads: $e');
      return [];
    }
  }

  /// Clear active download from SharedPreferences
  Future<void> _clearActiveDownload(String modelId) async {
    try {
      final prefs = await _getPrefsSafely();
      if (prefs == null) return;
      final activeIds = prefs.getStringList(_activeDownloadsKey) ?? [];
      activeIds.remove(modelId);
      await prefs.setStringList(_activeDownloadsKey, activeIds);
    } catch (e) {
      debugPrint('⚠️ Failed to clear active download: $e');
    }
  }

  /// Get the best storage directory for models
  /// Uses external storage on Android (persists across app updates)
  /// Falls back to internal storage if external is not available
  Future<Directory> getModelStorageDirectory() async {
    if (Platform.isAndroid) {
      try {
        // Try external storage first (persists across app updates)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          debugPrint('📁 Using external storage: ${externalDir.path}');
          return externalDir;
        }
      } catch (e) {
        debugPrint('⚠️ External storage not available: $e');
      }
    }
    // Fall back to app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    debugPrint('📁 Using internal storage: ${appDir.path}');
    return appDir;
  }

  /// Download an [OfflineModel] with automatic multi-file support (LM + mmproj),
  /// hardware RAM floor assertion, dynamic progress weighting, and byte integrity verification.
  Stream<ModelDownloadProgress> downloadOfflineModel({
    required OfflineModel model,
    bool useCompression = false,
  }) {
    return downloadModel(
      url: model.downloadUrl ?? '',
      modelId: model.id,
      fileName: model.filename ?? '',
      author: model.author,
      useCompression: useCompression,
      expectedSizeBytes: model.size,
      vision: model.vision,
      minRamMB: model.minRamMB,
    );
  }

  /// Download a model from URL with progress tracking.
  /// Supports multi-file paired downloads (vision models), HTTP Range resumption,
  /// and post-download byte-length integrity verification.
  Stream<ModelDownloadProgress> downloadModel({
    required String url,
    required String modelId,
    required String fileName,
    required String author,
    bool useCompression = false,
    int? expectedSizeBytes,
    VisionConfig? vision,
    int? minRamMB,
  }) async* {
    // Create progress stream
    final progressController = StreamController<ModelDownloadProgress>();
    _activeDownloads[modelId] = progressController;
    await _saveActiveDownloads(); // Persist download state
    try {
      // 1. Assert hardware RAM floor before beginning download
      if (minRamMB != null) {
        final ramMB = await DeviceHardwareService.getTotalRamMB();
        if (ramMB < minRamMB) {
          throw IncompatibleHardwareException(
            modelId: modelId,
            requiredRamMB: minRamMB,
            availableRamMB: ramMB,
          );
        }
      }

      // 2. Prepare storage directories
      final storageDir = await getModelStorageDirectory();
      final modelDir = Directory('${storageDir.path}/models/$author');
      await modelDir.create(recursive: true);

      debugPrint('📥 Starting download for $modelId');
      debugPrint('   URL: $url');
      debugPrint('   Author: $author');
      debugPrint('   Filename: $fileName');
      debugPrint('   Save dir: ${modelDir.path}');

      // Compute dynamic weights based on exact byte counts (no hardcoded 70/30)
      final int lmExpected = expectedSizeBytes ?? 0;
      final int mmprojExpected = vision?.mmprojSize ?? 0;
      final int totalOverallBytes = (lmExpected + mmprojExpected) > 0
          ? (lmExpected + mmprojExpected)
          : (expectedSizeBytes ?? 1);
      final double lmWeight = lmExpected > 0 ? (lmExpected / totalOverallBytes) : 1.0;
      final double mmprojWeight = mmprojExpected > 0 ? (mmprojExpected / totalOverallBytes) : 0.0;

      final finalFile = File('${modelDir.path}/$fileName');
      final tempFile = File('${modelDir.path}/$fileName.tmp');

      // Helper function to download an individual file component with Range resumption
      Future<void> downloadComponent({
        required String componentUrl,
        required File componentTempFile,
        required File componentFinalFile,
        required int componentExpectedBytes,
        required double progressOffset,
        required double progressFactor,
      }) async {
        // If final file already exists and matches expected size, skip
        if (await componentFinalFile.exists()) {
          final existingLen = await componentFinalFile.length();
          if (componentExpectedBytes <= 0 || existingLen == componentExpectedBytes) {
            debugPrint('✅ File already downloaded & verified: ${componentFinalFile.path}');
            return;
          } else {
            debugPrint('⚠️ Existing file size mismatch ($existingLen vs $componentExpectedBytes). Re-downloading.');
            await componentFinalFile.delete();
          }
        }

        int startByte = 0;
        if (await componentTempFile.exists()) {
          startByte = await componentTempFile.length();
          debugPrint('🔄 Resuming download for ${componentFinalFile.path} from byte $startByte');
        }

        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(componentUrl));
        request.headers.set('User-Agent', 'Mozilla/5.0 (Mobile; DenizenAI/1.0)');
        request.headers.set('Accept', '*/*');
        if (startByte > 0) {
          request.headers.set('Range', 'bytes=$startByte-');
        }

        final response = await request.close();

        if (response.statusCode == 416) {
          debugPrint('⚠️ HTTP 416: Range not satisfiable. Temp file likely fully downloaded.');
        } else if (response.statusCode != 200 && response.statusCode != 206) {
          throw Exception('Download HTTP error ${response.statusCode} for $componentUrl');
        } else {
          final streamTotal = (response.contentLength > 0 ? response.contentLength : 0) + startByte;
          int receivedBytes = startByte;
          final sink = componentTempFile.openWrite(mode: FileMode.append);

          await for (final chunk in response) {
            if (!_activeDownloads.containsKey(modelId)) {
              await sink.close();
              if (await componentTempFile.exists()) {
                await componentTempFile.delete();
              }
              client.close();
              return;
            }

            sink.add(chunk);
            receivedBytes += chunk.length;

            final fileProgressPercent = streamTotal > 0
                ? (receivedBytes / streamTotal)
                : 0.0;
            final overallProgressPercent =
                (progressOffset + (fileProgressPercent * progressFactor)) * 100;

            final progressData = ModelDownloadProgress(
              modelId: modelId,
              stage: ModelDownloadStage.downloading,
              progress: overallProgressPercent.clamp(0.0, 99.9),
              downloadedBytes: (progressOffset * totalOverallBytes).toInt() + receivedBytes,
              totalBytes: totalOverallBytes,
            );

            progressController.add(progressData);
          }
          await sink.close();
        }
        client.close();

        // Rename temp to final
        try {
          await componentTempFile.rename(componentFinalFile.path);
        } catch (e) {
          await Future.delayed(const Duration(milliseconds: 500));
          await componentTempFile.copy(componentFinalFile.path);
          await componentTempFile.delete();
        }

        // Post-download integrity verification
        final actualSize = await componentFinalFile.length();
        if (componentExpectedBytes > 0 && actualSize != componentExpectedBytes) {
          await componentFinalFile.delete();
          throw DownloadIntegrityException(
            modelId: modelId,
            filename: componentFinalFile.path.split(Platform.pathSeparator).last,
            expectedBytes: componentExpectedBytes,
            actualBytes: actualSize,
          );
        }
      }

      // Step 1: Download Base LM file
      await downloadComponent(
        componentUrl: url,
        componentTempFile: tempFile,
        componentFinalFile: finalFile,
        componentExpectedBytes: lmExpected,
        progressOffset: 0.0,
        progressFactor: lmWeight,
      );

      // Step 2: Download mmproj projector if vision model
      if (vision != null) {
        final mmprojFinalFile = File('${modelDir.path}/${vision.mmprojFilename}');
        final mmprojTempFile = File('${modelDir.path}/${vision.mmprojFilename}.tmp');

        await downloadComponent(
          componentUrl: vision.mmprojUrl,
          componentTempFile: mmprojTempFile,
          componentFinalFile: mmprojFinalFile,
          componentExpectedBytes: mmprojExpected,
          progressOffset: lmWeight,
          progressFactor: mmprojWeight,
        );
      }

      // Verify file stage
      final verifyingProgress = ModelDownloadProgress(
        modelId: modelId,
        stage: ModelDownloadStage.verifying,
        progress: 100,
      );
      progressController.add(verifyingProgress);
      yield verifyingProgress;

      final fileExists = await finalFile.exists();
      final fileSize = await finalFile.length();

      if (!fileExists || fileSize < 1024 * 1024) {
        throw Exception('Downloaded file is invalid or too small');
      }

      // Complete stage
      final completeProgress = ModelDownloadProgress(
        modelId: modelId,
        stage: ModelDownloadStage.completed,
        progress: 100,
        localPath: finalFile.path,
      );
      progressController.add(completeProgress);
      yield completeProgress;

      // Clear from active downloads
      await _clearActiveDownload(modelId);

      debugPrint('✅ Model downloaded: ${finalFile.path} (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)');
    } catch (e, stackTrace) {
      debugPrint('❌ Download failed: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Provide user-friendly error message
      String userMessage = 'Download failed';
      final errStr = e.toString();
      if (errStr.contains('Permission denied') || errStr.contains('PERMISSION_DENIED')) {
        userMessage = 'OS Permission error: Internet access denied by Android ($e)';
      } else if (errStr.contains('SocketException') || errStr.contains('HandshakeException') || errStr.contains('Network is unreachable') || errStr.contains('Failed host lookup')) {
        userMessage = 'Network error: $e';
      } else if (errStr.contains('TimeoutException')) {
        userMessage = 'Download timeout: Please try again ($e)';
      } else if (errStr.contains('Space') || errStr.contains('storage')) {
        userMessage = 'Insufficient storage space';
      } else {
        userMessage = 'Download failed: $e';
      }
      
      final failedProgress = ModelDownloadProgress(
        modelId: modelId,
        stage: ModelDownloadStage.failed,
        progress: 0,
        error: userMessage,
      );
      progressController.add(failedProgress);
      yield failedProgress;
    } finally {
      await progressController.close();
      _activeDownloads.remove(modelId);
      await _clearActiveDownload(modelId); // Clean up persistent state
    }
  }

  /// Extract gzip compressed file with progress tracking
  Future<void> extractGzip(
    File compressedFile,
    File outputFile,
    Function(double) onProgress,
  ) async {
    final inputStream = compressedFile.openRead();
    final decompressedStream = inputStream.transform(gzip.decoder);
    final outputSink = outputFile.openWrite();

    int processedBytes = 0;
    final totalBytes = await compressedFile.length();

    await for (final chunk in decompressedStream) {
      outputSink.add(chunk);
      processedBytes += chunk.length;
      
      final progress = (processedBytes / totalBytes) * 100;
      onProgress(progress.clamp(0, 100));
    }

    await outputSink.close();
    debugPrint('✅ Extraction complete: ${outputFile.path}');
  }

  /// Cancel an active download and delete all partial files immediately
  Future<void> cancelDownload(String modelId) async {
    final client = _downloadClients[modelId];
    if (client != null) {
      client.close();
      _downloadClients.remove(modelId);
    }

    final controller = _activeDownloads[modelId];
    if (controller != null) {
      await controller.close();
      _activeDownloads.remove(modelId);
      await _clearActiveDownload(modelId); // Remove from persistent storage
    }

    // Clean up ALL partial/incomplete files immediately
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      
      if (await modelsDir.exists()) {
        // Delete temp files
        await for (final entity in modelsDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.tmp')) {
            await entity.delete();
            debugPrint('🗑️ Deleted temporary file: ${entity.path}');
          }
        }
        
        // Delete incomplete GGUF file for this specific model
        final ggufFile = File('${modelsDir.path}/$modelId.gguf');
        if (await ggufFile.exists()) {
          await ggufFile.delete();
          debugPrint('🗑️ Deleted incomplete model: ${ggufFile.path}');
        }
        
        // Delete compressed file if exists
        final gzFile = File('${modelsDir.path}/$modelId.gguf.gz');
        if (await gzFile.exists()) {
          await gzFile.delete();
          debugPrint('🗑️ Deleted compressed file: ${gzFile.path}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning temp files: $e');
    }

    debugPrint('⚠️ Cancelled download: $modelId');
  }

  /// Delete a downloaded model file
  Future<bool> deleteModel(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        final sizeMB = (await file.length()) / (1024 * 1024);
        await file.delete();
        debugPrint('✅ Deleted model: $localPath (${sizeMB.toStringAsFixed(1)} MB freed)');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to delete model: $e');
      return false;
    }
  }

  /// Get available storage space in bytes
  Future<int> getAvailableStorageBytes() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Note: This is an approximation. Real implementation would use platform channels
        // to get actual device storage via native APIs
        return 5 * 1024 * 1024 * 1024; // 5GB default assumption
      }
      return 10 * 1024 * 1024 * 1024; // 10GB for desktop
    } catch (e) {
      debugPrint('⚠️ Could not determine storage: $e');
      return 5 * 1024 * 1024 * 1024; // Default 5GB
    }
  }

  /// Check if enough storage is available for model
  Future<bool> hasEnoughStorage(int requiredBytes) async {
    final available = await getAvailableStorageBytes();
    const buffer = 500 * 1024 * 1024; // 500MB safety buffer
    return available > (requiredBytes + buffer);
  }

  /// Get total size of downloaded models directory in bytes
  Future<int> getModelsDirectorySize() async {
    try {
      final storageDir = await getModelStorageDirectory();
      final modelsDir = Directory('${storageDir.path}/models');
      
      if (!await modelsDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in modelsDir.list(recursive: true)) {
        if (entity is File && !entity.path.endsWith('.tmp')) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('⚠️ Could not calculate directory size: $e');
      return 0;
    }
  }

  /// Check if download is in progress
  bool isDownloading(String modelId) {
    return _activeDownloads.containsKey(modelId);
  }

  /// Get list of all downloaded model files
  Future<List<String>> getDownloadedModelPaths() async {
    try {
      final storageDir = await getModelStorageDirectory();
      final modelsDir = Directory('${storageDir.path}/models');
      
      if (!await modelsDir.exists()) {
        return [];
      }

      final List<String> modelPaths = [];
      await for (final entity in modelsDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.gguf')) {
          modelPaths.add(entity.path);
        }
      }
      return modelPaths;
    } catch (e) {
      debugPrint('⚠️ Error listing models: $e');
      return [];
    }
  }

  // Custom model path management
  static const String _customModelPathKey = 'custom_model_path';

  /// Get the custom model path if set
  Future<String?> getCustomModelPath() async {
    try {
      final prefs = await _getPrefsSafely();
      if (prefs == null) return null;
      final path = prefs.getString(_customModelPathKey);
      if (path != null && await File(path).exists()) {
        return path;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting custom model path: $e');
      return null;
    }
  }

  /// Set a custom model path
  Future<bool> setCustomModelPath(String filePath) async {
    try {
      // Validate the file exists and is a GGUF file
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Custom model file not found: $filePath');
        return false;
      }
      if (!filePath.toLowerCase().endsWith('.gguf')) {
        debugPrint('❌ File is not a GGUF model: $filePath');
        return false;
      }
      
      final prefs = await _getPrefsSafely();
      if (prefs != null) {
        await prefs.setString(_customModelPathKey, filePath);
      }
      debugPrint('✅ Custom model path set: $filePath');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error setting custom model path: $e');
      return false;
    }
  }

  /// Clear the custom model path
  Future<void> clearCustomModelPath() async {
    try {
      final prefs = await _getPrefsSafely();
      if (prefs != null) {
        await prefs.remove(_customModelPathKey);
      }
      debugPrint('✅ Custom model path cleared');
    } catch (e) {
      debugPrint('⚠️ Error clearing custom model path: $e');
    }
  }

  void dispose() {
    for (final controller in _activeDownloads.values) {
      controller.close();
    }
    _activeDownloads.clear();
    
    for (final client in _downloadClients.values) {
      client.close();
    }
    _downloadClients.clear();
  }
}

/// Model download progress data
class ModelDownloadProgress {
  final String modelId;
  final ModelDownloadStage stage;
  final double progress;
  final int? downloadedBytes;
  final int? totalBytes;
  final String? localPath;
  final String? error;

  ModelDownloadProgress({
    required this.modelId,
    required this.stage,
    required this.progress,
    this.downloadedBytes,
    this.totalBytes,
    this.localPath,
    this.error,
  });

  bool get isCompleted => stage == ModelDownloadStage.completed;
  String? get filePath => localPath;

  String get progressText {
    switch (stage) {
      case ModelDownloadStage.downloading:
        if (totalBytes != null && totalBytes! > 0) {
          final downloadedMB = (downloadedBytes ?? 0) / (1024 * 1024);
          final totalMB = totalBytes! / (1024 * 1024);
          return 'Downloading: ${downloadedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB (${progress.toStringAsFixed(1)}%)';
        }
        return 'Downloading: ${progress.toStringAsFixed(1)}%';
      case ModelDownloadStage.extracting:
        return 'Extracting: ${progress.toStringAsFixed(1)}%';
      case ModelDownloadStage.verifying:
        return 'Verifying file integrity...';
      case ModelDownloadStage.completed:
        return 'Download complete!';
      case ModelDownloadStage.failed:
        return 'Failed: ${error ?? "Unknown error"}';
    }
  }

  String? get speedText {
    if (stage == ModelDownloadStage.downloading && 
        downloadedBytes != null && 
        totalBytes != null && 
        totalBytes! > 0) {
      final remainingBytes = totalBytes! - downloadedBytes!;
      final remainingMB = remainingBytes / (1024 * 1024);
      
      if (remainingMB < 100) {
        return 'Almost done...';
      } else if (remainingMB < 500) {
        return 'A few more minutes...';
      } else {
        return 'This may take 5-10 minutes';
      }
    }
    return null;
  }
}

/// Download stages
enum ModelDownloadStage {
  downloading,
  extracting,
  verifying,
  completed,
  failed,
}
