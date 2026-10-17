import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

@JS('bahtzayInstall')
external JSPromise<JSBoolean> _install();
Future<bool> installApp() async => (await _install().toDart).toDart;
Future<String?> pickBackup() async {
  final result = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json';
  input.addEventListener(
    'change',
    ((web.Event event) async {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!result.isCompleted) result.complete(null);
        return;
      }
      final file = files.item(0)!;
      if (file.size > 2000000) {
        result.completeError(
          const FormatException(
            'ဖိုင်ကြီးလွန်းတယ်။ မှတ်တမ်း JSON ဖိုင်ကို ရွေးပေးပါ။',
          ),
        );
        return;
      }
      try {
        result.complete((await file.text().toDart).toDart);
      } catch (e) {
        result.completeError(e);
      }
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event event) {
      if (!result.isCompleted) result.complete(null);
    }).toJS,
  );
  input.click();
  return result.future;
}

void downloadBytes(Uint8List bytes, String name, String mime) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  a.click();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
