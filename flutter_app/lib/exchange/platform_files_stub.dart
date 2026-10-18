import 'dart:typed_data';

Future<String?> pickBackup() async => null;
void downloadBytes(Uint8List bytes, String name, String mime) {}
Future<bool> installApp() async => false;

Future<Map<String, dynamic>> phoneNotifications(String action, String api) async => {
  'supported': false,
  'active': false,
  'reason': 'ဒီ version မှာ ဖုန်း noti မသုံးနိုင်သေးဘူး။ Telegram နဲ့ အသိပေးမှု သုံးနိုင်တယ်။',
};
