import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/complete_backup.dart';
import 'package:thai_helper/exchange/complete_backup_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Complete restore needs a valid preview and explicit confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final budget = BudgetStore(clock: () => DateTime.utc(2026, 10, 18));
    final current = await budget.save(
      const BudgetData(opening: 150000), expectedRevision: 0,
    );
    final service = CompleteBackupService(budgetStore: budget);
    final input = service.encode(const CompleteBackup(
      budget: BudgetData(opening: 600000), records: [],
    ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
            builder: (_) => CompleteBackupPage(service: service),
          )),
          child: const Text('Open backup'),
        )),
      ),
    ));
    await tester.tap(find.text('Open backup'));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('complete_backup_text'));
    await tester.enterText(field, '{"broken":true}');
    await tester.tap(find.byKey(const ValueKey('complete_backup_check')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('complete_backup_restore')), findsNothing);
    expect((await budget.load()).toJson(), current.toJson());

    await tester.enterText(field, input);
    await tester.tap(find.byKey(const ValueKey('complete_backup_check')));
    await tester.pumpAndSettle();
    final restore = find.byKey(const ValueKey('complete_backup_restore'));
    await tester.ensureVisible(restore);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(restore).onPressed, isNull);
    expect((await budget.load()).toJson(), current.toJson());

    final consent = find.byKey(const ValueKey('complete_backup_confirm'));
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(restore).onPressed, isNotNull);

    // Editing the input revokes consent; a fresh preview is required.
    await tester.enterText(field, '{"different":true}');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('complete_backup_restore')), findsNothing);
    expect((await budget.load()).toJson(), current.toJson());

    await tester.enterText(field, input);
    await tester.tap(find.byKey(const ValueKey('complete_backup_check')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect((await budget.load()).opening, 600000);
    expect(tester.takeException(), isNull);
  });
}
