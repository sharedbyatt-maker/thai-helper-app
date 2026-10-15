import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/storage.dart';

ExchangeQuote quote({
  ExchangeDirection direction = ExchangeDirection.thbMmk,
  int fee = 0,
  int bps = 0,
}) => ExchangeQuote(
  id: 'test',
  label: 'Test only',
  direction: direction,
  rateMicros: 125000000,
  flatFeeMinor: fee,
  feeBps: bps,
  observedAt: DateTime.utc(2026, 1, 1),
  validUntil: DateTime.utc(2026, 1, 2),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Myanmar and Thai digits, money precision, and bounds', () {
    expect(parseMoney('၁၀,၀၀၀.၅၀'), 1000050);
    expect(parseMoney('๑๒๓'), 12300);
    for (final bad in [
      'NaN',
      'Infinity',
      '-1',
      '0',
      '1.001',
      '1000000001',
      '',
    ]) {
      expect(parseMoney(bad), isNull, reason: bad);
    }
    expect(money(1000050), '10,000.50');
  });
  test('Two directions use explicitly chosen quotes and total budget fees', () {
    expect(quote().payout(1000000), 125000000);
    expect(
      quote(direction: ExchangeDirection.mmkThb).payout(100000000),
      800000,
    );
    expect(quote(fee: 1000, bps: 100).payout(1000000), 123625000);
    expect(quote(fee: 1000).payout(100), 0);
  });
  test(
    'Target calculation meets payout with the minimum minor-unit budget',
    () {
      for (final direction in ExchangeDirection.values) {
        for (final fee in [0, 1000, 50000]) {
          for (final bps in [0, 1, 110, 500, 9999]) {
            final q = quote(direction: direction, fee: fee, bps: bps);
            for (final target in [1, 100, 100000, 50000000]) {
              final budget = q.requiredBudget(target);
              if (budget != null) {
                expect(q.payout(budget), greaterThanOrEqualTo(target));
                expect(budget == 1 || q.payout(budget - 1) < target, isTrue);
              }
            }
          }
        }
      }
    },
  );
  test('Chat parser interprets explicit units and refuses ambiguous rates', () {
    for (final text in [
      '၁ ဘတ် = ၁၂၅ ကျပ်',
      '၁ သိန်း = ၈၀၀ ဘတ်',
      '100000 MMK = 800 THB',
    ]) {
      expect(parseChatRate(text)?.rateMicros, 125000000);
    }
    expect(parseChatRate('1 THB = 125 MMK; 1 THB = 130 MMK'), isNull);
    expect(parseChatRate('09 123456789 fee 50'), isNull);
    expect(parseChatRate('${'9' * 1000} THB = 125 MMK'), isNull);
  });
  test('Expiry and unstarted quotes are not usable', () {
    final q = quote();
    expect(q.activeAt(DateTime.utc(2025)), isFalse);
    expect(q.activeAt(DateTime.utc(2026, 1, 1, 12)), isTrue);
    expect(q.activeAt(DateTime.utc(2026, 1, 2)), isFalse);
  });
  test(
    'Private record snapshots survive reload and completion changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = RecordStore();
      final record = PersonalRecord(
        id: 'record1',
        name: 'A',
        note: 'Home',
        quote: quote(),
        budgetMinor: 1000000,
        receivedMinor: 125000000,
        savedAt: DateTime.utc(2026, 1, 1),
      );
      await store.save([record]);
      final read = await store.load();
      expect(read.single.completed, isFalse);
      expect(read.single.quote.rateMicros, 125000000);
      await store.save([read.single.withCompleted(true)]);
      expect((await store.load()).single.completed, isTrue);
      expect(store.export(await store.load()), contains('schema_version'));
    },
  );
  test('Corrupt personal history is not silently overwritten', () async {
    SharedPreferences.setMockInitialValues({RecordStore.key: 'bad-json'});
    await expectLater(RecordStore().load(), throwsFormatException);
    expect(
      (await SharedPreferences.getInstance()).getString(RecordStore.key),
      'bad-json',
    );
  });
}
