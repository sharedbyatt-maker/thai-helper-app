// Stable per-store names coordinate every writer, including backup restores.
export 'storage_lock_native.dart'
    if (dart.library.js_interop) 'storage_lock_web.dart';
