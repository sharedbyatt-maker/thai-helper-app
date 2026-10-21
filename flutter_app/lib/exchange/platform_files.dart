export 'platform_files_stub.dart'
    if (dart.library.io) 'platform_files_native.dart'
    if (dart.library.js_interop) 'platform_files_web.dart';
