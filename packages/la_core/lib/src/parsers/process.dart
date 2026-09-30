/// One row of `ps -eo <metric>,args` output.
class ProcessStat {
  final String metricValue;
  final String processName;

  const ProcessStat(this.metricValue, this.processName);
}

/// Pure parser for `ps -eo <metric>,args` output, split out so it can be
/// tested without shelling out.
///
/// Lines that carry a metric but no command are skipped rather than throwing;
/// `ps` emits those for kernel threads on some systems. Skipped lines do not
/// count towards `count` — the result holds up to `count` valid entries.
/// A `count` of 0 or less disables the limit: every valid entry is returned.
List<ProcessStat> parsePsOutput(String cmdResult, int count) {
  var processes = List<ProcessStat>.empty(growable: true);
  for (var line in cmdResult.split("\n").skip(1)) {
    var values = line.split(" ");
    values.removeWhere((x) => x == "");
    if (values.length < 2) {
      continue;
    }
    processes.add(ProcessStat(values[0], values[1].split("/").last));
    if (processes.length == count) {
      break;
    }
  }

  return processes;
}
