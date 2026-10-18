import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/rates_repository.dart';
import 'package:thai_helper/exchange/user_language.dart' as language;

import 'support/app_update_fixture.dart';

RatesRepository _repo() => RatesRepository(
  client: MockClient((request) async => http.Response(
    jsonEncode(request.url.path.endsWith('/history')
        ? <String, dynamic>{
            'schema_version': 1,
            'timezone': 'Asia/Bangkok',
            'points': [],
          }
        : <String, dynamic>{
            'schema_version': 2,
            'revision': 1,
            'published_at': DateTime.now().toIso8601String(),
            'notice': '',
            'quotes': [],
          }), 200)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('English can be selected, shows four translated main tabs and is persisted',
      (tester) async {
    await BudgetStore().save(
      const BudgetData(opening: 123400), expectedRevision: 0,
    );
    await tester.pumpWidget(CurrencyApp(repository: _repo(), updates: noNativeUpdates()));
    await tester.pumpAndSettle();
    expect(find.text('ငွေတွက်'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('language_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('My money'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect((await SharedPreferences.getInstance()).getString('user_language'), 'en');

    await tester.tap(find.text('My money'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_balance')), findsOneWidget);
    expect((await BudgetStore().load()).opening, 123400);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(CurrencyApp(repository: _repo(), updates: noNativeUpdates()));
    await tester.pumpAndSettle();
    expect(find.text('Calculator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Switching back keeps Burmese as default and persists selection',
      (tester) async {
    SharedPreferences.setMockInitialValues({'user_language': 'en'});
    await tester.pumpWidget(CurrencyApp(repository: _repo(), updates: noNativeUpdates()));
    await tester.pumpAndSettle();
    expect(find.text('Calculator'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('မြန်မာ').last);
    await tester.pumpAndSettle();
    expect(find.text('ငွေတွက်'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('user_language'), 'my');
  });


  testWidgets('English budget labels do not change a user-written Burmese note',
      (tester) async {
    SharedPreferences.setMockInitialValues({'user_language': 'en'});
    await BudgetStore().save(const BudgetData(entries: [
      BudgetEntry(
        id: 'my-note', day: '2026-10-17', kind: BudgetKind.income,
        category: 'salary', amount: 10000, note: 'လစာ',
      ),
    ]), expectedRevision: 0);
    await tester.pumpWidget(CurrencyApp(repository: _repo(), updates: noNativeUpdates()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My money'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Salary'), 220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsWidgets);
    expect(find.text('လစာ'), findsWidgets);
    expect((await BudgetStore().load()).entries.single.note, 'လစာ');
    expect(tester.takeException(), isNull);
  });

  test('Translations do not modify original strings or numerical fields', () {
    expect(language.uiTranslate('ဘတ်ဈေး', language.UserLanguage.english), 'BahtZay');
    expect(language.uiTranslate('ဘတ်ဈေး', language.UserLanguage.myanmar), 'ဘတ်ဈေး');
    expect(language.uiTranslate('THB/MMK 750', language.UserLanguage.english), 'THB/MMK 750');
  });

  testWidgets('English navigation remains usable at 320px and 1.4x text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues({'user_language': 'en'});
    await tester.pumpWidget(CurrencyApp(
      repository: _repo(), updates: noNativeUpdates(),
    ));
    await tester.pumpAndSettle();
    final labels = ['BahtZay', 'Calculator', 'My money', 'History'];
    for (var i = 0; i < labels.length; i++) {
      final destination = find.widgetWithText(NavigationDestination, labels[i]);
      expect(destination, findsOneWidget);
      final rect = tester.getRect(destination);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, i);
      expect(tester.takeException(), isNull);
    }
  });

}
