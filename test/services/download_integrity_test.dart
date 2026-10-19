import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';

void main() {
  group('Download Integrity & Dynamic Weighting Tests', () {
    test('DownloadIntegrityException formats details clearly', () {
      final ex = DownloadIntegrityException(
        modelId: 'lfm2.5-vl-450m-q4',
        filename: 'LFM2.5-VL-450M-Q4_0.gguf',
        expectedBytes: 219311264,
        actualBytes: 150000000,
      );

      expect(ex.modelId, 'lfm2.5-vl-450m-q4');
      expect(ex.filename, 'LFM2.5-VL-450M-Q4_0.gguf');
      expect(ex.expectedBytes, 219311264);
      expect(ex.actualBytes, 150000000);
      expect(ex.toString(), contains('expected 219311264 bytes'));
      expect(ex.toString(), contains('150000000 bytes'));
      expect(ex.toString(), contains('corrupted or truncated'));
    });

    test('Dynamic progress weights match exact file proportions', () {
      final model450M = DefaultOfflineModels.getUltraLightVisionModel();
      final totalBytes450 = model450M.size + model450M.vision!.mmprojSize;
      final lmWeight450 = model450M.size / totalBytes450;
      final mmprojWeight450 = model450M.vision!.mmprojSize / totalBytes450;

      expect(lmWeight450 + mmprojWeight450, closeTo(1.0, 0.000001));
      // ~68.1% LM, ~31.9% mmproj
      expect(lmWeight450, closeTo(0.6808, 0.001));
      expect(mmprojWeight450, closeTo(0.3192, 0.001));

      final model16B = DefaultOfflineModels.getInspectionVisionModel();
      final totalBytes16B = model16B.size + model16B.vision!.mmprojSize;
      final lmWeight16B = model16B.size / totalBytes16B;
      final mmprojWeight16B = model16B.vision!.mmprojSize / totalBytes16B;

      expect(lmWeight16B + mmprojWeight16B, closeTo(1.0, 0.000001));
      // ~55.6% LM, ~44.4% mmproj
      expect(lmWeight16B, closeTo(0.5562, 0.001));
      expect(mmprojWeight16B, closeTo(0.4438, 0.001));
    });
  });
}
