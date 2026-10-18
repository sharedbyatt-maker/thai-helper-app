import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/rates_repository.dart';

import 'support/app_update_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('All four main tabs remain accessible on 320px phone with large Myanmar text',
      (tester) async {
    for (final font in [
      ('Noto Sans Myanmar', 'assets/fonts/NotoSansMyanmar.ttf'),
      ('Noto Sans Symbols 2', 'assets/fonts/NotoSansSymbols2-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await BudgetStore().save(
      const BudgetData(opening: 123400), expectedRevision: 0,
    );
    final repo = RatesRepository(client: MockClient(
      (request) async => http.Response(jsonEncode(
        request.url.path.endsWith('/history')
            ? <String, dynamic>{
                'schema_version': 1,
                'timezone': 'Asia/Bangkok',
                'points': <Object>[],
              }
            : <String, dynamic>{
                'schema_version': 2,
                'revision': 1,
                'published_at': DateTime.now().toUtc().toIso8601String(),
                'notice': '',
                'quotes': <Object>[],
              },
      ), 200),
    ));
    await tester.pumpWidget(
      CurrencyApp(repository: repo, updates: noNativeUpdates()),
    );
    await tester.pumpAndSettle();

    const names = ['နေ့စဉ်ဈေး', 'ငွေတွက်', 'ငွေစာရင်း', 'မှတ်တမ်း'];
    final navItems = find.byType(NavigationDestination);
    expect(navItems, findsNWidgets(4));
    for (var index = 0; index < names.length; index++) {
      final label = find.text(names[index]);
      expect(label, findsOneWidget);
      final bounds = tester.getRect(navItems.at(index));
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(320));
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, index);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (index == 2) {
        expect(find.byKey(const ValueKey('budget_balance')), findsOneWidget);
        expect(find.byKey(const ValueKey('budget_add_expense')), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      }
      if (index == 3) {
        expect(find.text('ကိုယ့်ငွေလဲမှတ်တမ်း'), findsOneWidget);
        expect(find.byKey(const ValueKey('open_budget')), findsNothing);
      }
    }
  });
}
