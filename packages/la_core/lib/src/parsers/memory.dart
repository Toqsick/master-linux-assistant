/// Memory figures as reported by `free -m`, in mebibytes.
///
/// Deliberately not `@immutable`: that annotation is analysis-only, the fields
/// are already final and the constructor const, and importing `package:meta`
/// would break `la_core`'s "no dependencies" contract.
class MemoryInfo {
  final int totalMb;
  final int usedMb;
  final int swapTotalMb;
  final int swapUsedMb;

  const MemoryInfo({
    required this.totalMb,
    required this.usedMb,
    required this.swapTotalMb,
    required this.swapUsedMb,
  });

  double get usedRatio => totalMb > 0 ? usedMb / totalMb : 0;

  bool get hasSwap => swapTotalMb > 0;

  double get swapUsedRatio => swapTotalMb > 0 ? swapUsedMb / swapTotalMb : 0;

  /// Pure parser for `free -m`. Returns null when the output is unusable, so
  /// callers can keep the previous reading instead of showing a broken tile.
  static MemoryInfo? parseFreeOutput(String output) {
    final lines = output.split("\n");
    if (lines.length < 2) {
      return null;
    }

    List<String> columns(String line) =>
        line.split(" ").where((x) => x.isNotEmpty).toList();

    try {
      final mem = columns(lines[1]);
      if (mem.length < 3) {
        return null;
      }
      int swapTotal = 0;
      int swapUsed = 0;
      if (lines.length >= 3) {
        final swap = columns(lines[2]);
        if (swap.length >= 3) {
          swapTotal = int.parse(swap[1]);
          swapUsed = int.parse(swap[2]);
        }
      }
      return MemoryInfo(
        totalMb: int.parse(mem[1]),
        usedMb: int.parse(mem[2]),
        swapTotalMb: swapTotal,
        swapUsedMb: swapUsed,
      );
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }
}
