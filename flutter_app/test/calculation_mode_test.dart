import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/rates_repository.dart';

import 'support/app_update_fixture.dart';

const payHelp = 'ကိုယ်ပေးမယ့်ပမာဏထည့်ပြီး ရမယ့်ငွေကို တွက်ကြည့်ပါ။';
const receiveHelp = 'ကိုယ်ရချင်တဲ့ပမာဏထည့်ပြီး ပေးရမယ့်ငွေကို တွက်ကြည့်ပါ။';

Future<void> start(
  WidgetTester tester, {
  bool english = false,
  double width = 390,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({if (english) 'user_language': 'en'});
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final now = DateTime.now().toUtc();
  final repository = RatesRepository(
    client: MockClient(
      (request) async => http.Response(
        jsonEncode(
          request.url.path.endsWith('/history')
              ? {'schema_version': 1, 'timezone': 'Asia/Bangkok', 'points': []}
              : {
                  'schema_version': 2,
                  'revision': 1,
                  'published_at': now.toIso8601String(),
                  'notice': '',
                  'quotes': [
                    for (final side in ['thb_mmk', 'mmk_thb'])
                      {
                        'id': 'daily-$side',
                        'label': side,
                        'direction': side,
                        'rate_micros':
                            (100000000000 / (side == 'thb_mmk' ? 739 : 717))
                                .round(),
                        'source_name': 'Test quote',
                        'payout_method': 'Test only',
                        'observed_at': now
                            .subtract(const Duration(minutes: 1))
                            .toIso8601String(),
                        'valid_until': now
                            .add(const Duration(days: 1))
                            .toIso8601String(),
                        'source_checked': true,
                      },
                  ],
                },
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: CurrencyApp(repository: repository, updates: noNativeUpdates()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(
      NavigationDestination,
      english ? 'Calculator' : 'ငွေတွက်',
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> close(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  for (final english in [false, true]) {
    for (final side in ['thb_mmk', 'mmk_thb']) {
      testWidgets(
        'Pay and receive modes use the correct currency and quote: $side, English=$english',
        (tester) async {
          await start(tester, english: english);
          final selector = find.byKey(const ValueKey('calculation_mode'));
          expect(selector, findsOneWidget);
          expect(
            tester.getRect(selector).bottom,
            lessThan(tester.getRect(find.byKey(const ValueKey('amount'))).top),
          );
          await tapVisible(tester, find.byKey(ValueKey('direction_$side')));
          final payment = side == 'mmk_thb' ? '100000' : '739';
          final received = side == 'mmk_thb' ? '717' : '100,000';
          final paidCurrency = english
              ? (side == 'mmk_thb' ? 'MMK' : 'THB')
              : (side == 'mmk_thb' ? 'ကျပ်' : 'ဘတ်');
          final receivedCurrency = english
              ? (side == 'mmk_thb' ? 'THB' : 'MMK')
              : (side == 'mmk_thb' ? 'ဘတ်' : 'ကျပ်');
          expect(
            find.text(
              english
                  ? 'Enter the amount you will pay to see how much you will receive.'
                  : payHelp,
            ).last,
            findsOneWidget,
          );
          var input = tester.widget<TextField>(
            find.byKey(const ValueKey('amount')),
          );
          expect(input.decoration!.labelText, contains(paidCurrency));
          await tester.enterText(find.byKey(const ValueKey('amount')), payment);
          await tapVisible(tester, find.byKey(const ValueKey('calculate')));
          expect(
            find.text(
              english
                  ? 'You receive $received $receivedCurrency'
                  : 'ရငွေ $received $receivedCurrency',
            ).last,
            findsOneWidget,
          );

          await tapVisible(
            tester,
            find.text(english ? 'Amount to receive' : 'ရချင်တဲ့ငွေ'),
          );
          expect(
            find.text(
              english
                  ? 'Enter the amount you want to receive to see how much you need to pay.'
                  : receiveHelp,
            ),
            findsOneWidget,
          );
          input = tester.widget<TextField>(
            find.byKey(const ValueKey('amount')),
          );
          expect(input.controller!.text, isEmpty);
          expect(input.decoration!.labelText, contains(receivedCurrency));
          expect(
            find.byKey(const ValueKey('calculation_result_1_0')),
            findsNothing,
          );
          final target = side == 'mmk_thb' ? '2000' : '100000';
          final required = side == 'mmk_thb' ? '278,940.03' : '739';
          await tester.enterText(find.byKey(const ValueKey('amount')), target);
          await tapVisible(tester, find.byKey(const ValueKey('calculate')));
          final requiredText = english
              ? 'You pay $required $paidCurrency'
              : 'ပေးငွေ $required $paidCurrency';
          expect(find.text(requiredText).last, findsOneWidget);
          expect(
            tester.widget<Text>(find.text(requiredText).last).style!.fontWeight,
            FontWeight.w700,
          );

          await tapVisible(
            tester,
            find.text(english ? 'Amount to pay' : 'ပေးမယ့်ငွေ').first,
          );
          input = tester.widget<TextField>(
            find.byKey(const ValueKey('amount')),
          );
          expect(input.controller!.text, isEmpty);
          expect(input.decoration!.labelText, contains(paidCurrency));
          expect(find.text(requiredText), findsNothing);
          await close(tester);
        },
      );
    }
  }

  testWidgets(
    'Switching modes clears a validation error and switching direction updates target units',
    (tester) async {
      await start(tester);
      await tapVisible(tester, find.byKey(const ValueKey('calculate')));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('amount')))
            .decoration!
            .errorText,
        isNotNull,
      );
      await tapVisible(tester, find.text('ရချင်တဲ့ငွေ'));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('amount')))
            .decoration!
            .errorText,
        isNull,
      );
      await tester.enterText(find.byKey(const ValueKey('amount')), '100000');
      await tapVisible(tester, find.byKey(const ValueKey('direction_mmk_thb')));
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('amount')),
      );
      expect(input.controller!.text, isEmpty);
      expect(input.decoration!.labelText, 'ရချင်တဲ့ပမာဏ (ဘတ်)');
      expect(find.text(receiveHelp), findsOneWidget);
      await close(tester);
    },
  );

  for (final width in [320.0, 1366.0]) {
    testWidgets('Mode controls fit at width $width with larger text', (
      tester,
    ) async {
      await start(tester, width: width, textScale: 1.4);
      await tapVisible(tester, find.text('ရချင်တဲ့ငွေ'));
      expect(tester.takeException(), isNull);
      expect(find.text(receiveHelp), findsOneWidget);
      await close(tester);
    });
  }
}
