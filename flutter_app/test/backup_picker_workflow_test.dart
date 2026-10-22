import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/budget_page.dart';
import 'package:thai_helper/exchange/complete_backup_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Pending file selection disables competing backup actions; cancel unlocks without writes',
    (t) async {
      final selected = Completer<String?>();
      var calls = 0;
      await BudgetStore().save(
        const BudgetData(opening: 120000),
        expectedRevision: 0,
      );
      await t.pumpWidget(
        MaterialApp(
          home: CompleteBackupPage(
            pickFile: () {
              calls++;
              return selected.future;
            },
          ),
        ),
      );
      final picker = find.byKey(const ValueKey('complete_backup_pick'));
      await t.ensureVisible(picker);
      await t.tap(picker);
      await t.pump();
      expect(t.widget<OutlinedButton>(picker).onPressed, isNull);
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const ValueKey('complete_backup_export')),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('complete_backup_check')),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      selected.complete(null);
      await t.pumpAndSettle();
      expect(t.widget<OutlinedButton>(picker).onPressed, isNotNull);
      expect((await BudgetStore().load()).opening, 120000);
      expect(
        find.byKey(const ValueKey('complete_backup_restore')),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Invalid picked file releases controls and never changes the wallet',
    (t) async {
      await BudgetStore().save(
        const BudgetData(opening: 120000),
        expectedRevision: 0,
      );
      await t.pumpWidget(
        MaterialApp(home: CompleteBackupPage(pickFile: () async => '{broken')),
      );
      final picker = find.byKey(const ValueKey('complete_backup_pick'));
      await t.ensureVisible(picker);
      await t.tap(picker);
      await t.pumpAndSettle();
      expect(t.widget<OutlinedButton>(picker).onPressed, isNotNull);
      expect(
        find.byKey(const ValueKey('complete_backup_restore')),
        findsNothing,
      );
      expect((await BudgetStore().load()).opening, 120000);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'A failed wallet file selection clears an earlier accepted preview and unlocks actions',
    (t) async {
      final store = BudgetStore();
      await store.save(const BudgetData(opening: 120000), expectedRevision: 0);
      var calls = 0, restores = 0;
      final selected = Completer<String?>();
      await t.pumpWidget(
        MaterialApp(
          home: BudgetRestorePage(
            store: store,
            currentCount: 0,
            onRestore: (_) async {
              restores++;
            },
            pickFile: () {
              calls++;
              return selected.future;
            },
          ),
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('budget_backup_text')),
        store.backup(const BudgetData(opening: 250000)),
      );
      await t.tap(find.byKey(const ValueKey('budget_preview_restore')));
      await t.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('budget_confirm_restore'));
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      final picker = find.byKey(const ValueKey('budget_backup_pick'));
      await t.ensureVisible(picker);
      await t.tap(picker);
      await t.pump();
      expect(t.widget<OutlinedButton>(picker).onPressed, isNull);
      expect(calls, 1);
      selected.completeError(const FormatException('Unreadable file'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('budget_confirm_restore')),
        findsNothing,
      );
      expect(t.widget<OutlinedButton>(picker).onPressed, isNotNull);
      expect(restores, 0);
      expect((await store.load()).opening, 120000);
      expect(t.takeException(), isNull);
    },
  );
}
