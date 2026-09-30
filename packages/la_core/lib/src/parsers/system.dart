/// Uptime as a value+unit pair. The unit is one of `m` (minutes), `h` (hours)
/// or `d` (days).
class Uptime {
  final String unit;
  final int value;

  const Uptime(this.unit, this.value);
}

/// Pure parser for `uptime` output, split out so it can be tested without
/// shelling out.
Uptime parseUptime(String output) {
  var values = output.replaceAll(RegExp(r" +"), " ").trim().split(" ");
  if (values[2].contains(":")) {
    var arr = values[2].split(":");
    int hourValue = int.parse(arr[0]);
    int minuteValue = int.parse(arr[1].replaceAll(",", ""));
    return hourValue == 0 ? Uptime("m", minuteValue) : Uptime("h", hourValue);
  } else {
    // The new uptime output could be: 1 day,  1:23
    if (output.contains("min")) {
      return Uptime("m", int.parse(values[2]));
    }
    if (output.contains("day")) {
      return Uptime("d", int.parse(values[2]));
    }
    if (output.contains("hour")) {
      return Uptime("h", int.parse(values[2]));
    }
    return Uptime("m", int.parse(values[2]));
  }
}

/// The one-minute figure from the first column of `/proc/loadavg`.
double parseLoadAvg(String content) =>
    double.parse(content.trim().split(" ")[0]);
