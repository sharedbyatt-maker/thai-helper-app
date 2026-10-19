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
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/rates_repository.dart';
import 'package:thai_helper/exchange/storage.dart';

import 'support/app_update_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Noto Sans Myanmar', 'assets/fonts/NotoSansMyanmar.ttf'),
      ('Bahtzay UI Symbols', 'assets/fonts/BahtzayUISymbols.ttf'),
      ('Noto Sans Symbols 2', 'assets/fonts/NotoSansSymbols2-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  for (final scenario in [
    (320.0, 1.4, 'my', 'light'),
    (360.0, 1.4, 'en', 'dark'),
    (375.0, 1.0, 'my', 'dark'),
    (390.0, 2.0, 'my', 'light'),
    (430.0, 2.0, 'en', 'light'),
    (768.0, 1.0, 'en', 'dark'),
    (1024.0, 1.0, 'my', 'light'),
    (1440.0, 1.0, 'en', 'light'),
  ]) {
    testWidgets(
      'Four public pages at ${scenario.$1}px, ${scenario.$2}x, ${scenario.$3}, ${scenario.$4}',
      (t) async {
        SharedPreferences.setMockInitialValues({
          'user_language': scenario.$3,
          'currency_theme': scenario.$4,
        });
        t.view.physicalSize = Size(scenario.$1, 1000);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scenario.$2;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        final now = DateTime.now(), day = budgetToday();
        final q = ExchangeQuote(
          id: 'official',
          label: 'Official rate',
          direction: ExchangeDirection.thbMmk,
          rateMicros: 125000000,
          sourceName: 'Published source',
          sourceChecked: true,
          observedAt: now.subtract(const Duration(minutes: 5)),
          validUntil: now.add(const Duration(days: 1)),
        );
        await BudgetStore().save(
          BudgetData(
            opening: 1500000,
            entries: [
              BudgetEntry(
                id: 'income',
                day: budgetDay(day),
                kind: BudgetKind.income,
                amount: 2000000,
                category: 'salary',
              ),
              BudgetEntry(
                id: 'food',
                day: budgetDay(day),
                kind: BudgetKind.expense,
                amount: 25000,
                category: 'food',
              ),
            ],
            plans: [
              BudgetPlan(
                id: 'plan',
                start: budgetDay(day),
                end: budgetDay(day.add(const Duration(days: 15))),
                fixed: 300000,
                home: 200000,
                savings: 100000,
              ),
            ],
          ),
          expectedRevision: 0,
        );
        await RecordStore().save([
          PersonalRecord(
            id: 'saved',
            name: 'Family',
            note: 'Personal note',
            quote: q,
            budgetMinor: 100000,
            receivedMinor: q.payout(100000),
            savedAt: now,
          ),
        ]);
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
                        'quotes': [q.toJson()],
                      },
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: CurrencyApp(repository: repo, updates: noNativeUpdates()),
          ),
        );
        await t.pumpAndSettle();
        for (var index = 0; index < 4; index++) {
          await t.tap(find.byType(NavigationDestination).at(index));
          await t.pumpAndSettle();
          expect(
            t.takeException(),
            isNull,
            reason: 'tab $index at ${scenario.$1}px',
          );
          expect(
            t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
            index,
          );
          if (scenario.$3 == 'en') {
            final untranslated = find
                .byType(RichText)
                .evaluate()
                .map((e) => (e.widget as RichText).text.toPlainText())
                .where(
                  (text) =>
                      RegExp(r'[\u1000-\u109f]').hasMatch(text) &&
                      text != 'ဘတ်ဈေး',
                )
                .toSet();
            expect(
              untranslated,
              isEmpty,
              reason: 'English tab $index still has UI copy: $untranslated',
            );
          }
          if (const bool.fromEnvironment('RENDER_UX')) {
            await t.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final folder = Directory(
                Platform.environment['UX_QA_DIR'] ?? 'build/ux-qa',
              )..createSync(recursive: true);
              File(
                '${folder.path}/${scenario.$1.toInt()}-${scenario.$3}-$index.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
