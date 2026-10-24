import 'models.dart';
import 'app_links.dart' show productionAppUrl;

/// Translate receipt labels before inserting names and financial values.
String calculationReceipt({
  required ExchangeQuote quote,
  required int budget,
  required int received,
  required bool english,
  required DateTime now,
  required String rateLabel,
  String appUrl = productionAppUrl,
  required String Function(DateTime) formatTime,
}) {
  final thbFirst = quote.direction == ExchangeDirection.thbMmk;
  final from = english ? (thbFirst ? 'THB' : 'MMK') : quote.direction.from;
  final to = english ? (thbFirst ? 'MMK' : 'THB') : quote.direction.to;
  final direction = english
      ? (thbFirst ? 'Pay THB → Receive MMK' : 'Pay MMK → Receive THB')
      : quote.direction.label;
  final fee = quote.feeFor(budget);
  return <String>[
    if (quote.sourceChecked && !quote.activeAt(now))
      english
          ? 'Calculated using the last published rate. A new rate is not available yet.'
          : 'နောက်ဆုံးတင်ထားတဲ့ဈေးနဲ့ တွက်ထားပါတယ်။ ဈေးအသစ် မတင်ရသေးပါ။',
    'ဘတ်ဈေး · $direction',
    quote.label,
    '${english ? 'You pay' : 'ပေးငွေ'} ${money(budget)} $from',
    '${english ? 'You receive' : 'ရငွေ'} ${money(received)} $to',
    if (fee > 0)
      '${english ? 'Separate deduction' : 'သီးသန့်နုတ်ငွေ'} ${money(fee)} $from',
    rateLabel,
    if (quote.sourceChecked)
      '${english ? 'Rate published:' : 'ဈေးတင်ချိန်'} ${formatTime(quote.observedAt)}'
    else
      english
          ? 'Calculated using a manually entered rate.'
          : 'ကိုယ်ထည့်ထားတဲ့ဈေးနဲ့ တွက်ထားပါတယ်',
    '${english ? 'Calculated:' : 'တွက်ချိန်'} ${formatTime(now)}',
    english
        ? 'Calculation only. This is not proof of a money transfer.'
        : 'တွက်ချက်ရလဒ်သာ ဖြစ်ပါတယ်။ ငွေလွှဲပြီးကြောင်း ပြေစာမဟုတ်ပါ။',
    appUrl,
    english
        ? 'Confirm the latest rate before exchanging money.'
        : 'ငွေမလဲခင် နောက်ဆုံးဈေးကို ပြန်မေးပါ။',
  ].join('\n');
}
