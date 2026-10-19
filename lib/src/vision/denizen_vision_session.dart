import 'dart:typed_data';
import 'package:meta/meta.dart';
import '../services/offline_ai_service.dart';
import 'vision_results.dart';

export 'vision_results.dart';

/// A session specifically designed for multimodal (Vision) capabilities.
/// 
/// Interacts with local quantized vision-language models (e.g. LFM2.5-VL)
/// to inspect field photos, meters, diagnostic test strips, and documents.
///
/// **Status:** Experimental (v2.0 Preview).
@experimental
class DenizenVisionSession {
  final String _systemPrompt;
  final OfflineAIService _aiService;

  DenizenVisionSession({
    String? systemPrompt,
    OfflineAIService? aiService,
  })  : _systemPrompt = systemPrompt ??
            'You are a helpful visual assistant. Describe images accurately and concisely.',
        _aiService = aiService ?? OfflineAIService.instance;

  /// System prompt configured for this vision session.
  String get systemPrompt => _systemPrompt;

  /// Analyzes an image with a general prompt.
  /// 
  /// The [imageBytes] should be a raw byte array (JPEG or PNG).
  /// [prompt] defaults to asking what is in the image.
  Future<String> analyzeImage(
    Uint8List imageBytes, {
    String prompt = "What is in this image?",
  }) async {
    final formattedPrompt = '<|im_start|>system\n$_systemPrompt<|im_end|>\n'
        '<|im_start|>user\n<image>\n$prompt<|im_end|>\n'
        '<|im_start|>assistant\n';

    return await _aiService.generateVision(
      imageBytes: imageBytes,
      prompt: formattedPrompt,
      maxTokens: 256,
      temperature: 0.1,
    );
  }

  /// Reads an analog dial, pressure gauge, or digital meter.
  /// 
  /// Uses strict anti-hallucination prompting: if the needle or reading is blurry,
  /// obstructed, or cut off, the model is instructed to output "UNREADABLE"
  /// rather than guessing digits.
  Future<MeterReadingResult> readMeterOrGauge(
    Uint8List imageBytes, {
    String? unitHint,
  }) async {
    final unitClause = unitHint != null ? ' The expected unit is $unitHint.' : '';
    final prompt =
        'Look only at the numeric reading on this meter, gauge, or dial.$unitClause '
        'If the reading is blurry, cut off, obstructed, or not clearly legible, respond exactly "UNREADABLE". '
        'Otherwise, respond strictly with: VALUE: <number> UNIT: <unit>.';

    final output = await analyzeImage(imageBytes, prompt: prompt);
    return _parseMeterReading(output, unitHint);
  }

  /// Evaluates a rapid lateral flow diagnostic test strip (e.g. malaria, pregnancy).
  /// 
  /// Forces single-token classification between POSITIVE, NEGATIVE, INVALID, and UNCLEAR.
  Future<TestStripResult> inspectTestStrip(
    Uint8List imageBytes, {
    required String testType,
  }) async {
    final prompt =
        'This is a $testType rapid diagnostic lateral flow test strip with Control (C) and Test (T) lines. '
        'If the photo is too blurry, dark, or impossible to determine with confidence, respond exactly "UNCLEAR". '
        'If the Control (C) line is missing, broken, or not visible, respond exactly "INVALID". '
        'If both Control (C) and Test (T) lines are clearly visible, respond exactly "POSITIVE". '
        'If only the Control (C) line is visible and Test (T) is absent, respond exactly "NEGATIVE". '
        'Respond strictly with one of these words: POSITIVE, NEGATIVE, INVALID, UNCLEAR.';

    final output = await analyzeImage(imageBytes, prompt: prompt);
    return _parseTestStrip(output);
  }

  /// Inspects agricultural leaves and crops for disease symptoms or pest damage.
  Future<CropHealthResult> inspectCropHealth(
    Uint8List imageBytes, {
    String? cropType,
  }) async {
    final cropClause = cropType != null ? ' for $cropType' : '';
    final prompt =
        'Inspect this agricultural leaf or plant photo$cropClause. '
        'If the leaf is healthy with no signs of disease, blight, or pests, respond "HEALTHY: No visible disease symptoms." '
        'If disease, blight, fungal infection, or pest damage is observed, respond "DISEASED: <name of disease or symptom>." '
        'If the photo is too blurry, poorly lit, or not a plant leaf, respond "UNCLEAR: Cannot identify leaf."';

    final output = await analyzeImage(imageBytes, prompt: prompt);
    return _parseCropHealth(output);
  }

