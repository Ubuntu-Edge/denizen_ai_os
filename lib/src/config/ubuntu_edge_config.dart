/// Ubuntu Edge Platform configuration for the Denizen AI SDK.
///
/// Pass an instance of this class to [DenizenAI.configure] at app startup
/// to opt into Ubuntu Edge Platform services. All fields are optional and
/// default to sensible values.
///
/// **Important:** Ubuntu Edge Platform services are currently in development.
/// Providing this config today registers your intent and ensures your app code
/// is forward-compatible — the SDK will activate the relevant service hooks
/// automatically when the platform launches without any changes on your end.
///
/// ## Quick Start
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
///
/// Obtain an API key at: https://platform.ubuntuedge.io/dashboard
class UbuntuEdgeConfig {
  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Your Ubuntu Edge Platform API key.
  ///
  /// Obtain from: https://platform.ubuntuedge.io/dashboard
  final String apiKey;

  /// Base URL for the Ubuntu Edge API.
  ///
  /// Override only for self-hosted or staging deployments.
  /// Defaults to the Ubuntu Edge production endpoint.
  final String baseUrl;

  // ---------------------------------------------------------------------------
  // Smart Cloud Fallback
  // ---------------------------------------------------------------------------

  /// When `true`, the SDK will automatically route inference to the Ubuntu Edge
  /// cloud GPU cluster if:
  ///   - The on-device model is not loaded, or
  ///   - Local inference exceeds [fallbackLatencyThresholdMs].
  ///
  /// All cloud inference operates under **Zero Data Retention (ZDR)** rules —
  /// prompts are processed in GPU RAM and immediately purged on completion.
  /// No prompt or response is ever stored or logged.
  ///
  /// Defaults to `true`.
  final bool enableCloudFallback;

  /// Minimum on-device inference time (in milliseconds) before the SDK
  /// considers routing to the Ubuntu Edge cloud.
  ///
  /// Only relevant when [enableCloudFallback] is `true`.
  /// Defaults to `8000` ms (8 seconds).
  final int fallbackLatencyThresholdMs;

  // ---------------------------------------------------------------------------
  // OTA Model Updates
  // ---------------------------------------------------------------------------

  /// When `true`, the SDK will periodically check the Ubuntu Edge CDN for
  /// compressed delta patches for your locally downloaded GGUF models.
  ///
  /// Delta patches are typically 70–85% smaller than full model downloads,
  /// reducing data usage and update time significantly.
  ///
  /// Defaults to `true`.
  final bool enableOtaModelUpdates;

  /// How often the SDK checks for OTA model updates (in hours).
  ///
  /// Only relevant when [enableOtaModelUpdates] is `true`.
  /// Defaults to `24` hours (daily).
  final int otaCheckIntervalHours;

  // ---------------------------------------------------------------------------
  // Multilingual Gateway
  // ---------------------------------------------------------------------------

  /// When `true`, enables the Ubuntu Edge Multilingual Gateway — a cloud-side
  /// translation and routing layer that allows your on-device model to handle
  /// 50+ languages it may not natively support, including:
  ///   - Swahili, Amharic, Hausa, Yoruba, Zulu (Pan-African)
  ///   - Arabic, Hindi, Bengali, Urdu (South/West Asia)
  ///   - And 40+ more global languages.
  ///
  /// The gateway translates the user query → English → model → response →
  /// back to the user's language, transparently.
  ///
  /// Defaults to `false` (opt-in, as it requires a round-trip to the gateway).
  final bool enableMultilingualGateway;

  /// The BCP-47 language code to use for the multilingual gateway response.
  ///
  /// Examples: `'sw'` (Swahili), `'am'` (Amharic), `'ha'` (Hausa), `'auto'`.
  ///
  /// Set to `'auto'` to let the gateway detect the user's language automatically.
  /// Only relevant when [enableMultilingualGateway] is `true`.
  final String multilingualTargetLanguage;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  const UbuntuEdgeConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.ubuntuedge.io/v1',
    this.enableCloudFallback = true,
    this.fallbackLatencyThresholdMs = 8000,
    this.enableOtaModelUpdates = true,
    this.otaCheckIntervalHours = 24,
    this.enableMultilingualGateway = false,
    this.multilingualTargetLanguage = 'auto',
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns a summary string of active features, useful for debug logging.
  String get featureSummary {
    final features = <String>[];
    if (enableCloudFallback)      features.add('CloudFallback(>${fallbackLatencyThresholdMs}ms)');
    if (enableOtaModelUpdates)    features.add('OTA(${otaCheckIntervalHours}h)');
    if (enableMultilingualGateway) features.add('Multilingual($multilingualTargetLanguage)');
    return features.isEmpty ? 'none' : features.join(', ');
  }

  @override
  String toString() =>
      'UbuntuEdgeConfig(baseUrl: $baseUrl, features: $featureSummary)';
}
