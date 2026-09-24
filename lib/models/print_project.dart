class PrintProject {
  final String fileName;
  final int width;
  final int height;

  final double cyan;
  final double magenta;
  final double yellow;
  final double black;

  final DateTime createdAt;

  const PrintProject({
    required this.fileName,
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
      width: width ?? this.width,
      height: height ?? this.height,
      cyan: cyan ?? this.cyan,
      magenta: magenta ?? this.magenta,
      yellow: yellow ?? this.yellow,
      black: black ?? this.black,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