  /// Extracts structured attributes and status checks from an inspection sheet or equipment tag.
  Future<InspectionDocResult> parseInspectionReport(Uint8List imageBytes) async {
    const prompt =
        'Extract all key-value inspection attributes, serial numbers, checklist items, and statuses from this document or equipment label. '
        'If the document is illegible, unreadable, or cut off, respond "ILLEGIBLE". '
        'Otherwise, output each attribute in the format: <Field Name>: <Value>, followed by SUMMARY: <brief summary>.';

    final output = await analyzeImage(imageBytes, prompt: prompt);
    return _parseInspectionDoc(output);
  }

  // --- Parsing Helpers ---

  MeterReadingResult _parseMeterReading(String raw, String? fallbackUnit) {
    final upper = raw.trim().toUpperCase();
    if (upper.contains('UNREADABLE') || upper.contains('UNCLEAR')) {
      return MeterReadingResult(
        isReadable: false,
        rawOutput: raw,
      );
    }

    // Try extracting VALUE: <number> and UNIT: <unit>
    final valueRegex = RegExp(r'VALUE:\s*([\d\.]+)');
    final unitRegex = RegExp(r'UNIT:\s*([A-Za-z/%]+)');

    final valueMatch = valueRegex.firstMatch(raw);
    final unitMatch = unitRegex.firstMatch(raw);

    double? val;
    if (valueMatch != null) {
      val = double.tryParse(valueMatch.group(1) ?? '');
    } else {
      // Fallback: search for first float/integer in raw string
      final numRegex = RegExp(r'[-+]?\d*\.?\d+');
      final match = numRegex.firstMatch(raw);
      if (match != null) {
        val = double.tryParse(match.group(0) ?? '');
      }
    }

    final unit = unitMatch?.group(1) ?? fallbackUnit;

    return MeterReadingResult(
      numericValue: val,
      unit: unit,
      isReadable: val != null,
      rawOutput: raw,
    );
  }

  TestStripResult _parseTestStrip(String raw) {
    final upper = raw.trim().toUpperCase();
    if (upper.contains('POSITIVE')) {
      return TestStripResult(
        status: TestStripStatus.positive,
        rawOutput: raw,
      );
    }
    if (upper.contains('NEGATIVE')) {
      return TestStripResult(
        status: TestStripStatus.negative,
        rawOutput: raw,
      );
    }
    if (upper.contains('INVALID')) {
      return TestStripResult(
        status: TestStripStatus.invalid,
        rawOutput: raw,
      );
    }
    return TestStripResult(
      status: TestStripStatus.unclear,
      rawOutput: raw,
    );
  }

  CropHealthResult _parseCropHealth(String raw) {
    final upper = raw.trim().toUpperCase();
    if (upper.contains('HEALTHY')) {
      return CropHealthResult(
        condition: 'Healthy',
        isHealthy: true,
        isConfident: true,
        rawOutput: raw,
      );
    }
    if (upper.contains('DISEASED')) {
      final parts = raw.split(':');
      final condition = parts.length > 1 ? parts[1].trim() : 'Diseased';
      return CropHealthResult(
        condition: condition,
        isHealthy: false,
        isConfident: true,
        rawOutput: raw,
      );
    }
    return CropHealthResult(
      condition: 'Unclear',
      isHealthy: false,
      isConfident: false,
      rawOutput: raw,
    );
  }

  InspectionDocResult _parseInspectionDoc(String raw) {
    final upper = raw.trim().toUpperCase();
    if (upper.contains('ILLEGIBLE') || upper.contains('UNREADABLE')) {
      return InspectionDocResult(
        extractedFields: {},
        summary: 'Document illegible or obstructed.',
        isLegible: false,
        rawOutput: raw,
      );
    }

    final fields = <String, String>{};
    String summary = '';

    final lines = raw.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.toUpperCase().startsWith('SUMMARY:')) {
        summary = trimmed.substring(8).trim();
      } else if (trimmed.contains(':')) {
        final colonIndex = trimmed.indexOf(':');
        final key = trimmed.substring(0, colonIndex).trim();
        final value = trimmed.substring(colonIndex + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          fields[key] = value;
        }
      }
    }

    return InspectionDocResult(
      extractedFields: fields,
      summary: summary.isNotEmpty ? summary : raw,
      isLegible: fields.isNotEmpty || summary.isNotEmpty,
      rawOutput: raw,
    );
  }
}
