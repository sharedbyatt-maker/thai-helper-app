import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/rates_repository.dart';
import 'package:thai_helper/exchange/trend_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> start(
    WidgetTester tester, {
    bool stale = false,
    bool trend = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1050);
    tester.view.devicePixelRatio = 1;
    final now = DateTime.now().toUtc();
    final shifted = now.add(const Duration(hours: 7));
    final today = DateTime.utc(shifted.year, shifted.month, shifted.day);
    final repo = RatesRepository(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(
            r.url.path.endsWith('/history')
                ? {
                    'schema_version': 1,
                    'timezone': 'Asia/Bangkok',
                    'points': trend
                        ? [
                            for (final i in [1, 0])
                              {
                                'day': today
                                    .subtract(Duration(days: i))
                                    .toIso8601String()
                                    .substring(0, 10),
                                'quote_id': 'daily-mmk_thb',
                                'source_name': 'Daily reference',
                                'source_url': '',
                                'payout_method': 'မဖော်ပြထားပါ',
                                'direction': 'mmk_thb',
                                'rate_micros': i == 1
                                    ? (100000 / 725 * 1000000).round()
                                    : 137741047,
                              },
                          ]
                        : [],
                  }
                : {
                    'schema_version': 2,
                    'revision': 1,
                    'published_at': now.toIso8601String(),
                    'notice': '',
                    'quotes': [
                      {
                        'id': 'daily-mmk_thb',
                        'label': 'ကျပ်ပေး → ဘတ်ယူ',
                        'direction': 'mmk_thb',
                        'rate_micros': 137741047,
                        'source_name': 'Daily reference',
                        'source_url': '',
                        'payout_method': 'မဖော်ပြထားပါ',
                        'source_checked': true,
                        'observed_at': now
                            .subtract(Duration(days: stale ? 2 : 0, minutes: 1))
                            .toIso8601String(),
                        'valid_until': now
                            .add(Duration(days: stale ? -1 : 1))
                            .toIso8601String(),
                      },
                    ],
                  },
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpWidget(CurrencyApp(repository: repo));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets(
    'Telegram MMK-only publication is visible immediately in the same units and calculates exactly',
    (tester) async {
      await start(tester, trend: true);
      expect(find.text('ကျပ် ၁ သိန်း = ဘတ် 726'), findsOneWidget);
      final selected = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'ကျပ်ပေး → ဘတ်ယူ'),
      );
      expect(selected.selected, true);
      await tester.ensureVisible(find.text('7 ရက်'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 ရက်'));
      await tester.pumpAndSettle();
      expect(find.textContaining('+ 0.14%'), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RateTrendPainter,
        ),
      );
      expect(
        (paint.painter! as RateTrendPainter).direction,
        ExchangeDirection.mmkThb,
      );
      await tester.ensureVisible(find.text('ဒီနှုန်းနဲ့ တွက်မယ်').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ဒီနှုန်းနဲ့ တွက်မယ်').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('amount')), '100000');
      final rate = tester.widget<TextField>(
        find.byKey(const ValueKey('rate_0')),
      );
      expect(rate.controller!.text, '726');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('calculate')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('calculate')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('ရငွေ 726 ဘတ်'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ရငွေ 726 ဘတ်'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
  testWidgets(
    'Empty direction explains missing side and resume respects explicit choice',
    (tester) async {
      await start(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'ဘတ်ပေး → ကျပ်ယူ'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('ဘတ်ပေး → ကျပ်ယူ နှုန်း မတင်ရသေးပါ။'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ဘတ်ပေး → ကျပ်ယူ နှုန်း မတင်ရသေးပါ။'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'ဘတ်ပေး → ကျပ်ယူ'),
            )
            .selected,
        true,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'ကျပ်ပေး → ဘတ်ယူ နှုန်းကြည့်မယ်'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'ကျပ်ပေး → ဘတ်ယူ နှုန်းကြည့်မယ်'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'ကျပ်ပေး → ဘတ်ယူ နှုန်းကြည့်မယ်'),
      );
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('ကျပ် ၁ သိန်း = ဘတ် 726'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
  testWidgets(
    'After 24 hours the last rate stays visible with a stale label and cannot calculate as current',
    (tester) async {
      await start(tester, stale: true);
      expect(find.text('ကျပ် ၁ သိန်း = ဘတ် 726'), findsOneWidget);
      expect(find.text('ပြန်မစစ်ရသေးသောနှုန်း'), findsOneWidget);
      expect(find.text('ဒီနှုန်းနဲ့ တွက်မယ်'), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
}
