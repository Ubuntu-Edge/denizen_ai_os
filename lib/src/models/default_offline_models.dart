import 'offline_model.dart';

/// Default offline models based on PocketPal AI configuration
/// These models are optimized for mobile devices and medical use cases
class DefaultOfflineModels {
  /// Get list of recommended models for CHW medical use
  static List<OfflineModel> getMedicalModels() {
    return [
      // Priority 1: Ultra-lightweight & Fast (Default Recommended for Mobile)
      OfflineModel(
        id: 'qwen2.5-0.5b-q4',
        name: 'Qwen2.5 0.5B Instruct',
        author: 'Alibaba',
        size: 491400032, // Exact: ~491.4 MB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Ultra-lightweight model (~491MB). Fast inference, low RAM usage, ideal for mobile devices.',
        tags: ['lightweight', 'fast', 'mobile', 'recommended'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 2: Gemma 2 2B Instruct (High Intelligence Google Model)
      OfflineModel(
        id: 'gemma-2-2b-q4',
        name: 'Gemma 2 2B Instruct',
        author: 'Google',
        size: 1708582752, // Exact: ~1.71 GB
        downloadUrl:
            'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
        filename: 'gemma-2-2b-it-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Google Gemma 2 2B Instruct (~1.71GB). Superior reasoning, math, and instruction following for RAG.',
        tags: ['google', 'gemma', 'reasoning', 'quality', 'recommended'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),



      // Priority 3: High Quality Mobile Model
      OfflineModel(
        id: 'llama-3.2-1b-q4',
        name: 'Llama 3.2 1B Instruct',
        author: 'Meta',
        size: 807694464, // Exact: ~807.7 MB
        downloadUrl:
            'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Great balance of intelligence and size (~808MB). Fast instruction following for general tasks.',
        tags: ['instructions', 'balanced', 'quality'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 4: Qwen 1.5B (Quantized Q4_K_M)
      OfflineModel(
        id: 'qwen2.5-1.5b-q4',
        name: 'Qwen2.5 1.5B Instruct (Q4)',
        author: 'Alibaba',
        size: 1117320736, // Exact: ~1.12 GB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Higher capability model (~1.12GB). Excellent reasoning while keeping RAM under 1.5GB.',
        tags: ['reasoning', 'multilingual', 'high-quality'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 5: Phi-3.5 Mini (High RAM Devices Only)
      OfflineModel(
        id: 'phi-3.5-mini-q4',
        name: 'Phi-3.5 Mini Instruct',
        author: 'Microsoft',
        size: 2393232672, // Exact: ~2.39 GB
        downloadUrl:
            'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
        filename: 'phi-3.5-mini-instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Large model (2.39 GB). High reasoning power, requires devices with 6GB+ RAM.',
        tags: ['medical', 'heavy', 'high-ram'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),
    ];
  }

  /// Get list of recommended models for student tutoring and educational use
  static List<OfflineModel> getEducationModels() {
    return [
      // Priority 1: Ultra-lightweight default model (~398MB)
      OfflineModel(
        id: 'qwen2.5-0.5b-q4',
        name: 'Qwen2.5 0.5B Instruct',
        author: 'Alibaba',
        size: 491400032, // Exact: ~491.4 MB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Ultra-lightweight default model (~491MB). Fast inference, low RAM usage, ideal for mobile tutoring.',
        tags: ['education', 'tutoring', 'fast', 'mobile', 'recommended'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 2: Google Gemma 2 2B Instruct (~1.71 GB)
      OfflineModel(
        id: 'gemma-2-2b-q4',
        name: 'Gemma 2 2B Instruct',
        author: 'Google',
        size: 1708582752, // Exact: ~1.71 GB
        downloadUrl:
            'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
        filename: 'gemma-2-2b-it-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Google Gemma 2 2B Instruct (~1.71GB). Superior reasoning, math, and instruction following for RAG tutoring.',
        tags: ['education', 'google', 'gemma', 'reasoning', 'quality', 'recommended'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 3: Balanced General & Socratic Tutoring (~808 MB)
      OfflineModel(
        id: 'llama-3.2-1b-q4',
        name: 'Llama 3.2 1B Instruct',
        author: 'Meta',
        size: 807694464, // Exact: ~807.7 MB
        downloadUrl:
            'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'High instruction following quality (~808MB). Excellent for Socratic tutoring.',
        tags: ['education', 'tutoring', 'instructions', 'balanced'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 4: Advanced Reasoning & Multilingual / Kiswahili (~1.12 GB)
      OfflineModel(
        id: 'qwen2.5-1.5b-q4',
        name: 'Qwen2.5 1.5B Instruct',
        author: 'Alibaba',
        size: 1117320736, // Exact: ~1.12 GB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Higher capability model (~1.12GB). Excellent multilingual and Kiswahili support with deep reasoning.',
        tags: ['education', 'multilingual', 'kiswahili', 'reasoning'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 5: Heavy Reasoning (High-RAM devices only, ~2.39 GB)
      OfflineModel(
        id: 'phi-3.5-mini-q4',
        name: 'Phi-3.5 Mini Instruct',
        author: 'Microsoft',
        size: 2393232672, // Exact: ~2.39 GB
        downloadUrl:
            'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
        filename: 'phi-3.5-mini-instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Heavy reasoning model (2.39 GB). Requires devices with 6GB+ RAM.',
        tags: ['education', 'reasoning', 'high-ram'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),
    ];
  }

  /// Get list of multimodal vision models
  static List<OfflineModel> getVisionModels() {
    return [
      getUltraLightVisionModel(),
      getInspectionVisionModel(),
    ];
  }

  /// Priority 1 (Default Ultra-Light Vision): LFM2.5-VL-450M (~322 MB total)
  /// Runs comfortably in ~700MB-1GB runtime RAM on 2GB/3GB devices.
  static OfflineModel getUltraLightVisionModel() {
    return OfflineModel(
      id: 'lfm2.5-vl-450m-q4',
      name: 'LFM2.5-VL 450M (Vision)',
      author: 'Liquid AI',
      size: 219311264, // Exact LM size: ~219.3 MB
      downloadUrl:
          'https://huggingface.co/LiquidAI/LFM2.5-VL-450M-GGUF/resolve/main/LFM2.5-VL-450M-Q4_0.gguf',
      filename: 'LFM2.5-VL-450M-Q4_0.gguf',
      quantization: 'Q4_0',
      description:
          'Ultra-light mobile vision model (~322MB total). Fast inference, ~700MB-1GB runtime RAM, ideal for 2GB/3GB phones in the field.',
      tags: ['vision', 'multimodal', 'lightweight', 'edge', 'recommended'],
      contextSize: 2048,
      minRamMB: 2048,
      vision: const VisionConfig(
        // NOTE: mmproj filename uses lowercase "450m" — verified against LiquidAI repo tree, do not rename.
        mmprojUrl:
            'https://huggingface.co/LiquidAI/LFM2.5-VL-450M-GGUF/resolve/main/mmproj-LFM2.5-VL-450m-Q8_0.gguf',
        mmprojFilename: 'mmproj-LFM2.5-VL-450m-Q8_0.gguf',
        mmprojSize: 102815168, // Exact mmproj size: ~102.8 MB
        minImageTokens: 64,
        maxImageTokens: 256,
        projectorType: 'siglip',
      ),
    );
  }

  /// Priority 2 (Field Reports & Structured Extraction): LFM2.5-VL-1.6B-Extract
  /// Requires 4GB+ RAM hardware floor (~1.31GB total download, ~1.8-2.2GB runtime RAM).
  static OfflineModel getInspectionVisionModel() {
    return OfflineModel(
      id: 'lfm2.5-vl-1.6b-extract-q4',
      name: 'LFM2.5-VL 1.6B Extract (Vision)',
      author: 'Liquid AI',
      size: 730896192, // Exact LM size: ~730.9 MB
      downloadUrl:
          'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-Extract-GGUF/resolve/main/LFM2.5-VL-1.6B-Extract-Q4_K_M.gguf',
      filename: 'LFM2.5-VL-1.6B-Extract-Q4_K_M.gguf',
      quantization: 'Q4_K_M',
      description:
          'Specialized vision model for dense inspection forms, complex meters, and structured attribute extraction. Requires 4GB+ RAM.',
      tags: ['vision', 'multimodal', 'ocr', 'inspection', 'structured-data'],
      contextSize: 2048,
      minRamMB: 4096, // Hard gate: 4GB+ RAM required
      vision: const VisionConfig(
        // NOTE: Extract model uses uppercase "1.6B" with -Extract- prefix — verified against repo tree.
        mmprojUrl:
            'https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B-Extract-GGUF/resolve/main/mmproj-LFM2.5-VL-1.6B-Extract-Q8_0.gguf',
        mmprojFilename: 'mmproj-LFM2.5-VL-1.6B-Extract-Q8_0.gguf',
        mmprojSize: 583109792, // Exact mmproj size: ~583.1 MB
        minImageTokens: 128,
        maxImageTokens: 512,
        projectorType: 'siglip',
      ),
    );
  }

  /// Get all recommended models across all domains (medical, education, vision)
  static List<OfflineModel> getAllRecommendedModels() {
    final medical = getMedicalModels();
    final education = getEducationModels();
    final vision = getVisionModels();
    final seen = <String>{};
    final combined = <OfflineModel>[];
    for (final m in [...medical, ...education, ...vision]) {
      if (seen.add(m.id)) {
        combined.add(m);
      }
    }
    return combined;
  }

  /// Filter models available for a given device RAM in MB.
  /// Prevents lower-RAM devices (e.g. 2GB/3GB) from being shown models that would crash the app.
  static List<OfflineModel> getAvailableModelsFor(int deviceRamMB) {
    return getAllRecommendedModels()
        .where((model) => deviceRamMB >= model.minRamMB)
        .toList();
  }

  /// Get model by ID across all recommended models
  static OfflineModel? getModelById(String id) {
    try {
      return getAllRecommendedModels().firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get models filtered by tags across all recommended models
  static List<OfflineModel> getModelsByTags(List<String> tags) {
    return getAllRecommendedModels()
        .where((model) => model.tags.any((tag) => tags.contains(tag)))
        .toList();
  }

  /// Get recommended model for device RAM
  static OfflineModel getRecommendedForRAM(int ramMB) {
    final models = getAllRecommendedModels();

    if (ramMB < 4096) {
      // < 4GB RAM: Use Qwen 0.5B
      return models.firstWhere((m) => m.id == 'qwen2.5-0.5b-q4', orElse: () => models.first);
    } else if (ramMB < 6144) {
      // 4-6GB RAM: Use Qwen 0.5B or Llama 1B
      return models.firstWhere((m) => m.id == 'qwen2.5-0.5b-q4' || m.id == 'llama-3.2-1b-q4', orElse: () => models.first);
    } else if (ramMB < 8192) {
      // 6-8GB RAM: Use Llama 3.2 1B or Qwen 1.5B
      return models.firstWhere((m) => m.id == 'llama-3.2-1b-q4' || m.id == 'qwen2.5-1.5b-q4', orElse: () => models.first);
    } else {
      // 8GB+ RAM: Use Phi-3.5 Mini or Qwen 1.5B
      return models.firstWhere((m) => m.id == 'phi-3.5-mini-q4' || m.id == 'qwen2.5-1.5b-q4', orElse: () => models.first);
    }
  }

  /// Get the recommended model for medical CHW use (default)
  static OfflineModel getDefaultMedicalModel() {
    return getMedicalModels().firstWhere((m) => m.id == 'qwen2.5-0.5b-q4');
  }

  /// Get the recommended model for educational tutoring use (default)
  static OfflineModel getDefaultEducationModel() {
    return getEducationModels().firstWhere((m) => m.id == 'qwen2.5-0.5b-q4');
  }

  /// Get the recommended vision model for general mobile use (default)
  static OfflineModel getDefaultVisionModel() {
    return getUltraLightVisionModel();
  }
}
