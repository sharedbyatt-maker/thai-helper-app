import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:flutter/widgets.dart' show Rect;
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

/// Native document picker grants access only to the file the user selects.
Future<String?> pickBackup({Future<XFile?> Function()? select}) async {
  final file =
      await (select?.call() ??
          openFile(
            acceptedTypeGroups: const [
              XTypeGroup(
                label: 'JSON backup',
                extensions: ['json'],
                mimeTypes: ['application/json'],
                uniformTypeIdentifiers: ['public.json'],
              ),
            ],
          ));
  if (file == null) return null;
  if (await file.length() > 2000000) {
    throw const FormatException(
      'ဖိုင်ကြီးလွန်းတယ်။ မှတ်တမ်းဖိုင်ကို ပြန်စစ်ပေးပါ။',
    );
  }
  return file.readAsString();
}

// Legacy CSV/image exports have a copy fallback. Combined backups below use
// an awaited share action so the page can report failure before claiming success.
void downloadBytes(Uint8List bytes, String name, String mime) {
  unawaited(
    Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: mime, name: name)],
      fileNameOverrides: [name],
      sharePositionOrigin: const Rect.fromLTWH(1, 1, 1, 1),
    ).then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
  );
}

Future<bool> installApp() async => false;
Future<Map<String, dynamic>> phoneNotifications(
  String action,
  String api,
) async {
  if (Platform.isAndroid) {
    const channel = MethodChannel('bahtzay/notifications');
    return (await channel.invokeMapMethod<String, dynamic>(action))!;
  }
  return {
    'supported': false,
    'active': false,
    'reason': 'ဒီ version မှာ ဖုန်း noti မသုံးနိုင်သေးဘူး။',
  };
}
