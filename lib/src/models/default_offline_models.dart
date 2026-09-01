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
        size: 398000000, // ~398 MB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Ultra-lightweight model (~398MB). Fast inference, low RAM usage, ideal for mobile devices.',
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
        size: 1630000000, // ~1.63 GB
        downloadUrl:
            'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
        filename: 'gemma-2-2b-it-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Google Gemma 2 2B Instruct (~1.63GB). Superior reasoning, math, and instruction following for RAG.',
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
        size: 758000000, // ~758 MB
        downloadUrl:
            'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Great balance of intelligence and size (~758MB). Fast instruction following for general tasks.',
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
        size: 980000000, // ~980 MB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Higher capability model (~980MB). Excellent reasoning while keeping RAM under 1.5GB.',
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
        size: 2390000000, // 2.39 GB
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
        size: 398000000, // ~398 MB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Ultra-lightweight default model (~398MB). Fast inference, low RAM usage, ideal for mobile tutoring.',
        tags: ['education', 'tutoring', 'fast', 'mobile', 'recommended'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 2: Google Gemma 2 2B Instruct (~1.63 GB)
      OfflineModel(
        id: 'gemma-2-2b-q4',
        name: 'Gemma 2 2B Instruct',
        author: 'Google',
        size: 1630000000, // ~1.63 GB
        downloadUrl:
            'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
        filename: 'gemma-2-2b-it-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Google Gemma 2 2B Instruct (~1.63GB). Superior reasoning, math, and instruction following for RAG tutoring.',
        tags: ['education', 'google', 'gemma', 'reasoning', 'quality', 'recommended'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 3: Balanced General & Socratic Tutoring (~758 MB)
      OfflineModel(
        id: 'llama-3.2-1b-q4',
        name: 'Llama 3.2 1B Instruct',
        author: 'Meta',
        size: 758000000, // ~758 MB
        downloadUrl:
            'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'High instruction following quality (~758MB). Excellent for Socratic tutoring.',
        tags: ['education', 'tutoring', 'instructions', 'balanced'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 4: Advanced Reasoning & Multilingual / Kiswahili (~980 MB)
      OfflineModel(
        id: 'qwen2.5-1.5b-q4',
        name: 'Qwen2.5 1.5B Instruct',
        author: 'Alibaba',
        size: 980000000, // ~980 MB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Higher capability model (~980MB). Excellent multilingual and Kiswahili support with deep reasoning.',
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
        size: 2390000000, // 2.39 GB
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

  /// Get all recommended models across all domains (medical, education, general)
  static List<OfflineModel> getAllRecommendedModels() {
    final medical = getMedicalModels();
    final education = getEducationModels();
    final seen = <String>{};
    final combined = <OfflineModel>[];
    for (final m in [...medical, ...education]) {
      if (seen.add(m.id)) {
        combined.add(m);
      }
    }
    return combined;
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
}
