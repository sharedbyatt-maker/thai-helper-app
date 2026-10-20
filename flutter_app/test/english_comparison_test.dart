import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/daily_tools.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/rate_history.dart';
import 'package:thai_helper/exchange/user_language.dart' as language;

import 'daily_tools_test.dart' show point, quote;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final side in ExchangeDirection.values) {
    testWidgets('English actual prior-day comparison for ${side.key}', (t) async {
      final now = DateTime.now().toUtc();
      final current = quote(side, 130000000, now);
      final previous = quote(side, 125000000, now.subtract(const Duration(days: 1)));
      await t.pumpWidget(
        language.UserLanguageScope(
          language: language.UserLanguage.english,
          onChanged: (_) {},
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DailyTools(
                  quote: current,
                  quotes: [current],
                  history: RateHistory([point(previous, previous.observedAt)]),
                  direction: side,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final paragraphs = t.widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText()).toList();
      expect(paragraphs.where((text) => RegExp(r'[\u1000-\u109f]').hasMatch(text)), isEmpty);
      expect(paragraphs, contains(side == ExchangeDirection.thbMmk
          ? '50,000 MMK more than yesterday.'
          : '30.77 THB less than yesterday.'));
      expect(paragraphs, contains(side == ExchangeDirection.thbMmk
          ? 'You pay 30.77 THB less per 100,000 MMK than yesterday.'
          : 'You receive 30.77 THB less per 100,000 MMK than yesterday.'));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  test('English comparisons retain gaps and unchanged-rate meaning', () {
    final now = DateTime.now().toUtc();
    final current = quote(ExchangeDirection.thbMmk, 125000000, now);
    final previous = point(current, now.subtract(const Duration(days: 3)));
    final date = '${previous.day.day}/${previous.day.month}';
    expect(comparisonDay(previous, now: now, english: true), date);
    expect(dailyRateBrief(current, previous, english: true), 'Same rate as $date.');
  });

  testWidgets('An expired quote explains the unavailable English quick estimate', (t) async {
    final expired = quote(ExchangeDirection.thbMmk, 125000000,
        DateTime.now().toUtc().subtract(const Duration(days: 2)));
    await t.pumpWidget(
      language.UserLanguageScope(
        language: language.UserLanguage.english,
        onChanged: (_) {},
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(
          child: DailyTools(quote: expired, history: const RateHistory([]),
              quotes: [expired], direction: expired.direction),
        ))),
      ),
    );
    await t.pumpAndSettle();
    final paragraphs = t.widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText()).toList();
    expect(paragraphs, contains(
        'This rate needs rechecking, so the quick estimate is unavailable.'));
    expect(paragraphs.where((text) => RegExp(r'[\u1000-\u109f]').hasMatch(text)), isEmpty);
    expect(find.byKey(const ValueKey('watch_payout')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
