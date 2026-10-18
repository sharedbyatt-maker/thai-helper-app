import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/complete_backup_page.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/rates_repository.dart';

import 'support/app_update_fixture.dart';

RatesRepository repo() => RatesRepository(client: MockClient((r) async =>
  http.Response(jsonEncode(r.url.path.endsWith('/history')
      ? {'schema_version':1, 'timezone':'Asia/Bangkok', 'points':[]}
      : {'schema_version':2, 'revision':1,
          'published_at':DateTime.now().toUtc().toIso8601String(),
          'notice':'', 'quotes':[]}), 200)));

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('settings_button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('app_settings_list')), findsOneWidget);
  expect(find.byKey(const ValueKey('settings_language')), findsOneWidget);
  expect(find.byKey(const ValueKey('settings_theme')), findsOneWidget);
  expect(find.byKey(const ValueKey('settings_backup')), findsOneWidget);
  expect(find.byKey(const ValueKey('settings_help')), findsOneWidget);
  expect(find.byKey(const ValueKey('settings_update')), findsOneWidget);
  expect(find.byKey(const ValueKey('settings_notifications')), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Every main tab has the same settings and exactly one app header', (tester) async {
    await BudgetStore().save(const BudgetData(opening:123400), expectedRevision:0);
    await tester.pumpWidget(CurrencyApp(repository:repo(), updates:noNativeUpdates()));
    await tester.pumpAndSettle();

    for (final label in ['ဘတ်ဈေး','ငွေတွက်','ငွေစာရင်း','မှတ်တမ်း']) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_button')), findsOneWidget);
      if (label == 'ငွေစာရင်း') {
        expect(find.byKey(const ValueKey('budget_balance')), findsOneWidget);
        expect(find.byKey(const ValueKey('budget_add_expense')), findsOneWidget);
      }
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('settings_close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect((await BudgetStore().load()).opening, 123400);
  });

  testWidgets('Switch language from wallet and keep the selected language on all tabs', (tester) async {
    await BudgetStore().save(const BudgetData(opening:123400), expectedRevision:0);
    await tester.pumpWidget(CurrencyApp(repository:repo(), updates:noNativeUpdates()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ငွေစာရင်း'));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('language_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('settings_close')));
    await tester.pumpAndSettle();
    expect(find.text('My money'), findsWidgets);
    expect((await SharedPreferences.getInstance()).getString('user_language'), 'en');
    await tester.tap(find.widgetWithText(NavigationDestination,'History'));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Language'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('settings_close')));
    await tester.pumpAndSettle();
    expect((await BudgetStore().load()).opening, 123400);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings backup is accessible from all tabs without modifying budget', (tester) async {
    await BudgetStore().save(const BudgetData(opening:123400), expectedRevision:0);
    await tester.pumpWidget(CurrencyApp(repository:repo(), updates:noNativeUpdates()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination,'ငွေစာရင်း'));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('settings_backup')));
    await tester.pumpAndSettle();
    expect(find.byType(CompleteBackupPage), findsOneWidget);
    expect(find.byKey(const ValueKey('complete_backup_export')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_balance')), findsOneWidget);
    expect((await BudgetStore().load()).opening, 123400);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings remains usable at 320px with English and enlarged text', (tester) async {
    SharedPreferences.setMockInitialValues({'user_language':'en'});
    tester.view.physicalSize=const Size(320,800);
    tester.view.devicePixelRatio=1;
    tester.platformDispatcher.textScaleFactorTestValue=1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(CurrencyApp(repository:repo(), updates:noNativeUpdates()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination,'My money'));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('settings_update')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('settings_close')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
