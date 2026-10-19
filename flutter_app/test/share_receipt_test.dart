import 'package:flutter_test/flutter_test.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/share_receipt.dart';

void main() {
  final now = DateTime.utc(2026, 10, 19, 14);
  ExchangeQuote quote(ExchangeDirection direction, {bool published = true}) =>
      ExchangeQuote(
        id: 'receipt',
        label: 'လစာ',
        direction: direction,
        rateMicros: 125000000,
        flatFeeMinor: published ? 500 : 0,
        observedAt: now.subtract(const Duration(days: 2)),
        validUntil: now.subtract(const Duration(days: 1)),
        sourceChecked: published,
      );

  String receipt(ExchangeQuote q, int budget, {bool english = true}) =>
      calculationReceipt(
        quote: q,
        budget: budget,
        received: q.payout(budget),
        english: english,
        now: now,
        rateLabel: '800 THB = 100,000 MMK',
        formatTime: (date) => date.toIso8601String(),
      );

  test('English receipt preserves source names, exact payout and deductions', () {
    final q = quote(ExchangeDirection.thbMmk);
    final before = q.toJson();
    final text = receipt(q, 1000000);
    expect(text, contains('last published rate'));
    expect(text, contains('\nဘတ်ဈေး · Pay THB → Receive MMK\nလစာ\n'));
    expect(text, contains('You pay 10,000 THB'));
    expect(text, contains('You receive 1,249,375 MMK'));
    expect(text, contains('Separate deduction 5 THB'));
    expect(text, contains('Rate published: 2026-10-17T14:00:00.000Z'));
    expect(q.toJson(), before);
  });

  test('Reverse receipt uses the correct currencies and rounded payout', () {
    final text = receipt(quote(ExchangeDirection.mmkThb), 10000000);
    expect(text, contains('Pay MMK → Receive THB'));
    expect(text, contains('You pay 100,000 MMK'));
    expect(text, contains('You receive 799.96 THB'));
    expect(text, contains('Separate deduction 5 MMK'));
  });

  test('Manual receipt has no published-rate or deduction claims', () {
    final text = receipt(
      quote(ExchangeDirection.thbMmk, published: false),
      1000000,
    );
    expect(text, contains('Calculated using a manually entered rate.'));
    expect(text, isNot(contains('Rate published:')));
    expect(text, isNot(contains('last published rate')));
    expect(text, isNot(contains('Separate deduction')));
    expect(text, contains('You receive 1,250,000 MMK'));
  });

  test('Myanmar receipt retains its original wording and money values', () {
    final text = receipt(
      quote(ExchangeDirection.thbMmk),
      1000000,
      english: false,
    );
    expect(text, startsWith('နောက်ဆုံးတင်ထားတဲ့ဈေးနဲ့ တွက်ထားပါတယ်။'));
    expect(text, contains('ပေးငွေ 10,000 ဘတ်\nရငွေ 1,249,375 ကျပ်'));
    expect(text, contains('သီးသန့်နုတ်ငွေ 5 ဘတ်'));
    expect(text, endsWith('ငွေမလဲခင် နောက်ဆုံးဈေးကို ပြန်မေးပါ။'));
  });
}
