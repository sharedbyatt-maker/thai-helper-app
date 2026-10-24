import 'models.dart';

/// The observation belongs to the selected quote, never the network request.
String quoteFreshness(ExchangeQuote quote, {required DateTime now, bool english = false}) {
  final at = quote.observedAt.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${two(at.day)}/${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
  final minutes = now.toUtc().difference(quote.observedAt.toUtc()).inMinutes;
  final age = minutes < 1 ? (english ? 'just now' : 'ယခုလေးတင်')
      : minutes < 60 ? (english ? '$minutes min ago' : 'လွန်ခဲ့တဲ့ $minutes မိနစ်')
      : minutes < 1440 ? (english ? '${minutes ~/ 60} hr ago' : 'လွန်ခဲ့တဲ့ ${minutes ~/ 60} နာရီ')
      : (english ? '${minutes ~/ 1440} days ago' : 'လွန်ခဲ့တဲ့ ${minutes ~/ 1440} ရက်');
  return english ? 'Rate published: $stamp · $age · Thailand time' : 'ဈေးထုတ်ပြန်ချိန် $stamp · $age · ထိုင်းအချိန်';
}
