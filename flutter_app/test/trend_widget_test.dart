import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
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
    'Source trend renders on narrow and wide screens and supports period and point selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fonts = FontLoader('Noto Sans Myanmar')
        ..addFont(rootBundle.load('assets/fonts/NotoSansMyanmar.ttf'));
      await fonts.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final symbols = FontLoader('Noto Sans Symbols 2')
        ..addFont(rootBundle.load('assets/fonts/NotoSansSymbols2-Regular.ttf'));
      await symbols.load();
      final now = DateTime.now().toUtc();
      final shifted = now.add(const Duration(hours: 7));
      final today = DateTime.utc(shifted.year, shifted.month, shifted.day);
      final q = {
        'id': 'a',
        'label': 'နေ့စဉ် ငွေလဲနှုန်း',
        'direction': 'thb_mmk',
        'rate_micros': 125000000,
        'source_name': 'Test source',
        'source_url': '',
        'payout_method': 'Bank',
        'source_checked': true,
        'observed_at': now
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
        'valid_until': now.add(const Duration(hours: 24)).toIso8601String(),
      };
      for (final width in [320.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        final repo = RatesRepository(
          client: MockClient(
            (r) async => http.Response(
              jsonEncode(
                r.url.path.endsWith('/history')
                    ? {
                        'schema_version': 1,
                        'timezone': 'Asia/Bangkok',
                        'points': [
                          for (var i = 13; i >= 0; i--)
                            {
                              'day': today
                                  .subtract(Duration(days: i))
                                  .toIso8601String()
                                  .substring(0, 10),
                              'quote_id': 'a',
                              'source_name': 'Test source',
                              'source_url': '',
                              'payout_method': 'Bank',
                              'direction': 'thb_mmk',
                              'rate_micros': (125000000 + (i % 4) * 700000),
                            },
                        ],
                      }
                    : {
                        'schema_version': 2,
                        'revision': 1,
                        'published_at': now.toIso8601String(),
                        'notice': '',
                        'quotes': [q],
                      },
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: CurrencyApp(repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('rate_trend_card')), findsOneWidget);
        expect(find.widgetWithText(TextButton, '7 ရက်'), findsOneWidget);
        await tester.tap(find.text('30 ရက်'));
        await tester.pumpAndSettle();
        expect(
          find.text('14 ရက်'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((e) => e.data)
              .join(' | '),
        );
        final plot = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RateTrendPainter,
        );
        await tester.ensureVisible(plot);
        await tester.tap(plot);
        await tester.pumpAndSettle();
        expect(
          find.text('အမှတ်လေးကို ထိပြီး ဈေးနဲ့အချိန် ကြည့်လို့ရပါတယ်'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('RENDER_UI')) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/bahtzay-ui-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        await tester.pumpWidget(const SizedBox());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
