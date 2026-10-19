import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';

class MockVisionAIService implements OfflineAIService {
  String responseToReturn;
  String? lastPrompt;

  MockVisionAIService({this.responseToReturn = ''});

  @override
  bool get isModelLoaded => true;

  @override
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.2,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
    List<String>? stopSequences,
  }) async {
    lastPrompt = prompt;
    return responseToReturn;
  }

  @override
  Future<String> generateVision({
    required Uint8List imageBytes,
    required String prompt,
    int maxTokens = 256,
    double temperature = 0.1,
  }) async {
    lastPrompt = prompt;
    return responseToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DenizenVisionSession', () {
    final mockBytes = Uint8List.fromList([1, 2, 3, 4]);

    test('Initialization with default and custom prompt', () {
      final defaultSession = DenizenVisionSession();
      expect(defaultSession.systemPrompt, contains('visual assistant'));

      final customSession = DenizenVisionSession(systemPrompt: 'You are an agricultural botanist.');
      expect(customSession.systemPrompt, 'You are an agricultural botanist.');
    });

    test('analyzeImage fails closed when native vision pipeline is not active', () async {
      final session = DenizenVisionSession();
      // Must throw StateError or UnsupportedError rather than silently hallucinating text
      expect(
        () => session.analyzeImage(mockBytes),
        throwsA(isA<StateError>()),
      );
    });

    test('readMeterOrGauge parses structured VALUE and UNIT correctly', () async {
      final mockAi = MockVisionAIService(responseToReturn: 'VALUE: 142.8 UNIT: PSI');
      final session = DenizenVisionSession(aiService: mockAi);

      final result = await session.readMeterOrGauge(mockBytes, unitHint: 'PSI');
      expect(result.isReadable, isTrue);
      expect(result.numericValue, 142.8);
      expect(result.unit, 'PSI');
      expect(result.rawOutput, 'VALUE: 142.8 UNIT: PSI');
      expect(mockAi.lastPrompt, contains('<image>'));
      expect(mockAi.lastPrompt, contains('UNREADABLE'));
    });

    test('readMeterOrGauge respects UNREADABLE and UNCLEAR escape hatches', () async {
      final unreadableAi = MockVisionAIService(responseToReturn: 'UNREADABLE');
      final session1 = DenizenVisionSession(aiService: unreadableAi);
      final res1 = await session1.readMeterOrGauge(mockBytes);
      expect(res1.isReadable, isFalse);
      expect(res1.numericValue, isNull);

      final unclearAi = MockVisionAIService(responseToReturn: 'UNCLEAR: glare on dial glass');
      final session2 = DenizenVisionSession(aiService: unclearAi);
      final res2 = await session2.readMeterOrGauge(mockBytes);
      expect(res2.isReadable, isFalse);
      expect(res2.numericValue, isNull);
    });

    test('readMeterOrGauge extracts standalone number with fallback unit', () async {
      final mockAi = MockVisionAIService(responseToReturn: 'The dial indicates approximately 3.75 bar');
      final session = DenizenVisionSession(aiService: mockAi);

      final result = await session.readMeterOrGauge(mockBytes, unitHint: 'bar');
      expect(result.isReadable, isTrue);
      expect(result.numericValue, 3.75);
      expect(result.unit, 'bar');
    });

    test('inspectTestStrip classifies positive, negative, invalid, and unclear', () async {
      final sessionPos = DenizenVisionSession(aiService: MockVisionAIService(responseToReturn: 'POSITIVE'));
      final pos = await sessionPos.inspectTestStrip(mockBytes, testType: 'Malaria Pf');
      expect(pos.status, TestStripStatus.positive);
      expect(pos.isReliable, isTrue);

      final sessionNeg = DenizenVisionSession(aiService: MockVisionAIService(responseToReturn: 'NEGATIVE'));
      final neg = await sessionNeg.inspectTestStrip(mockBytes, testType: 'Malaria Pf');
      expect(neg.status, TestStripStatus.negative);
      expect(neg.isReliable, isTrue);

      final sessionInv = DenizenVisionSession(aiService: MockVisionAIService(responseToReturn: 'INVALID: no C line'));
      final inv = await sessionInv.inspectTestStrip(mockBytes, testType: 'Malaria Pf');
      expect(inv.status, TestStripStatus.invalid);
      expect(inv.isReliable, isFalse);

      final sessionUnc = DenizenVisionSession(aiService: MockVisionAIService(responseToReturn: 'UNCLEAR: blurry photo'));
      final unc = await sessionUnc.inspectTestStrip(mockBytes, testType: 'Malaria Pf');
      expect(unc.status, TestStripStatus.unclear);
      expect(unc.isReliable, isFalse);
    });

    test('inspectCropHealth handles healthy, diseased, and unclear diagnostics', () async {
      final sessionHealthy = DenizenVisionSession(
        aiService: MockVisionAIService(responseToReturn: 'HEALTHY: No visible disease symptoms.'),
      );
      final healthy = await sessionHealthy.inspectCropHealth(mockBytes, cropType: 'Maize');
      expect(healthy.isHealthy, isTrue);
      expect(healthy.isConfident, isTrue);
      expect(healthy.condition, 'Healthy');

      final sessionDiseased = DenizenVisionSession(
        aiService: MockVisionAIService(responseToReturn: 'DISEASED: Northern Corn Leaf Blight'),
      );
      final diseased = await sessionDiseased.inspectCropHealth(mockBytes, cropType: 'Maize');
      expect(diseased.isHealthy, isFalse);
      expect(diseased.isConfident, isTrue);
      expect(diseased.condition, 'Northern Corn Leaf Blight');

      final sessionUnclear = DenizenVisionSession(
        aiService: MockVisionAIService(responseToReturn: 'UNCLEAR: Cannot identify leaf'),
      );
      final unclear = await sessionUnclear.inspectCropHealth(mockBytes);
      expect(unclear.isHealthy, isFalse);
      expect(unclear.isConfident, isFalse);
    });

    test('parseInspectionReport parses key-value pairs, summary, and ILLEGIBLE status', () async {
      final sampleDoc = '''
Tag Number: TAG-9921
Location: Pump House B
Pressure Valve: PASSED
Oil Level: NORMAL
SUMMARY: All quarterly maintenance checklist items verified.
''';
      final sessionDoc = DenizenVisionSession(
        aiService: MockVisionAIService(responseToReturn: sampleDoc),
      );
      final docResult = await sessionDoc.parseInspectionReport(mockBytes);
      expect(docResult.isLegible, isTrue);
      expect(docResult.extractedFields['Tag Number'], 'TAG-9921');
      expect(docResult.extractedFields['Location'], 'Pump House B');
      expect(docResult.extractedFields['Pressure Valve'], 'PASSED');
      expect(docResult.extractedFields['Oil Level'], 'NORMAL');
      expect(docResult.summary, 'All quarterly maintenance checklist items verified.');

      final illegibleSession = DenizenVisionSession(
        aiService: MockVisionAIService(responseToReturn: 'ILLEGIBLE: photo too dark to read text'),
      );
      final illegibleResult = await illegibleSession.parseInspectionReport(mockBytes);
      expect(illegibleResult.isLegible, isFalse);
      expect(illegibleResult.extractedFields, isEmpty);
    });
  });
}
