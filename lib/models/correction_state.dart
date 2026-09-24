class CorrectionState {
  final double cyan;
  final double magenta;
  final double yellow;
  final double black;

  const CorrectionState({
    required this.cyan,
    required this.magenta,
    required this.yellow,
    required this.black,
  });

  static const zero = CorrectionState(
    cyan: 0,
    magenta: 0,
    yellow: 0,
    black: 0,
  );
}
