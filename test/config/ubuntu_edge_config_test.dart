import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';

void main() {
  group('UbuntuEdgeConfig Unit Tests', () {
    tearDown(() {
      // Reset DenizenAI edge config after each test
      DenizenAI.configure(edgeConfig: null);
    });

    test('UbuntuEdgeConfig initializes with default values', () {
      const config = UbuntuEdgeConfig(apiKey: 'ue-test-12345');

      expect(config.apiKey, equals('ue-test-12345'));
      expect(config.baseUrl, equals('https://api.ubuntuedge.io/v1'));
      expect(config.enableCloudFallback, isTrue);
      expect(config.fallbackLatencyThresholdMs, equals(8000));
      expect(config.enableOtaModelUpdates, isTrue);
      expect(config.otaCheckIntervalHours, equals(24));
      expect(config.enableMultilingualGateway, isFalse);
      expect(config.multilingualTargetLanguage, equals('auto'));
    });

    test('UbuntuEdgeConfig accepts custom values and generates feature summary', () {
      const config = UbuntuEdgeConfig(
        apiKey: 'ue-custom-key',
        baseUrl: 'https://staging.ubuntuedge.io/v1',
        enableCloudFallback: true,
        fallbackLatencyThresholdMs: 5000,
        enableOtaModelUpdates: true,
        otaCheckIntervalHours: 12,
        enableMultilingualGateway: true,
        multilingualTargetLanguage: 'sw',
      );

      expect(config.apiKey, equals('ue-custom-key'));
      expect(config.baseUrl, equals('https://staging.ubuntuedge.io/v1'));
      expect(config.enableCloudFallback, isTrue);
      expect(config.fallbackLatencyThresholdMs, equals(5000));
      expect(config.enableOtaModelUpdates, isTrue);
      expect(config.otaCheckIntervalHours, equals(12));
      expect(config.enableMultilingualGateway, isTrue);
      expect(config.multilingualTargetLanguage, equals('sw'));

      final summary = config.featureSummary;
      expect(summary, contains('CloudFallback(>5000ms)'));
      expect(summary, contains('OTA(12h)'));
      expect(summary, contains('Multilingual(sw)'));

      final str = config.toString();
      expect(str, contains('https://staging.ubuntuedge.io/v1'));
      expect(str, contains(summary));
    });

    test('UbuntuEdgeConfig returns none when all features are disabled', () {
      const config = UbuntuEdgeConfig(
        apiKey: 'ue-bare-key',
        enableCloudFallback: false,
        enableOtaModelUpdates: false,
        enableMultilingualGateway: false,
      );

      expect(config.featureSummary, equals('none'));
    });

    test('DenizenAI.configure sets static edgeConfig and isEdgeConfigured getter', () {
      expect(DenizenAI.isEdgeConfigured, isFalse);
      expect(DenizenAI.edgeConfig, isNull);

      const config = UbuntuEdgeConfig(apiKey: 'ue-prod-key');
      DenizenAI.configure(edgeConfig: config);

      expect(DenizenAI.isEdgeConfigured, isTrue);
      expect(DenizenAI.edgeConfig, equals(config));
      expect(DenizenAI.edgeConfig?.apiKey, equals('ue-prod-key'));

      // Test resetting config to null
      DenizenAI.configure(edgeConfig: null);
      expect(DenizenAI.isEdgeConfigured, isFalse);
      expect(DenizenAI.edgeConfig, isNull);
    });
  });
}
