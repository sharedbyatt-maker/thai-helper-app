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
    double height = 1000,
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
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
      expect(find.widgetWithText(NavigationDestination, 'ဘတ်ဈေး'), findsOneWidget);
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
    'Calculate dismisses input, acknowledges success and reveals the result on a small screen',
    (tester) async {
      await start(tester, width: 360, height: 700, scale: 1.3);
      await tester.tap(find.text('ငွေတွက်'));
      await tester.pumpAndSettle();
      final amount = find.byKey(const ValueKey('amount'));
      final rate = find.byKey(const ValueKey('rate_0'));
      final button = find.byKey(const ValueKey('calculate'));
      await tester.enterText(amount, '1000');
      await reveal(tester, rate, 180);
      await tester.enterText(rate, '125');
      await reveal(tester, button, 180);
      await tester.tap(button);
      await tester.pump();
      expect(find.text('✓ တွက်ပြီးပြီ'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.pumpAndSettle();
      // Do not manually scroll to the result: that is the behavior under test.
      final result = find.text('ရငွေ 125,000 ကျပ်');
      final rect = tester.getRect(result);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThan(630));
      expect(find.text('1,000 ဘတ် ပေးရင်'), findsOneWidget);

      await reveal(tester, amount, -250);
      await tester.enterText(amount, '2000');
      await tester.pump();
      expect(find.text('✓ တွက်ပြီးပြီ'), findsNothing);
      expect(result, findsNothing);
      await reveal(tester, button, 180);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('ရငွေ 250,000 ကျပ်')).bottom, lessThan(630));
      await reveal(tester, rate, -180);
      await tester.enterText(rate, '130');
      await tester.pump();
      expect(find.text('✓ တွက်ပြီးပြီ'), findsNothing);
      expect(find.text('ရငွေ 250,000 ကျပ်'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'Invalid amounts never acknowledge a successful calculation',
    (tester) async {
      await start(tester);
      await tester.tap(find.text('ငွေတွက်'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('amount')), '0');
      await reveal(tester, find.byKey(const ValueKey('rate_0')), 180);
      await tester.enterText(find.byKey(const ValueKey('rate_0')), '125');
      await reveal(tester, find.byKey(const ValueKey('calculate')), 180);
      await tester.tap(find.byKey(const ValueKey('calculate')));
      await tester.pumpAndSettle();
      expect(find.text('✓ တွက်ပြီးပြီ'), findsNothing);
      expect(find.textContaining('0 ထက်ကြီးတဲ့ ပမာဏ'), findsOneWidget);
      expect(find.text('ရမယ့်ငွေ'), findsNothing);
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
