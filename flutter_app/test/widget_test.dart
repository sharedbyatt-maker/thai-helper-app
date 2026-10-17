import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/rates_repository.dart';

Future<void> reveal(WidgetTester tester, Finder finder, double delta) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> start(
    WidgetTester tester, {
    double width = 390,
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    final repository = RatesRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'schema_version': 2,
            'revision': 0,
            'published_at': null,
            'notice': '',
            'quotes': [],
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ExchangeHome(onTheme: () {}, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Narrow screen with large text has usable empty board and navigation',
    (tester) async {
      await start(tester, width: 320, scale: 1.3);
      expect(find.text('နေ့စဉ်ဈေး'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('ငွေတွက်'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('amount')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'Calculate custom rate, save private record, and preserve on tab change',
    (tester) async {
      await start(tester);
      await tester.tap(find.text('ငွေတွက်'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('amount')), '10000');
      await reveal(tester, find.byKey(const ValueKey('rate_0')), 200);
      await tester.enterText(find.byKey(const ValueKey('rate_0')), '125');
      expect(find.text('ကူးထားတဲ့စာကနေ ဈေးထည့်မယ်'), findsNothing);
      final calculate = find.byKey(const ValueKey('calculate'));
      await reveal(tester, calculate, 250);
      await tester.tap(calculate);
      await tester.pumpAndSettle();
      final result = find.text('ရငွေ 1,250,000 ကျပ်');
      await reveal(tester, result, 200);
      expect(result, findsOneWidget);
      final save = find.text('မှတ်တမ်းသိမ်း');
      await reveal(tester, save, 100);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'သိမ်းမယ်'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('မှတ်တမ်း'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('10,000 ဘတ် → 1,250,000 ကျပ်'), 200);
      expect(find.text('10,000 ဘတ် → 1,250,000 ကျပ်'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'Direction change clears previous rate instead of silently inverting it',
    (tester) async {
      await start(tester, dark: true);
      await tester.tap(find.text('ငွေတွက်'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('rate_0')), 200);
      await tester.enterText(find.byKey(const ValueKey('rate_0')), '125');
      await reveal(tester, find.text('ကျပ်ပေး → ဘတ်ယူ'), -300);
      await tester.tap(find.text('ကျပ်ပေး → ဘတ်ယူ'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('rate_0')), 200);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('rate_0')),
      );
      expect(field.controller!.text, '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
