/// Severity rating of a single probe result.
///
/// Named [ProbeSeverity] — not "Level" — to keep it apart from [ProbeState],
/// the unknown/running/ok/stale/failed state machine: severity is the rating
/// of an observed probe result, not a lifecycle state.
enum ProbeSeverity { ok, warn, crit, unknown }

class ProbeResult {
  const ProbeResult({
    required this.level,
    required this.key,
    this.params = const <String, String>{},
    this.at,
  });

  final ProbeSeverity level;
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
      ProbeResult(level: ProbeSeverity.ok, key: id, at: DateTime.now());
}
