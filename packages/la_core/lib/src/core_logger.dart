/// The core's logging seam. Contracts only — no `dart:io`, no Flutter. The
/// app binds this to its own logger, so core code can log without importing
/// anything the GTK/Flutter layer owns.
abstract interface class CoreLogger {
  void debug(String message);
  void info(String message);
  void warn(String message, [Object? error]);
  void error(String message, [Object? error, StackTrace? stack]);
}

/// Default logger for the core: a library must not force its callers to wire
/// one up just to satisfy a constructor.
class NullLogger implements CoreLogger {
  const NullLogger();

  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warn(String message, [Object? error]) {}

  @override
  void error(String message, [Object? error, StackTrace? stack]) {}
}
