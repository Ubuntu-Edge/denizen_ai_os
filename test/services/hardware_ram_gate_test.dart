import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';

void main() {
  group('DeviceHardwareService RAM Gating Tests', () {
    final ultraLightModel = DefaultOfflineModels.getUltraLightVisionModel();
    final balancedModel = DefaultOfflineModels.getInspectionVisionModel();

    tearDown(() {
      DeviceHardwareService.setMockTotalRamMB(null);
    });

    test('3GB RAM device allows 450M ultra-light tier but strictly gates 1.6B tier', () async {
      DeviceHardwareService.setMockTotalRamMB(3072);

      expect(await DeviceHardwareService.getTotalRamMB(), 3072);

      // On Android platform or when mocked
      if (DeviceHardwareService.isVisionSupported) {
        expect(await DeviceHardwareService.canRunModel(ultraLightModel), isTrue);
        expect(await DeviceHardwareService.canRunModel(balancedModel), isFalse);
      }

      // Asserting compatibility on ultra-light passes
      await expectLater(
        DeviceHardwareService.assertCompatibility(ultraLightModel),
        completes,
      );

      // Asserting compatibility on 1.6B throws IncompatibleHardwareException
      expect(
        () => DeviceHardwareService.assertCompatibility(balancedModel),
        throwsA(isA<IncompatibleHardwareException>().having(
          (e) => e.requiredRamMB,
          'requiredRamMB',
          4096,
        ).having(
          (e) => e.availableRamMB,
          'availableRamMB',
          3072,
        )),
      );
    });

    test('4GB+ RAM device clears both 450M and 1.6B tiers', () async {
      DeviceHardwareService.setMockTotalRamMB(4096);

      if (DeviceHardwareService.isVisionSupported) {
        expect(await DeviceHardwareService.canRunModel(ultraLightModel), isTrue);
        expect(await DeviceHardwareService.canRunModel(balancedModel), isTrue);
      }

      await expectLater(
        DeviceHardwareService.assertCompatibility(ultraLightModel),
        completes,
      );
      await expectLater(
        DeviceHardwareService.assertCompatibility(balancedModel),
        completes,
      );
    });

    test('Severe low-memory device (<2GB) rejects all models requiring 2GB+', () async {
      DeviceHardwareService.setMockTotalRamMB(1536); // 1.5 GB device

      expect(
        () => DeviceHardwareService.assertCompatibility(ultraLightModel),
        throwsA(isA<IncompatibleHardwareException>().having(
          (e) => e.availableRamMB,
          'availableRamMB',
          1536,
        )),
      );
    });
  });
}
