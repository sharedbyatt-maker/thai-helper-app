import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/daily_tools.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/rate_history.dart';
import 'package:thai_helper/exchange/storage.dart';

ExchangeQuote quote(ExchangeDirection side, int rate, DateTime at) =>
    ExchangeQuote(
      id: 'daily-${side.key}',
      label: side.label,
      direction: side,
      rateMicros: rate,
      observedAt: at,
      validUntil: at.add(const Duration(days: 1)),
      sourceChecked: true,
    );
RatePoint point(ExchangeQuote q, DateTime at) {
  final b = at.toUtc().add(const Duration(hours: 7));
  return RatePoint(
    day: DateTime.utc(b.year, b.month, b.day),
    observedAt: at,
    rateMicros: q.rateMicros,
    quoteId: q.id,
    sourceName: 'private source',
    sourceUrl: '',
    payoutMethod: '',
    direction: q.direction,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Comparison uses the latest actual earlier Bangkok day, preserves gaps and excludes the opposite direction',
    () {
      final now = DateTime.parse('2026-10-17T01:00:00Z'),
          q = quote(
            ExchangeDirection.thbMmk,
            130000000,
            DateTime.parse('2026-10-17T00:00:00Z'),
          );
      final old = quote(
        ExchangeDirection.thbMmk,
        125000000,
        now.subtract(const Duration(days: 3)),
      );
      final opposite = quote(
        ExchangeDirection.mmkThb,
        150000000,
        now.subtract(const Duration(days: 1)),
      );
      final history = RateHistory([
        point(old, old.observedAt),
        point(opposite, opposite.observedAt),
        point(q, q.observedAt),
      ]);
      final found = priorDailyPoint(q, history, now: now)!;
      expect(found.rateMicros, 125000000);
      expect(comparisonDay(found, now: now), '14/10 ရက်က');
      expect(priorDailyPoint(q, const RateHistory([]), now: now), isNull);
    },
  );
  test(
    'A still-valid yesterday quote is never treated as a new today observation or compared with itself',
    () {
      final now = DateTime.parse('2026-10-17T01:00:00Z');
      final q = quote(
        ExchangeDirection.thbMmk,
        130000000,
        now.subtract(const Duration(hours: 12)),
      );
      expect(
        priorDailyPoint(q, RateHistory([point(q, q.observedAt)]), now: now),
        isNull,
      );
    },
  );
  test(
    'Backups merge without replacing existing records, reject malformed or unsupported data atomically, and retain completion dates',
    () {
      final now = DateTime.now(),
          q = quote(ExchangeDirection.mmkThb, 140000000, DateTime.now());
      final r = PersonalRecord(
        id: 'a',
        name: 'test',
        note: '',
        quote: q,
        budgetMinor: 10000000,
        receivedMinor: 71428,
        savedAt: now,
      ).withCompleted(true, at: DateTime(2026, 9, 30));
      final exported = RecordStore().export([r]);
      final first = previewRecordImport(exported, []);
      expect(first.added, 1);
      expect(first.records.single.completedAt, DateTime(2026, 9, 30));
      final repeated = previewRecordImport(exported, [r]);
      expect(repeated.added, 0);
      expect(repeated.skipped, 1);
      expect(repeated.records.single, same(r));
      final changed = r.toJson()..['budget_minor'] = -1;
      expect(
        () => previewRecordImport(
          jsonEncode({
            'schema_version': 1,
            'records': [r.toJson(), changed],
          }),
          [],
        ),
        throwsFormatException,
      );
      expect(
        () => previewRecordImport('{"schema_version":99,"records":[]}', [r]),
        throwsFormatException,
      );
      expect(() => previewRecordImport('not JSON', [r]), throwsFormatException);
    },
  );
  testWidgets(
    'Saved personal amounts show direction-correct differences, survive switching, and stale rates cannot calculate',
    (t) async {
      final now = DateTime.now().toUtc(),
          thb = quote(
            ExchangeDirection.thbMmk,
            130000000,
            DateTime.now().toUtc(),
          ),
          mmk = quote(
            ExchangeDirection.mmkThb,
            145000000,
            DateTime.now().toUtc(),
          );
      final history = RateHistory([
        point(
          quote(ExchangeDirection.thbMmk, 125000000, now),
          now.subtract(const Duration(days: 1)),
        ),
        point(
          quote(ExchangeDirection.mmkThb, 140000000, now),
          now.subtract(const Duration(days: 1)),
        ),
      ]);
      Future<void> show(ExchangeQuote q) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DailyTools(
                  quote: q,
                  quotes: [thb, mmk],
                  history: history,
                  direction: q.direction,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await show(thb);
      await t.enterText(find.byKey(const ValueKey('watch_amount')), '1000');
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('130,000 ကျပ်'), findsOneWidget);
      expect(find.text('မနေ့ကထက် 5,000 ကျပ် ပိုရမယ်'), findsOneWidget);
      await show(mmk);
      expect(find.text('689.65 ဘတ်'), findsOneWidget);
      expect(find.text('မနေ့ကထက် 24.63 ဘတ် လျော့ရမယ်'), findsOneWidget);
      await show(thb);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('watch_amount')))
            .controller!
            .text,
        '1000',
      );
      final old = quote(
        ExchangeDirection.thbMmk,
        130000000,
        now.subtract(const Duration(days: 2)),
      );
      await show(old);
      expect(find.byKey(const ValueKey('watch_payout')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Personal tools, alerts and timestamped share card remain readable with real Myanmar fonts at phone widths',
    (t) async {
      for (final font in [
        ('Noto Sans Myanmar', 'assets/fonts/NotoSansMyanmar.ttf'),
        ('Noto Sans Symbols 2', 'assets/fonts/NotoSansSymbols2-Regular.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
      }
      for (final width in [320.0, 430.0, 1100.0]) {
        t.view.physicalSize = Size(width, 1100);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 1.3;
        final q = quote(ExchangeDirection.thbMmk, 133689840, DateTime.now());
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Noto Sans Myanmar'),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DailyTools(
                  quote: q,
                  quotes: [q],
                  history: const RateHistory([]),
                  direction: q.direction,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('ဈေးအသိပေးမယ်'));
        await t.tap(find.text('ဈေးအသိပေးမယ်'));
        await t.pumpAndSettle();
        await t.tap(find.byType(SwitchListTile));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('alert_target')), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.tap(find.text('ပိတ်မယ်'));
        await t.pumpAndSettle();
        final capture = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: capture,
                  child: SizedBox(
                    width: 320,
                    child: RateShareCard(quotes: [q]),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.textContaining('private source'), findsNothing);
        expect(find.textContaining('ဈေးစစ်ချိန်'), findsOneWidget);
        expect(t.takeException(), isNull);
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final png = await boundary.toImage(pixelRatio: 1);
        expect(png.width, greaterThan(0));
        png.dispose();
        await t.pumpWidget(const SizedBox());
        t.platformDispatcher.clearTextScaleFactorTestValue();
      }
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
}
