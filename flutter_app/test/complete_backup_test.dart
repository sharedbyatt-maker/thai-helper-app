import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/complete_backup.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/storage.dart';

final fixedDay = DateTime.utc(2026, 10, 18);

class RejectingBudgetStore extends BudgetStore {
  RejectingBudgetStore() : super(clock: () => fixedDay);

  @override
  Future<BudgetData> save(BudgetData next,
      {required int expectedRevision, bool replaceCorrupt = false}) async {
    throw const FormatException('simulate budget write failure');
  }
}

PersonalRecord exchangeRecord(String id) {
  final at = DateTime.utc(2026, 10, 17, 3);
  final quote = ExchangeQuote(
    id: 'daily-thb-to-mmk',
    label: 'ဘတ်ပေး → ကျပ်ယူ',
    direction: ExchangeDirection.thbMmk,
    rateMicros: 133689840,
    observedAt: at,
    validUntil: at.add(const Duration(days: 1)),
  );
  const amount = 100000;
  return PersonalRecord(
    id: id,
    name: 'ကိုယ်မှတ်ထားတဲ့ ဈေး',
    note: 'မူရင်းနှုန်း',
    quote: quote,
    budgetMinor: amount,
    receivedMinor: quote.payout(amount),
    savedAt: at,
    completed: true,
    completedAt: at,
  );
}

BudgetData budget(String id, int opening) => BudgetData(
  opening: opening,
  entries: [
    BudgetEntry(
      id: id, day: '2026-10-17', kind: BudgetKind.expense,
      amount: 5000, category: 'food', note: 'နေ့လယ်စာ',
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Combined backup exports real local budget and exchange data without API sheets', () async {
    final b = BudgetStore(clock: () => fixedDay);
    final r = RecordStore();
    final savedBudget = await b.save(budget('saved', 200000), expectedRevision: 0);
    await r.save([exchangeRecord('x1')]);
    final service = CompleteBackupService(budgetStore: b, recordStore: r);

    final raw = await service.exportAll();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    expect(json['kind'], 'bahtzay_complete_backup');
    expect(json['schema_version'], 1);
    expect(json.containsKey('quotes'), false);
    expect(json.containsKey('published_rates'), false);
    expect(json['budget'], savedBudget.toJson());
    expect((json['exchange_records'] as List).length, 1);
    expect(service.decode(raw).records.single.id, 'x1');
    expect(service.decode(raw).budget.entries.single.id, 'saved');
  });

  test('Preview never writes, restore replaces budget but only merges new exchange IDs', () async {
    final b = BudgetStore(clock: () => fixedDay);
    final r = RecordStore();
    final service = CompleteBackupService(budgetStore: b, recordStore: r);
    final saved = await b.save(budget('old', 50000), expectedRevision: 0);
    await r.save([exchangeRecord('keep')]);

    final incoming = service.encode(CompleteBackup(
      budget: budget('new', 400000),
      records: [exchangeRecord('keep'), exchangeRecord('extra')],
    ));
    final proposed = await service.preview(incoming);
    expect(proposed.previousBudget.entries.single.id, 'old');
    expect(proposed.mergedRecords.added, 1);
    expect(proposed.mergedRecords.skipped, 1);
    expect((await b.load()).toJson(), saved.toJson());
    expect((await r.load()).length, 1);

    await service.restore(proposed);
    final after = await b.load();
    expect(after.entries.single.id, 'new');
    expect(after.opening, 400000);
    expect(after.revision, 2);
    expect((await r.load()).map((e) => e.id).toSet(), {'keep', 'extra'});

    // The old single-purpose backup formats remain independently supported.
    expect(b.decode(b.backup(after)).entries.single.id, 'new');
    expect(previewRecordImport(r.export(await r.load()), []).added, 2);
  });

  test('Wrong formats, invalid records, duplicates and oversize files never write', () async {
    final b = BudgetStore(clock: () => fixedDay);
    final r = RecordStore();
    final service = CompleteBackupService(budgetStore: b, recordStore: r);
    await b.save(budget('safe', 30000), expectedRevision: 0);
    await r.save([exchangeRecord('original')]);
    final valid = jsonDecode(service.encode(CompleteBackup(
      budget: budget('incoming', 90000), records: [exchangeRecord('x2')],
    ))) as Map<String, dynamic>;

    final duplicates = Map<String, dynamic>.from(valid)
      ..['exchange_records'] = [exchangeRecord('x2').toJson(), exchangeRecord('x2').toJson()];
    final negative = Map<String, dynamic>.from(valid)
      ..['exchange_records'] = [{...exchangeRecord('x2').toJson(), 'budget_minor': -1}];
    final noBudget = Map<String, dynamic>.from(valid)..remove('budget');
    final futureBudget = Map<String, dynamic>.from(valid)
      ..['budget'] = budget('future', 90000).toJson()
        ..['entries'] = [
          BudgetEntry(id: 'future', day: '2026-10-19',
            kind: BudgetKind.expense, amount: 200, category: 'food').toJson(),
        ];
    for (final invalid in [
      '{not json',
      'x' * (CompleteBackupService.maxBytes + 1),
      jsonEncode({...valid, 'schema_version': 987}),
      jsonEncode(duplicates),
      jsonEncode(negative),
      jsonEncode(noBudget),
      jsonEncode(futureBudget),
    ]) {
      await expectLater(service.preview(invalid), throwsFormatException);
      expect((await b.load()).entries.single.id, 'safe');
      expect((await r.load()).single.id, 'original');
    }
  });

  test('Preview becomes invalid if data changed; failed budget save rolls back record merge', () async {
    final b = BudgetStore(clock: () => fixedDay);
    final r = RecordStore();
    final service = CompleteBackupService(budgetStore: b, recordStore: r);
    final saved = await b.save(budget('old', 50000), expectedRevision: 0);
    await r.save([exchangeRecord('keep')]);
    final backup = service.encode(CompleteBackup(
      budget: budget('new', 500000), records: [exchangeRecord('add')],
    ));
    final stale = await service.preview(backup);
    await b.save(saved.copy(opening: 70000), expectedRevision: saved.revision);
    await expectLater(service.restore(stale), throwsFormatException);
    expect((await b.load()).opening, 70000);
    expect((await r.load()).map((e) => e.id), ['keep']);

    final failing = CompleteBackupService(
      budgetStore: RejectingBudgetStore(), recordStore: r,
    );
    final current = await failing.preview(backup);
    await expectLater(failing.restore(current), throwsFormatException);
    expect((await b.load()).opening, 70000);
    expect((await r.load()).map((e) => e.id), ['keep']);
  });

  test('Corrupt local history blocks export/restore without erasing any budget data', () async {
    final b = BudgetStore(clock: () => fixedDay);
    final service = CompleteBackupService(budgetStore: b);
    await b.save(budget('keep', 20000), expectedRevision: 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RecordStore.key, 'not a JSON history');
    await expectLater(service.exportAll(), throwsA(isA<Object>()));
    final incoming = service.encode(CompleteBackup(
      budget: budget('new', 70000), records: [],
    ));
    await expectLater(service.preview(incoming), throwsA(isA<Object>()));
    expect((await b.load()).entries.single.id, 'keep');
    expect(prefs.getString(RecordStore.key), 'not a JSON history');
  });
}
