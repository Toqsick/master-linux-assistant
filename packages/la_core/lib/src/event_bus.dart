import 'module_descriptor.dart';
import 'probe.dart';

/// A typed channel. Identity lives in the instance (via [name]), not in the
/// string alone: two `Topic`s with the same name are different channels. That
/// is why the seeded channels live as constants in [CoreTopics] — subscribe
/// and publish must name the same instance.
class Topic<T> {
  const Topic(this.name);

  final String name;

  @override
  String toString() => 'Topic<$T>($name)';
}

/// The core's seed channels. Deliberately exactly two (#93); new channels are
/// added here, never as loose string pairs scattered through the app.
class CoreTopics {
  static const probeResult = Topic<ProbeResult>('probe.result');
  static const moduleRegistered = Topic<ModuleDescriptor>('module.registered');
}

/// Handle on a subscription. [cancel] is idempotent — unsubscribing twice is
/// not an error.
class Subscription {
  Subscription(this._cancel);

  final void Function() _cancel;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

/// Raised when a disposed [EventBus] is used again.
class EventBusError implements Exception {
  EventBusError(this.message);

  final String message;

  @override
  String toString() => 'EventBusError: $message';
}

/// In-process publish/subscribe, typed by [Topic].
class EventBus {
  EventBus({this.onListenerError});

  /// When set, a throwing listener is reported here and the remaining
  /// listeners still run. Without it the error propagates out of [publish].
  final void Function(Object error, StackTrace stack)? onListenerError;

  final Map<Object, List<void Function(Object?)>> _listeners = {};
  bool _disposed = false;

  int get subscriberCount {
    var total = 0;
    for (final list in _listeners.values) {
      total += list.length;
    }
    return total;
  }

  Subscription subscribe<T>(Topic<T> topic, void Function(T) listener) {
    _ensureUsable();
    final list = _listeners.putIfAbsent(topic, () => []);
    void wrapper(Object? event) => listener(event as T);
    list.add(wrapper);
    return Subscription(() {
      list.remove(wrapper);
      if (list.isEmpty) {
        _listeners.remove(topic);
      }
    });
  }

  void publish<T>(Topic<T> topic, T event) {
    _ensureUsable();
    final list = _listeners[topic];
    // Nothing subscribed: a no-op, not an error.
    if (list == null || list.isEmpty) return;

    // Snapshot (Muster module_registry.dart): a listener that unsubscribes
    // during delivery must not change the running iteration.
    for (final listener in List.of(list)) {
      try {
        listener(event);
      } catch (error, stack) {
        final handler = onListenerError;
        if (handler == null) rethrow;
        handler(error, stack);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }

  void _ensureUsable() {
    if (_disposed) {
      throw EventBusError('EventBus already disposed');
    }
  }
}
