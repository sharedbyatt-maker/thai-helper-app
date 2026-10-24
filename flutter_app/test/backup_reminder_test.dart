import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/backup_reminder.dart';

void main() {
  testWidgets('First successful-save reminder offers backup once without blocking entry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var opened = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => remindBackup(context, () => opened++), child: const Text('saved'))))));
    await tester.tap(find.text('saved')); await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getBool(backupReminderKey), true);
    await tester.tap(find.text('Backup သိမ်းမယ်')); await tester.pumpAndSettle();
    expect(opened, 1);
    await tester.tap(find.text('saved')); await tester.pumpAndSettle();
    expect(find.text('Backup သိမ်းမယ်'), findsNothing);
  });
  testWidgets('Closing the reminder remains dismissed after rebuilding the app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Widget app(Key key) => MaterialApp(key: key, home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => remindBackup(context, () {}), child: const Text('saved')))));
    await tester.pumpWidget(app(const ValueKey('first')));
    await tester.tap(find.text('saved')); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close')); await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(app(const ValueKey('second')));
    await tester.tap(find.text('saved')); await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

}
