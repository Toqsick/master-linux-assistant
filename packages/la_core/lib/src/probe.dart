enum ProbeLevel { ok, warn, crit, unknown }

class ProbeResult {
  const ProbeResult({
    required this.level,
    required this.key,
    this.params = const <String, String>{},
    this.at,
  });

  final ProbeLevel level;
  final String key;
  final Map<String, String> params;
  final DateTime? at;

  String describe() =>
      '${level.name}:$key${at == null ? '' : ' @ ${at!.toIso8601String()}'}';
}

abstract interface class Probe {
  String get id;
  Future<ProbeResult> run();
}

class SelfProbe implements Probe {
  @override
  String get id => 'probe.self';

  @override
  Future<ProbeResult> run() async =>
      ProbeResult(level: ProbeLevel.ok, key: id, at: DateTime.now());
}
