import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/storage.dart';

import 'user_experience_test.dart' show quote, start, tab;

Future<void> revealControl(WidgetTester t, Finder control) async {
  if (control.evaluate().isEmpty) {
    t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      control,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(control);
  await t.pumpAndSettle();
}

void expectEnglish(WidgetTester t) {
  final untranslated = find
      .byType(RichText)
      .evaluate()
      .map((e) => (e.widget as RichText).text.toPlainText())
      .where(
        (text) =>
            RegExp(r'[\u1000-\u109f]').hasMatch(text) &&
            text != 'ဘတ်ဈေး' &&
            text != 'မြန်မာ / English',
      )
      .toSet();
  expect(untranslated, isEmpty);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('English calculator result and save dialog keep exact money values',
      (t) async {
    SharedPreferences.setMockInitialValues({'user_language': 'en'});
    await start(t);
    await tab(t, 'Calculator');
    await t.enterText(find.byKey(const ValueKey('amount')), '10000');
    final calculate = find.byKey(const ValueKey('calculate'));
    await revealControl(t, calculate);
    await t.tap(calculate);
    await t.pumpAndSettle();
    // Inspect rendered paragraphs, excluding the translating Text wrapper.
    Finder paragraph(String text) => find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    );
    expect(paragraph('You pay 10,000 THB'), findsOneWidget);
    expect(paragraph('You receive 1,250,000 MMK'), findsOneWidget);
    // Published names are data and keep their original language.
    expect(find.text(quote().label), findsWidgets);
    final save = find.text('Save record');
    await revealControl(t, save);
    await t.tap(save);
    await t.pumpAndSettle();
    expect(find.text('Save calculation'), findsOneWidget);
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'English entry, plan, discard and backup flows keep finance records intact',
    (t) async {
      SharedPreferences.setMockInitialValues({'user_language': 'en'});
      await BudgetStore().save(
        const BudgetData(opening: 100000),
        expectedRevision: 0,
      );
      await start(t);
      await tab(t, 'My money');
      final income = find.byKey(const ValueKey('budget_add_income'));
      await revealControl(t, income);
      await t.tap(income);
      await t.pumpAndSettle();
      expectEnglish(t);
      await t.enterText(find.byKey(const ValueKey('budget_amount')), '50');
      final save = find.byKey(const ValueKey('budget_save_entry'));
      await revealControl(t, save);
      expectEnglish(t);
      await t.tap(save);
      await t.pumpAndSettle();
      expect((await BudgetStore().load()).entries.single.amount, 5000);

      final plan = find.byKey(const ValueKey('budget_plan'));
      await revealControl(t, plan);
      await t.tap(plan);
      await t.pumpAndSettle();
      expectEnglish(t);
      final fixed = find.byKey(const ValueKey('budget_fixed'));
      await revealControl(t, fixed);
      await t.enterText(fixed, '100');
      await t.pump();
      await t.tap(find.byType(BackButton).first);
      await t.pumpAndSettle();
      expect(find.text('You have unsaved changes'), findsOneWidget);
      await t.tap(find.text('Discard changes'));
      await t.pumpAndSettle();
      expect((await BudgetStore().load()).plans, isEmpty);

      await t.tap(find.byKey(const ValueKey('settings_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('settings_backup')));
      await t.pumpAndSettle();
      expectEnglish(t);
      expect(
        find.byKey(const ValueKey('complete_backup_export')),
        findsOneWidget,
      );
      expect((await BudgetStore().load()).entries.length, 1);
      expect((await BudgetStore().load()).opening, 100000);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Status, month and note filters only change the visible exchange history',
    (t) async {
      final q = quote(), now = DateTime.now().toUtc();
      final previous = DateTime.utc(now.year, now.month - 1, 1);
      PersonalRecord record(String id, DateTime at, bool completed) =>
          PersonalRecord(
            id: id,
            name: id,
            note: id,
            quote: q,
            budgetMinor: 100000,
            receivedMinor: q.payout(100000),
            savedAt: at,
            completed: completed,
            completedAt: completed ? at : null,
          );
      await RecordStore().save([
        record('pending', now, false),
        record('completed', now, true),
        record('old', previous, true),
      ]);
      await start(t);
      await tab(t, 'မှတ်တမ်း');
      final dates = find.byKey(const PageStorageKey('history_date_filters'));
      await revealControl(t, dates);
      await t.tap(dates);
      await t.pumpAndSettle();
      final month = find.byKey(const ValueKey('history_this_month'));
      await revealControl(t, month);
      await t.tap(month);
      await t.pumpAndSettle();
      await revealControl(t, find.text('မှတ်တမ်း 2 ခု'));
      expect(find.text('မှတ်တမ်း 2 ခု'), findsOneWidget);
      final status = find.byKey(const ValueKey('history_status_null'));
      await revealControl(t, status);
      await t.tap(status);
      await t.pumpAndSettle();
      await t.tap(find.text('ငွေလဲပြီးတာ').last);
      await t.pumpAndSettle();
      await revealControl(t, find.text('မှတ်တမ်း 1 ခု'));
      expect(find.text('မှတ်တမ်း 1 ခု'), findsOneWidget);
      expect((await RecordStore().load()).length, 3);
      final clear = find.byKey(const ValueKey('history_clear_filters'));
      await revealControl(t, clear);
      await t.tap(clear);
      await t.pumpAndSettle();
      expect(find.text('မှတ်တမ်း 3 ခု'), findsOneWidget);
      expect((await RecordStore().load()).length, 3);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
