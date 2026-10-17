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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<GlobalKey> start(WidgetTester tester, {bool charged = false}) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    if (const bool.fromEnvironment('RENDER_SIMPLE')) {
      for (final font in [
        ('Noto Sans Myanmar', 'assets/fonts/NotoSansMyanmar.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        final loader = FontLoader(font.$1)..addFont(rootBundle.load(font.$2));
        await loader.load();
      }
    }
    final now = DateTime.now();
    final repo = RatesRepository(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(
            r.url.path.endsWith('/history')
                ? {
                    'schema_version': 1,
                    'timezone': 'Asia/Bangkok',
                    'points': [],
                  }
                : {
                    'schema_version': 2,
                    'revision': 1,
                    'published_at': now.toIso8601String(),
                    'notice': '',
                    'quotes': charged
                        ? [
                            {
                              'id': 'a',
                              'label': 'Daily quote',
                              'direction': 'thb_mmk',
                              'rate_micros': 125000000,
                              'flat_fee_minor': 2000,
                              'fee_bps': 100,
                              'source_name': 'Test source',
                              'source_url': '',
                              'payout_method': 'Bank',
                              'observed_at': now
                                  .subtract(const Duration(minutes: 1))
                                  .toIso8601String(),
                              'valid_until': now
                                  .add(const Duration(days: 1))
                                  .toIso8601String(),
                              'source_checked': true,
                            },
                          ]
                        : [],
                  },
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CurrencyApp(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets(
    'Calculator has amount and rate without a source drawer or deduction controls',
    (tester) async {
      final key = await start(tester);
      await tester.tap(find.text('ငွေတွက်'));
      await tester.pumpAndSettle();
      expect(find.text('ဒီဈေးကို ဘယ်ကရလဲ?'), findsNothing);
      expect(find.text('သီးသန့်နုတ်ငွေ ရှိမှ ဖြည့်ပါ'), findsNothing);
      expect(find.byKey(const ValueKey('deduction_0')), findsNothing);
      expect(find.byKey(const ValueKey('deduction_percent_0')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('amount')), '1000');
      await tester.enterText(find.byKey(const ValueKey('rate_0')), '125');
      if (const bool.fromEnvironment('RENDER_SIMPLE')) {
        for (final f in [
          ('Noto Sans Myanmar', 'assets/fonts/NotoSansMyanmar.ttf'),
          ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        ]) {
          final loader = FontLoader(f.$1)..addFont(rootBundle.load(f.$2));
          await loader.load();
        }
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/simple-calculator.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      await reveal(tester, find.byKey(const ValueKey('calculate')));
      await tester.tap(find.byKey(const ValueKey('calculate')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('ရငွေ 125,000 ကျပ်'));
      expect(find.text('ရငွေ 125,000 ကျပ်'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
  testWidgets(
    'Legacy published deductions remain transparent without editable controls, and manual prices never retain hidden deductions',
    (tester) async {
      await start(tester, charged: true);
      await reveal(tester, find.text('ဒီနှုန်းနဲ့ တွက်မယ်').first);
      await tester.tap(find.text('ဒီနှုန်းနဲ့ တွက်မယ်').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('amount')), '1000');
      await reveal(tester, find.byKey(const ValueKey('published_deduction_0')));
      expect(find.byKey(const ValueKey('deduction_0')), findsNothing);
      expect(find.byKey(const ValueKey('deduction_percent_0')), findsNothing);
      expect(find.textContaining('Test source'), findsNothing);
      await reveal(tester, find.byKey(const ValueKey('calculate')));
      await tester.tap(find.byKey(const ValueKey('calculate')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('ရငွေ 121,250 ကျပ်'));
      expect(find.text('ရငွေ 121,250 ကျပ်'), findsOneWidget);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('rate_0')));
      await tester.enterText(find.byKey(const ValueKey('rate_0')), '800');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('published_deduction_0')), findsNothing);
      await reveal(tester, find.byKey(const ValueKey('calculate')));
      await tester.tap(find.byKey(const ValueKey('calculate')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('ရငွေ 125,000 ကျပ်'));
      expect(find.text('ရငွေ 125,000 ကျပ်'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
}
