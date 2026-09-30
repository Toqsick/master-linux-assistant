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
/// `ps` emits those for kernel threads on some systems.
List<ProcessStat> parsePsOutput(String cmdResult, int count) {
  var processes = List<ProcessStat>.empty(growable: true);
  for (var line in cmdResult.split("\n").skip(1).take(count)) {
    var values = line.split(" ");
    values.removeWhere((x) => x == "");
    if (values.length < 2) {
      continue;
    }
    processes.add(ProcessStat(values[0], values[1].split("/").last));
  }

  return processes;
}
