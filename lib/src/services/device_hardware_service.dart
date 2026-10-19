import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/default_offline_models.dart';
import '../models/offline_model.dart';

/// Exception thrown when a device does not meet the hardware requirements for an offline model.
class IncompatibleHardwareException implements Exception {
  final String modelId;
  final int requiredRamMB;
  final int availableRamMB;
  final String message;

  IncompatibleHardwareException({
    required this.modelId,
    required this.requiredRamMB,
    required this.availableRamMB,
    String? message,
  }) : message = message ??
            'Device has $availableRamMB MB RAM, but model $modelId requires at least $requiredRamMB MB to avoid lowmemorykiller termination.';

  @override
  String toString() => 'IncompatibleHardwareException: $message';
}

/// Service for inspecting device hardware (RAM, CPU, platform) and gating models safely.
class DeviceHardwareService {
  static const MethodChannel _systemChannel =
      MethodChannel('com.agilebiz.denizen_ai/system');

  static int? _cachedTotalRamMB;

  /// Whether on-device multimodal vision inference is supported on this platform.
  /// 
  /// NOTE: v2.0 native C++ clip.cpp/llava.cpp compilation targets Android (arm64-v8a).
  /// iOS native compilation is explicitly scheduled for v2.1.
  static bool get isVisionSupported => Platform.isAndroid;

  /// Retrieves the total physical device RAM in Megabytes (MB).
  /// 
  /// On Android, queries `ActivityManager.MemoryInfo.totalMem` via platform channel.
  /// On other platforms or in testing environments, returns a safe default.
  static Future<int> getTotalRamMB() async {
    if (_cachedTotalRamMB != null) {
      return _cachedTotalRamMB!;
    }

    if (Platform.isAndroid) {
      try {
        final result = await _systemChannel.invokeMethod<int>('getDeviceTotalRam');
        if (result != null && result > 0) {
          final ramMB = result ~/ (1024 * 1024);
          _cachedTotalRamMB = ramMB;
          return ramMB;
        }
      } catch (e) {
        debugPrint('⚠️ DeviceHardwareService: Failed to query total RAM from platform channel: $e');
      }
    }

    // Default fallback for test harnesses and non-Android environments
    return 4096;
  }

  /// Sets a manual RAM override for unit testing and deterministic simulation.
  @visibleForTesting
  static void setMockTotalRamMB(int? ramMB) {
    _cachedTotalRamMB = ramMB;
  }

  /// Evaluates whether the current device meets all hardware and platform requirements
  /// to download and run [model].
  static Future<bool> canRunModel(OfflineModel model) async {
    if (model.isVision && !isVisionSupported) {
      return false;
    }
    final ramMB = await getTotalRamMB();
    return ramMB >= model.minRamMB;
  }

  /// Returns only the models from [DefaultOfflineModels] that the current device can safely run.
  static Future<List<OfflineModel>> getAvailableModels() async {
    final ramMB = await getTotalRamMB();
    final models = DefaultOfflineModels.getAvailableModelsFor(ramMB);
    if (!isVisionSupported) {
      return models.where((m) => !m.isVision).toList();
    }
    return models;
  }

  /// Asserts that the device can run [model], throwing an [IncompatibleHardwareException]
  /// if the physical RAM floor is not met.
  static Future<void> assertCompatibility(OfflineModel model) async {
    final ramMB = await getTotalRamMB();
    if (ramMB < model.minRamMB) {
      throw IncompatibleHardwareException(
        modelId: model.id,
        requiredRamMB: model.minRamMB,
        availableRamMB: ramMB,
      );
    }
  }
}
