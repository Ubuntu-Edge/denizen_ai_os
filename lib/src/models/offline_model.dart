/// Configuration for vision-capable models (VLMs) requiring an mmproj projector.
class VisionConfig {
  final String mmprojUrl;
  final String mmprojFilename;
  final int mmprojSize; // Exact byte count for integrity and progress weighting
  final int? imageSize; // e.g. 384 or 448
  final int minImageTokens; // e.g. 64 (speed dial)
  final int maxImageTokens; // e.g. 256 for gauge, 512 for dense forms
  final String projectorType; // 'siglip'
  final String? sha256;

  const VisionConfig({
    required this.mmprojUrl,
    required this.mmprojFilename,
    required this.mmprojSize,
    this.imageSize,
    this.minImageTokens = 64,
    this.maxImageTokens = 256,
    this.projectorType = 'siglip',
    this.sha256,
  });

  /// Get mmproj size in MB
  double get sizeMB => mmprojSize / (1024 * 1024);

  Map<String, dynamic> toJson() => {
        'mmprojUrl': mmprojUrl,
        'mmprojFilename': mmprojFilename,
        'mmprojSize': mmprojSize,
        if (imageSize != null) 'imageSize': imageSize,
        'minImageTokens': minImageTokens,
        'maxImageTokens': maxImageTokens,
        'projectorType': projectorType,
        if (sha256 != null) 'sha256': sha256,
      };

  factory VisionConfig.fromJson(Map<String, dynamic> json) => VisionConfig(
        mmprojUrl: json['mmprojUrl'] as String,
        mmprojFilename: json['mmprojFilename'] as String,
        mmprojSize: json['mmprojSize'] as int? ?? 0,
        imageSize: json['imageSize'] as int?,
        minImageTokens: json['minImageTokens'] as int? ?? 64,
        maxImageTokens: json['maxImageTokens'] as int? ?? 256,
        projectorType: json['projectorType'] as String? ?? 'siglip',
        sha256: json['sha256'] as String?,
      );
}

/// Represents an offline GGUF model available for local inference
class OfflineModel {
  final String id;
  final String name;
  final String author;
  final int size; // in bytes (base LM)
  final String? downloadUrl;
  final String? filename;
  final bool isDownloaded;
  final double downloadProgress; // 0.0 to 100.0
  final String? localPath;
  final String? description;
  final String? quantization; // Q4_K_M, Q6_K, Q8_0, etc.
  final List<String> tags; // ['medical', 'reasoning', etc.]
  final int contextSize; // Context window size
  final VisionConfig? vision; // Vision configuration if multimodal
  final int minRamMB; // Minimum physical device RAM required in MB (e.g. 2048 or 4096)

  OfflineModel({
    required this.id,
    required this.name,
    required this.author,
    required this.size,
    this.downloadUrl,
    this.filename,
    this.isDownloaded = false,
    this.downloadProgress = 0.0,
    this.localPath,
    this.description,
    this.quantization,
    this.tags = const [],
    this.contextSize = 2048,
    this.vision,
    this.minRamMB = 2048,
  });

  /// Whether this model supports multimodal vision input
  bool get isVision => vision != null;

  /// Total download size including mmproj if vision model
  int get totalSizeBytes => size + (vision?.mmprojSize ?? 0);

  /// Get base model size in MB
  double get sizeMB => size / (1024 * 1024);

  /// Get base model size in GB
  double get sizeGB => size / (1024 * 1024 * 1024);

  /// Get total size in MB (including mmproj if vision model)
  double get totalSizeMB => totalSizeBytes / (1024 * 1024);

  /// Create a copy with modified fields
  OfflineModel copyWith({
    String? id,
    String? name,
    String? author,
    int? size,
    String? downloadUrl,
    String? filename,
    bool? isDownloaded,
    double? downloadProgress,
    String? localPath,
    String? description,
    String? quantization,
    List<String>? tags,
    int? contextSize,
    VisionConfig? vision,
    int? minRamMB,
  }) {
    return OfflineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      size: size ?? this.size,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      filename: filename ?? this.filename,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: localPath ?? this.localPath,
      description: description ?? this.description,
      quantization: quantization ?? this.quantization,
      tags: tags ?? this.tags,
      contextSize: contextSize ?? this.contextSize,
      vision: vision ?? this.vision,
      minRamMB: minRamMB ?? this.minRamMB,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author': author,
        'size': size,
        'downloadUrl': downloadUrl,
        'filename': filename,
        'isDownloaded': isDownloaded,
        'downloadProgress': downloadProgress,
        'localPath': localPath,
        'description': description,
        'quantization': quantization,
        'tags': tags,
        'contextSize': contextSize,
        if (vision != null) 'vision': vision!.toJson(),
        'minRamMB': minRamMB,
      };

  /// Create from JSON
  factory OfflineModel.fromJson(Map<String, dynamic> json) {
    return OfflineModel(
      id: json['id'] as String,
      name: json['name'] as String,
      author: json['author'] as String,
      size: json['size'] as int,
      downloadUrl: json['downloadUrl'] as String?,
      filename: json['filename'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      downloadProgress: (json['downloadProgress'] as num?)?.toDouble() ?? 0.0,
      localPath: json['localPath'] as String?,
      description: json['description'] as String?,
      quantization: json['quantization'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      contextSize: json['contextSize'] as int? ?? 2048,
      vision: json['vision'] != null
          ? VisionConfig.fromJson(json['vision'] as Map<String, dynamic>)
          : null,
      minRamMB: json['minRamMB'] as int? ?? 2048,
    );
  }

  @override
  String toString() =>
      'OfflineModel(id: $id, name: $name, totalSize: ${totalSizeMB.toStringAsFixed(1)} MB, isVision: $isVision)';
}
