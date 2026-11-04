import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/storage.dart';
import 'package:thai_helper/exchange/storage_lock.dart';

import 'complete_backup_test.dart' show exchangeRecord;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exclusive writers wait until the complete asynchronous write finishes', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final events = <String>[];
    final first = withStorageLock('queue-test', () async {
      events.add('first');
      entered.complete();
      await release.future;
      events.add('saved');
    });
    await entered.future;
    final second = withStorageLock('queue-test', () async => events.add('second'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(events, ['first']);
    release.complete();
    await Future.wait([first, second]);
    expect(events, ['first', 'saved', 'second']);
  });

  test('a failed write preserves its error and releases the lock', () async {
    await expectLater(withStorageLock<void>('failure-test', () async {
      throw const FormatException('original failure');
    }), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'original failure')));
    expect(await withStorageLock('failure-test', () async => 42), 42);
  });

  test('simultaneous budget writers cannot both commit the same revision', () async {
    final a = BudgetStore(), b = BudgetStore();
    final original = await a.load();
    final outcomes = await Future.wait([100, 200].map((amount) async {
      try {
        await (amount == 100 ? a : b).save(original.copy(opening: amount), expectedRevision: original.revision);
        return true;
      } on FormatException {
        return false;
      }
    }));
    expect(outcomes.where((ok) => ok).length, 1);
    final saved = await a.load();
    expect(saved.revision, 1);
    expect(saved.opening, anyOf(100, 200));
    await b.save(saved.copy(opening: 300), expectedRevision: saved.revision);
    expect((await a.load()).opening, 300);
  });

  test('simultaneous record writers reject stale history instead of losing a record', () async {
    final a = RecordStore(), b = RecordStore();
    final initial = await a.load();
    final outcomes = await Future.wait(['a', 'b'].map((id) async {
      try {
        await (id == 'a' ? a : b).save([exchangeRecord(id)], expectedRecords: initial);
        return true;
      } on FormatException {
        return false;
      }
    }));
    expect(outcomes.where((ok) => ok).length, 1);
    final current = await a.load();
    expect(current.length, 1);
    await b.save([...current, exchangeRecord('retry')], expectedRecords: current);
    expect((await a.load()).length, 2);
  });
}
