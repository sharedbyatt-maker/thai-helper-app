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
    ..accept = '.json,application/json'
    ..style.display = 'none';
  Timer? cancelTimer;
  var reading = false;
  Future<void> readSelected() async {
    if (result.isCompleted || reading) return;
    final files = input.files;
    if (files == null || files.length == 0) {
      result.complete(null);
      return;
    }
    reading = true;
    final file = files.item(0)!;
    if (file.size > 2000000) {
      result.completeError(
        const FormatException(
          'ဖိုင်ကြီးလွန်းတယ်။ မှတ်တမ်းဖိုင်ကို ပြန်စစ်ပေးပါ။',
        ),
      );
      return;
    }
    try {
      final text = (await file.text().toDart).toDart;
      if (!result.isCompleted) result.complete(text);
    } catch (e, stack) {
      if (!result.isCompleted) result.completeError(e, stack);
    }
  }

  final change = ((web.Event event) {
    unawaited(readSelected());
  }).toJS;
  final cancel = ((web.Event event) {
    if (!reading && !result.isCompleted) result.complete(null);
  }).toJS;
  // Older browsers do not emit `cancel`; returning focus without a selection
  // releases the picker as well. Give `change` time to start reading first.
  final focus = ((web.Event event) {
    cancelTimer?.cancel();
    cancelTimer = Timer(const Duration(seconds: 1), () {
      if (!reading && !result.isCompleted) {
        if ((input.files?.length ?? 0) > 0) {
          unawaited(readSelected());
        } else {
          result.complete(null);
        }
      }
    });
  }).toJS;
  input.addEventListener('change', change);
  input.addEventListener('cancel', cancel);
  web.window.addEventListener('focus', focus);
  web.document.body!.append(input);
  try {
    input.click();
    return await result.future;
  } finally {
    cancelTimer?.cancel();
    input.removeEventListener('change', change);
    input.removeEventListener('cancel', cancel);
    web.window.removeEventListener('focus', focus);
    input.remove();
  }
}

void downloadBytes(Uint8List bytes, String filename, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
