import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/rates_repository.dart';
import 'package:thai_helper/exchange/trend_card.dart';

void main() {
  testWidgets(
    'Phone selectors show complete Myanmar text and six-point graph stays compact with real fonts',
    (t) async {
      for (final font in [
        ('Noto Sans Myanmar', 'assets/fonts/NotoSansMyanmar.ttf'),
        ('Noto Sans Symbols 2', 'assets/fonts/NotoSansSymbols2-Regular.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
      }
      for (final scenario in [
        (320.0, 1.3),
        (368.0, 1.0),
        (390.0, 1.0),
        (430.0, 1.4),
      ]) {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = Size(scenario.$1, 800);
        t.view.devicePixelRatio = 1;
        final now = DateTime.now().toUtc();
        final quotes = [
          for (final side in ['thb_mmk', 'mmk_thb'])
            {
              'id': 'daily-$side',
              'label': side == 'thb_mmk'
                  ? 'ဘတ်ပေး → ကျပ်ယူ'
                  : 'ကျပ်ပေး → ဘတ်ယူ',
              'direction': side,
              'rate_micros': side == 'thb_mmk' ? 133689840 : 138121547,
              'source_name': 'test',
              'source_url': '',
              'payout_method': 'မဖော်ပြထားပါ',
              'source_checked': true,
              'observed_at': now.toIso8601String(),
              'valid_until': now.add(const Duration(days: 1)).toIso8601String(),
            },
        ];
        final points = [
          for (var i = 5; i >= 0; i--)
            for (final q in quotes)
              {
                'day': now
                    .subtract(Duration(days: i))
                    .add(const Duration(hours: 7))
                    .toIso8601String()
                    .substring(0, 10),
                'observed_at': now
                    .subtract(Duration(days: i))
                    .toIso8601String(),
                'quote_id': q['id'],
                'direction': q['direction'],
                'source_name': q['source_name'],
                'source_url': '',
                'payout_method': q['payout_method'],
                'rate_micros': (q['rate_micros'] as int) + i * 100000,
              },
        ];
        final repo = RatesRepository(
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.endsWith('/history')
                    ? {
                        'schema_version': 1,
                        'timezone': 'Asia/Bangkok',
                        'points': points,
                        'observations': points,
                      }
                    : {
                        'schema_version': 2,
                        'revision': 9,
                        'published_at': now.toIso8601String(),
                        'notice': '',
                        'quotes': quotes,
                      },
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        t.platformDispatcher.textScaleFactorTestValue = scenario.$2;
        await t.pumpWidget(CurrencyApp(repository: repo));
        await t.pumpAndSettle();
        final left = find.byKey(const ValueKey('direction_thb_mmk'));
        final right = find.byKey(const ValueKey('direction_mmk_thb'));
        final a = t.getRect(left), b = t.getRect(right);
        expect(a.left, greaterThanOrEqualTo(0));
        expect(b.right, lessThanOrEqualTo(scenario.$1));
        expect(a.right, lessThan(b.left));
        expect(a.height, b.height);
        expect(t.widget<Semantics>(left).properties.selected, true);
        for (final card in [left, right]) {
          for (final text
              in find
                  .descendant(of: card, matching: find.byType(RichText))
                  .evaluate()) {
            final paragraph = text.findRenderObject()! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, false);
            final length = paragraph.text.toPlainText().length;
            for (final box in paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: length),
            )) {
              final origin = paragraph.localToGlobal(Offset.zero);
              final bounds = t.getRect(card);
              expect(origin.dx + box.left, greaterThanOrEqualTo(bounds.left));
              expect(origin.dx + box.right, lessThanOrEqualTo(bounds.right));
              expect(origin.dy + box.top, greaterThanOrEqualTo(bounds.top));
              expect(origin.dy + box.bottom, lessThanOrEqualTo(bounds.bottom));
            }
          }
        }
        final graph = find.byKey(const ValueKey('reference_rate_graph'));
        expect(t.getSize(graph).height, 108);
        expect(
          (t.widget<CustomPaint>(graph).painter! as RateTrendPainter)
              .points
              .length,
          6,
        );
        final cardHeight = t
            .getSize(find.byKey(const ValueKey('rate_trend_card')))
            .height;
        expect(cardHeight, lessThan(scenario.$2 == 1 ? 510 : 680));
        await t.ensureVisible(right);
        await t.pumpAndSettle();
        await t.tap(right);
        await t.pumpAndSettle();
        expect(t.widget<Semantics>(right).properties.selected, true);
        expect(find.text('ကျပ် ၁ သိန်း = 724 ဘတ်'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        t.platformDispatcher.clearTextScaleFactorTestValue();
      }
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
}
