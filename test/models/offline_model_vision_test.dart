import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';

void main() {
  group('VisionConfig and OfflineModel Vision Integration', () {
    test('VisionConfig serializes and deserializes cleanly', () {
      final config = VisionConfig(
        mmprojUrl: 'https://example.com/mmproj.gguf',
        mmprojFilename: 'mmproj.gguf',
        mmprojSize: 102815168,
        minImageTokens: 64,
        maxImageTokens: 256,
        projectorType: 'siglip',
        sha256: 'abc123',
      );

      final json = config.toJson();
      expect(json['mmprojUrl'], 'https://example.com/mmproj.gguf');
      expect(json['mmprojFilename'], 'mmproj.gguf');
      expect(json['mmprojSize'], 102815168);
      expect(json['minImageTokens'], 64);
      expect(json['maxImageTokens'], 256);
      expect(json['projectorType'], 'siglip');
      expect(json['sha256'], 'abc123');

      final reconstructed = VisionConfig.fromJson(json);
      expect(reconstructed.mmprojUrl, config.mmprojUrl);
      expect(reconstructed.mmprojFilename, config.mmprojFilename);
      expect(reconstructed.mmprojSize, config.mmprojSize);
      expect(reconstructed.minImageTokens, 64);
      expect(reconstructed.maxImageTokens, 256);
      expect(reconstructed.projectorType, 'siglip');
      expect(reconstructed.sha256, 'abc123');
    });

    test('OfflineModel correctly reports isVision and totalSizeBytes', () {
      final textModel = OfflineModel(
        id: 'test-text',
        name: 'Test Text Model',
        author: 'denizen',
        size: 500000000,
        filename: 'text.gguf',
      );

      expect(textModel.isVision, isFalse);
      expect(textModel.totalSizeBytes, 500000000);
      expect(textModel.minRamMB, 2048);

      final visionModel = textModel.copyWith(
        id: 'test-vision',
        minRamMB: 4096,
        vision: VisionConfig(
          mmprojUrl: 'https://example.com/mmproj.gguf',
          mmprojFilename: 'mmproj.gguf',
          mmprojSize: 100000000,
        ),
      );

      expect(visionModel.isVision, isTrue);
      expect(visionModel.minRamMB, 4096);
      expect(visionModel.totalSizeBytes, 600000000);
      expect(visionModel.totalSizeMB, closeTo(572.2, 0.5));

      final json = visionModel.toJson();
      final fromJson = OfflineModel.fromJson(json);
      expect(fromJson.isVision, isTrue);
      expect(fromJson.minRamMB, 4096);
      expect(fromJson.vision?.mmprojSize, 100000000);
      expect(fromJson.totalSizeBytes, 600000000);
    });

    test('DefaultOfflineModels provides verified vision models with exact byte sizes', () {
      final ultraLight = DefaultOfflineModels.getUltraLightVisionModel();
      expect(ultraLight.id, 'lfm2.5-vl-450m-q4');
      expect(ultraLight.isVision, isTrue);
      expect(ultraLight.minRamMB, 2048);
      expect(ultraLight.size, 219311264);
      expect(ultraLight.vision?.mmprojSize, 102815168);
      expect(ultraLight.totalSizeBytes, 322126432);

      final balanced = DefaultOfflineModels.getInspectionVisionModel();
      expect(balanced.id, 'lfm2.5-vl-1.6b-extract-q4');
      expect(balanced.isVision, isTrue);
      expect(balanced.minRamMB, 4096);
      expect(balanced.size, 730896192);
      expect(balanced.vision?.mmprojSize, 583109792);
      expect(balanced.totalSizeBytes, 1314005984);

      final allVision = DefaultOfflineModels.getVisionModels();
      expect(allVision.length, 2);
      expect(allVision.map((m) => m.id), containsAll(['lfm2.5-vl-450m-q4', 'lfm2.5-vl-1.6b-extract-q4']));
    });

    test('DefaultOfflineModels.getAvailableModelsFor filters strictly on RAM floor', () {
      // 1GB RAM: No models qualify
      final at1GB = DefaultOfflineModels.getAvailableModelsFor(1024);
      expect(at1GB, isEmpty);

      // 2GB RAM: Ultra-light 450M vision qualifies; 1.6B does NOT
      final at2GB = DefaultOfflineModels.getAvailableModelsFor(2048);
      final ids2GB = at2GB.map((m) => m.id).toList();
      expect(ids2GB, contains('lfm2.5-vl-450m-q4'));
      expect(ids2GB, isNot(contains('lfm2.5-vl-1.6b-extract-q4')));

      // 3GB RAM: Ultra-light 450M vision qualifies; 1.6B does NOT
      final at3GB = DefaultOfflineModels.getAvailableModelsFor(3072);
      final ids3GB = at3GB.map((m) => m.id).toList();
      expect(ids3GB, contains('lfm2.5-vl-450m-q4'));
      expect(ids3GB, isNot(contains('lfm2.5-vl-1.6b-extract-q4')));

      // 4GB RAM: Both 450M and 1.6B vision models qualify
      final at4GB = DefaultOfflineModels.getAvailableModelsFor(4096);
      final ids4GB = at4GB.map((m) => m.id).toList();
      expect(ids4GB, contains('lfm2.5-vl-450m-q4'));
      expect(ids4GB, contains('lfm2.5-vl-1.6b-extract-q4'));
    });
  });
}
