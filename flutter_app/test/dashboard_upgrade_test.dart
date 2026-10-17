import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/rates_repository.dart';
import 'package:thai_helper/exchange/trend_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> reveal(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        f,
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  Map<String, dynamic> quote(
    String direction,
    DateTime now, {
    int revision = 1,
  }) => {
    'id': 'daily-$direction',
    'label': direction == 'mmk_thb' ? 'ကျပ်ပေး → ဘတ်ယူ' : 'ဘတ်ပေး → ကျပ်ယူ',
    'direction': direction,
    'rate_micros':
        (100000 /
                (direction == 'mmk_thb'
                    ? 750
                    : revision == 1
                    ? 800
                    : 810) *
                1000000)
            .round(),
    'source_name': 'နေ့စဉ်ရည်ညွှန်းနှုန်း',
    'source_url': '',
    'payout_method': 'မဖော်ပြထားပါ',
    'source_checked': true,
    'observed_at': now.toIso8601String(),
    'valid_until': now.add(const Duration(days: 1)).toIso8601String(),
  };
  Future<void> start(
    WidgetTester t, {
    double width = 390,
    double scale = 1,
    bool empty = false,
    int Function()? revision,
  }) async {
    t.view.physicalSize = Size(width, 1100);
    t.view.devicePixelRatio = 1;
    final now = DateTime.now().toUtc();
    final shifted = now.add(const Duration(hours: 7));
    final day = DateTime.utc(shifted.year, shifted.month, shifted.day);
    Map<String, dynamic> point(
      Map<String, dynamic> q,
      DateTime at,
      int rate,
      String source,
    ) => {
      'day': day.toIso8601String().substring(0, 10),
      'observed_at': at.toIso8601String(),
      'quote_id': q['id'],
      'direction': q['direction'],
      'source_name': source,
      'source_url': '',
      'payout_method': q['payout_method'],
      'rate_micros': rate,
    };
    final repo = RatesRepository(
      client: MockClient((r) async {
        final current = revision?.call() ?? 1;
        final mmk = quote('mmk_thb', now, revision: current),
            thb = quote('thb_mmk', now, revision: current);
        return http.Response(
          jsonEncode(
            r.url.path.endsWith('/history')
                ? {
                    'schema_version': 1,
                    'timezone': 'Asia/Bangkok',
                    'points': empty
                        ? []
                        : [
                            point(
                              mmk,
                              now,
                              mmk['rate_micros'] as int,
                              mmk['source_name'] as String,
                            ),
                            point(
                              thb,
                              now,
                              thb['rate_micros'] as int,
                              thb['source_name'] as String,
                            ),
                          ],
                    'observations': empty
                        ? []
                        : [
                            point(
                              mmk,
                              day.subtract(const Duration(hours: 7)),
                              137741047,
                              'att',
                            ),
                            point(
                              mmk,
                              now,
                              mmk['rate_micros'] as int,
                              mmk['source_name'] as String,
                            ),
                            point(
                              thb,
                              now,
                              thb['rate_micros'] as int,
                              thb['source_name'] as String,
                            ),
                          ],
                  }
                : {
                    'schema_version': 2,
                    'revision': current,
                    'published_at': now.toIso8601String(),
                    'notice': '',
                    'quotes': empty ? [] : [mmk, thb],
                  },
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ExchangeHome(onTheme: () {}, repository: repo),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  }

  testWidgets(
    'Graph remains visible for a single real observation, and today shows real intraday prices across a renamed label on narrow and wide layouts',
    (t) async {
      for (final width in [320.0, 1100.0]) {
        await start(t, width: width, scale: width == 320 ? 1.3 : 1);
        await t.tap(find.text('ဒီနေ့'));
        await t.pumpAndSettle();
        final graph = find.byKey(const ValueKey('reference_rate_graph'));
        expect(graph, findsOneWidget);
        expect(
          (t.widget<CustomPaint>(graph).painter! as RateTrendPainter)
              .points
              .length,
          1,
        );
        expect(find.text('ဘတ် 800 = ကျပ် ၁ သိန်း'), findsOneWidget);
        expect(find.text('၁ ဘတ် ≈ 125 ကျပ်'), findsOneWidget);
        expect(find.text('ကျပ် ၁ သိန်း → 750 ဘတ်'), findsOneWidget);
        expect(find.text('ဘတ် 800 → ကျပ် ၁ သိန်း'), findsOneWidget);
        await t.tap(find.widgetWithText(ChoiceChip, 'ကျပ်ပေး → ဘတ်ယူ'));
        await t.pumpAndSettle();
        expect(find.text('ကျပ် ၁ သိန်း = 750 ဘတ်'), findsOneWidget);
        expect(find.byKey(const ValueKey('per_baht_equivalent')), findsNothing);
        expect(
          (t.widget<CustomPaint>(graph).painter! as RateTrendPainter)
              .points
              .length,
          2,
        );
        await reveal(t, graph);
        await t.tapAt(t.getTopLeft(graph) + const Offset(12, 78));
        await t.pumpAndSettle();
        expect(find.textContaining('726 ဘတ်'), findsOneWidget);
        expect(find.textContaining('att'), findsNothing);
        expect(find.text('ဒီဈေးကို ဘယ်ကရလဲ?'), findsNothing);
        expect(t.takeException(), isNull);
        await close(t);
      }
    },
  );
  testWidgets(
    'An empty dashboard still has a graph frame and clear empty state without invented prices',
    (t) async {
      await start(t, width: 320, scale: 1.3, empty: true);
      final graph = find.byKey(const ValueKey('reference_rate_graph'));
      expect(graph, findsOneWidget);
      expect(
        (t.widget<CustomPaint>(graph).painter! as RateTrendPainter).points,
        isEmpty,
      );
      expect(find.text('ဒီဘက်ဈေး မတင်ရသေးဘူး'), findsOneWidget);
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
  testWidgets(
    'Published rates fill the calculator and refresh preserves the entered budget and personal comparison',
    (t) async {
      var revision = 1;
      await start(t, revision: () => revision);
      await t.tap(find.text('ငွေတွက်'));
      await t.pumpAndSettle();
      await reveal(t, find.byKey(const ValueKey('rate_0')));
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('rate_0')))
            .controller!
            .text,
        '800',
      );
      await reveal(t, find.byKey(const ValueKey('amount')));
      await t.enterText(find.byKey(const ValueKey('amount')), '1000');
      await reveal(t, find.byKey(const PageStorageKey('calculator_options')));
      await t.tap(find.text('ဈေးနှိုင်းမယ် / ရချင်တဲ့ငွေနဲ့ တွက်မယ်'));
      await t.pumpAndSettle();
      await reveal(t, find.text('နှိုင်းဖို့ ဈေးတစ်ခု ထပ်ထည့်မယ်'));
      await t.tap(find.text('နှိုင်းဖို့ ဈေးတစ်ခု ထပ်ထည့်မယ်'));
      await t.pumpAndSettle();
      await reveal(t, find.byKey(const ValueKey('rate_1')));
      await t.enterText(find.byKey(const ValueKey('rate_1')), '130');
      revision = 2;
      await t.tap(find.byTooltip('ဈေးအသစ် ယူမယ်'));
      await t.pumpAndSettle();
      await reveal(t, find.byKey(const ValueKey('rate_1')));
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('rate_1')))
            .controller!
            .text,
        '130',
      );
      await reveal(t, find.byKey(const ValueKey('rate_0')));
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('rate_0')))
            .controller!
            .text,
        '810',
      );
      await reveal(t, find.byKey(const ValueKey('amount')));
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('amount')))
            .controller!
            .text,
        '1000',
      );
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
}
