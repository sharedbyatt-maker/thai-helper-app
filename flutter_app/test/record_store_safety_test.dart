import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/storage.dart';
import 'complete_backup_test.dart' show exchangeRecord;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Stale history writes reject both new IDs and edits of an existing record', () async {
    final store = RecordStore();
    await store.save([exchangeRecord('keep')]);
    final tabA = await store.load(), tabB = await store.load();
    await store.save([tabB.single.withCompleted(false)], expectedRecords: tabB);
    await expectLater(store.save([], expectedRecords: tabA), throwsFormatException);
    expect((await store.load()).single.completed, false);
    final refreshed = await store.load();
    await store.save([...refreshed, exchangeRecord('new')], expectedRecords: refreshed);
    await expectLater(store.save([], expectedRecords: refreshed), throwsFormatException);
    expect((await store.load()).map((r) => r.id), ['keep', 'new']);
  });

  test('Corrupt or duplicated saved records block writes instead of becoming empty', () async {
    final prefs = await SharedPreferences.getInstance(), store = RecordStore();
    final duplicate = jsonEncode([exchangeRecord('same').toJson(), exchangeRecord('same').toJson()]);
    for (final raw in ['not-json', '{}', '[{}]', duplicate]) {
      await prefs.setString(RecordStore.key, raw);
      await expectLater(store.load(), throwsFormatException);
      await expectLater(store.save([]), throwsFormatException);
      expect(prefs.getString(RecordStore.key), raw);
    }
  });

  test('Invalid proposed records cannot overwrite a valid history', () async {
    final store = RecordStore();
    await store.save([exchangeRecord('keep')]);
    final before = await store.load();
    await expectLater(store.save([exchangeRecord('same'), exchangeRecord('same')],
      expectedRecords: before), throwsFormatException);
    expect((await store.load()).single.id, 'keep');
  });
}
