import 'package:flutter_test/flutter_test.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/quote_freshness.dart';

void main() {
  final observed = DateTime.utc(2026, 10, 24, 6, 57);
  final q = ExchangeQuote(id: 'daily', label: 'Daily', direction: ExchangeDirection.thbMmk,
    rateMicros: 135000000, observedAt: observed, validUntil: observed.add(const Duration(days: 1)), sourceChecked: true);
  test('Compact timestamp keeps original observation in Bangkok time', () {
    expect(quoteFreshness(q, now: observed), 'နောက်ဆုံးဈေး · 24/10၊ 13:57');
    expect(quoteFreshness(q, now: observed, english: true), 'Latest rate · 24/10, 13:57');
  });
  test('Age uses quote observation and Bangkok time, including English and future clock skew', () {
    expect(quoteFreshnessDetails(q, now: observed.add(const Duration(hours: 2)), english: true), 'Rate published: 24/10 13:57 · 2 hr ago · Thailand time');
    expect(quoteFreshnessDetails(q, now: observed.add(const Duration(days: 2))), contains('2 ရက်'));
    expect(quoteFreshnessDetails(q, now: observed.subtract(const Duration(minutes: 2)), english: true), contains('just now'));
  });
}
