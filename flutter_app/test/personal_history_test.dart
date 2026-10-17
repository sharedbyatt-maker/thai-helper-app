import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/rates_repository.dart';
import 'package:thai_helper/exchange/storage.dart';

PersonalRecord record(
  String id,
  ExchangeDirection side,
  DateTime at, {
  bool completed = true,
  int multiple = 1,
}) {
  final q = ExchangeQuote(
    id: id,
    label: 'ကိုယ်ထည့်ထားတဲ့ဈေး',
    direction: side,
    rateMicros: side == ExchangeDirection.thbMmk ? 125000000 : 140000000,
    observedAt: at,
    validUntil: at.add(const Duration(days: 1)),
  );
  final budget =
      (side == ExchangeDirection.thbMmk ? 100000 : 10000000) * multiple;
  return PersonalRecord(
    id: id,
    name: q.label,
    note: 'မှတ်ချက် $id',
    quote: q,
    budgetMinor: budget,
    receivedMinor: q.payout(budget),
    savedAt: at,
    completed: completed,
  );
}

Future<void> reveal(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
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

Future<void> start(
  WidgetTester t,
  List<PersonalRecord> records, {
  double width = 960,
  double scale = 1,
  bool dark = false,
}) async {
  SharedPreferences.setMockInitialValues({
    RecordStore.key: jsonEncode(records.map((r) => r.toJson()).toList()),
    'currency_theme': dark ? 'dark' : 'light',
  });
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  await t.pumpWidget(
    CurrencyApp(
      repository: RatesRepository(
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
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('မှတ်တမ်း'));
  await t.pumpAndSettle();
}

Future<void> close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  t.view.resetPhysicalSize();
  t.view.resetDevicePixelRatio();
  t.platformDispatcher.clearTextScaleFactorTestValue();
}

void main() {
  setUpAll(() async {
    for (final font in [
      ('Noto Sans Myanmar', 'assets/fonts/NotoSansMyanmar.ttf'),
      ('Noto Sans Symbols 2', 'assets/fonts/NotoSansSymbols2-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  testWidgets(
    'Monthly totals keep currencies separate, exclude pending and the previous Bangkok month, and update on completion',
    (t) async {
      final now = DateTime.now().toUtc();
      final bangkok = now.add(const Duration(hours: 7));
      // Just before midnight on the first day in Bangkok belongs to the previous month.
      final previous = DateTime.utc(
        bangkok.year,
        bangkok.month,
      ).subtract(const Duration(hours: 7, seconds: 1));
      await start(t, [
        record('thb', ExchangeDirection.thbMmk, now),
        record('mmk', ExchangeDirection.mmkThb, now),
        record(
          'pending',
          ExchangeDirection.mmkThb,
          now,
          completed: false,
          multiple: 2,
        ),
        record('previous', ExchangeDirection.mmkThb, previous, multiple: 3),
      ]);
      await t.tap(find.text('ဒီလ ငွေလဲပြီးသမျှ'));
      await t.pumpAndSettle();
      expect(find.text('စုစုပေါင်းပေးငွေ 1,000 ဘတ်'), findsOneWidget);
      expect(find.text('စုစုပေါင်းရငွေ 125,000 ကျပ်'), findsOneWidget);
      expect(find.text('စုစုပေါင်းပေးငွေ 100,000 ကျပ်'), findsOneWidget);
      expect(find.text('စုစုပေါင်းရငွေ 714.28 ဘတ်'), findsOneWidget);
      final pending = find.byKey(const ValueKey('record_completed_pending'));
      await reveal(t, pending);
      await t.tap(pending);
      await t.pumpAndSettle();
      await reveal(t, find.byKey(const ValueKey('monthly_summary_mmk_thb')));
      expect(find.text('စုစုပေါင်းပေးငွေ 300,000 ကျပ်'), findsOneWidget);
      expect(find.text('စုစုပေါင်းရငွေ 2,142.85 ဘတ်'), findsOneWidget);
      final saved = await RecordStore().load();
      expect(saved.singleWhere((r) => r.id == 'pending').completed, true);
      expect(saved.length, 4);
      expect(t.takeException(), isNull);
      await close(t);
    },
  );

  testWidgets(
    'Both directions can be filtered and deleting one confirmed record preserves the other direction',
    (t) async {
      final now = DateTime.now().toUtc();
      await start(t, [
        record('thb', ExchangeDirection.thbMmk, now),
        record('mmk', ExchangeDirection.mmkThb, now),
      ]);
      await t.tap(find.byKey(const ValueKey('records_filter_mmk_thb')));
      await t.pumpAndSettle();
      expect(find.text('မှတ်တမ်း 1 ခု'), findsOneWidget);
      await reveal(t, find.byKey(const ValueKey('record_amount_mmk')));
      expect(find.text('100,000 ကျပ် → 714.28 ဘတ်'), findsOneWidget);
      expect(find.byKey(const ValueKey('personal_record_thb')), findsNothing);
      expect((await RecordStore().load()).length, 2);
      final delete = find.byKey(const ValueKey('record_delete_mmk'));
      await reveal(t, delete);
      await t.tap(delete);
      await t.pumpAndSettle();
      await t.tap(find.text('မဖျက်တော့'));
      await t.pumpAndSettle();
      expect((await RecordStore().load()).length, 2);
      await t.tap(delete);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'ဖျက်မယ်'));
      await t.pumpAndSettle();
      expect((await RecordStore().load()).single.id, 'thb');
      await reveal(t, find.byKey(const ValueKey('records_filter_thb_mmk')));
      await t.tap(find.byKey(const ValueKey('records_filter_thb_mmk')));
      await t.pumpAndSettle();
      await reveal(t, find.byKey(const ValueKey('record_amount_thb')));
      expect(find.text('1,000 ဘတ် → 125,000 ကျပ်'), findsOneWidget);
      expect(t.takeException(), isNull);
      await close(t);
    },
  );

  testWidgets(
    'Personal records and expanded monthly totals fit phones with large Myanmar text and desktop',
    (t) async {
      for (final scenario in [(320.0, 1.3), (430.0, 1.4), (1100.0, 1.0)]) {
        final now = DateTime.now().toUtc();
        await start(
          t,
          [
            record('thb', ExchangeDirection.thbMmk, now, multiple: 100),
            record('mmk', ExchangeDirection.mmkThb, now, multiple: 100),
          ],
          width: scenario.$1,
          scale: scenario.$2,
          dark: scenario.$1 == 1100,
        );
        await t.tap(find.text('ဒီလ ငွေလဲပြီးသမျှ'));
        await t.pumpAndSettle();
        final position = t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        while (position.extentAfter > 0) {
          position.jumpTo(
            (position.pixels + 250).clamp(0, position.maxScrollExtent),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        expect(t.takeException(), isNull);
        await close(t);
      }
    },
  );
}
