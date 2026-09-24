class PrintProject {
  final String fileName;
  final String? sourcePath;
  final int width;
  final int height;

  final double cyan;
  final double magenta;
  final double yellow;
  final double black;

  final DateTime createdAt;

  const PrintProject({
    required this.fileName,
    this.sourcePath,
    required this.width,
    required this.height,
    required this.cyan,
    required this.magenta,
    required this.yellow,
    required this.black,
    required this.createdAt,
  });

  PrintProject copyWith({
    String? fileName,
    String? sourcePath,
    int? width,
    int? height,
    double? cyan,
    double? magenta,
    double? yellow,
    double? black,
    DateTime? createdAt,
  }) {
    return PrintProject(
      fileName: fileName ?? this.fileName,
      sourcePath: sourcePath ?? this.sourcePath,
      width: width ?? this.width,
      height: height ?? this.height,
      cyan: cyan ?? this.cyan,
      magenta: magenta ?? this.magenta,
      yellow: yellow ?? this.yellow,
      black: black ?? this.black,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'sourcePath': sourcePath,
      'width': width,
      'height': height,
      'cyan': cyan,
      'magenta': magenta,
      'yellow': yellow,
      'black': black,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PrintProject.fromJson(Map<String, dynamic> json) {
    return PrintProject(
      fileName: json['fileName'] as String? ?? 'Untitled',
      sourcePath: json['sourcePath'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      cyan: (json['cyan'] as num?)?.toDouble() ?? 0,
      magenta: (json['magenta'] as num?)?.toDouble() ?? 0,
      yellow: (json['yellow'] as num?)?.toDouble() ?? 0,
      black: (json['black'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(
            json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }
}
