import 'dart:async';

final _pending = <String, Future<void>>{};

/// Serialize read/check/write in this isolate; failed writes release the queue.
Future<T> withStorageLock<T>(String key, Future<T> Function() action) async {
  final previous = _pending[key] ?? Future<void>.value();
  final released = Completer<void>();
  _pending[key] = released.future;
  await previous;
  try {
    return await action();
  } finally {
    released.complete();
    if (identical(_pending[key], released.future)) _pending.remove(key);
  }
}
