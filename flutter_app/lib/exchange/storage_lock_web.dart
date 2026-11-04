import 'dart:js_interop';

@JS('navigator.locks')
external _LockManager? get _locks;

extension type _LockManager(JSObject _) implements JSObject {
  external JSPromise<JSAny?> request(JSString name, JSFunction callback);
}

/// The default exclusive Web Lock covers reload, validation and persistence.
/// Never fall back to an unsafe read/check/write on unsupported browsers.
Future<T> withStorageLock<T>(String key, Future<T> Function() action) async {
  final manager = _locks;
  if (manager == null) {
    throw const FormatException(
      'စာရင်းကို လုံခြုံစွာ သိမ်းဖို့ browser update လုပ်ပြီး ပြန်စမ်းပေးပါ။',
    );
  }
  late T result;
  Object? failure;
  StackTrace? trace;
  await manager.request(('bahtzay-storage:' + key).toJS, ((JSAny? lock) {
    Future<JSAny?> run() async {
      try {
        result = await action();
      } catch (error, stack) {
        failure = error;
        trace = stack;
      }
      return null;
    }
    return run().toJS;
  }).toJS).toDart;
  // Preserve FormatException and its original stack across the JS boundary.
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return result;
}
