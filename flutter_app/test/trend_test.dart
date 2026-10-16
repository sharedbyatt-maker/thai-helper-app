import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/rate_history.dart';

void main() {
  test(
    'Trend isolates source, direction and Bangkok window; never fills missing days',
    () {
      final q = ExchangeQuote(
        id: 'a',
        label: 'A',
        direction: ExchangeDirection.thbMmk,
        rateMicros: 125000000,
        sourceName: 'A',
        payoutMethod: 'bank',
        observedAt: DateTime.utc(2026, 10, 15),
        validUntil: DateTime.utc(2026, 10, 16),
      );
      Map<String, dynamic> p(
        String day, {
        String source = 'A',
        String direction = 'thb_mmk',
      }) => {
        'day': day,
        'quote_id': 'a',
        'source_name': source,
        'source_url': 'https://example.com/different-post',
        'payout_method': 'bank',
        'direction': direction,
        'rate_micros': 125000000,
      };
      final h = RateHistory.decode(
        jsonEncode({
          'schema_version': 1,
          'timezone': 'Asia/Bangkok',
          'points': [
            p('2026-10-09'),
            p('2026-10-15'),
            p('2026-10-08'),
            p('2026-10-16'),
            p('2026-10-15', source: 'B'),
            p('2026-10-15', direction: 'mmk_thb'),
          ],
        }),
      );
      expect(h.series(q, 7, now: DateTime.utc(2026, 10, 15, 12)).length, 2);
      expect(h.series(q, 30, now: DateTime.utc(2026, 10, 15, 12)).length, 3);
      expect(
        h.series(q, 7, now: DateTime.utc(2026, 10, 15, 18)).length,
        2,
      ); // Bangkok is already Oct 16.
    },
  );
  test(
    'Reference graph keeps real intraday publications across display-name changes but isolates direction and quote ID',
    () {
      final q = ExchangeQuote(
        id: 'daily',
        label: 'Daily',
        direction: ExchangeDirection.mmkThb,
        rateMicros: 133333333,
        sourceName: 'New label',
        payoutMethod: 'bank',
        observedAt: DateTime.utc(2026, 10, 16, 15),
        validUntil: DateTime.utc(2026, 10, 17, 15),
      );
      RatePoint point(
        int hour,
        int rate, {
        String source = 'Old label',
        String id = 'daily',
        ExchangeDirection direction = ExchangeDirection.mmkThb,
      }) => RatePoint(
        day: DateTime.utc(2026, 10, 16),
        observedAt: DateTime.utc(2026, 10, 16, hour),
        rateMicros: rate,
        quoteId: id,
        sourceName: source,
        sourceUrl: '',
        payoutMethod: 'bank',
        direction: direction,
      );
      final history = RateHistory(
        [point(14, 134000000), point(13, 135000000)],
        observations: [
          point(13, 135000000),
          point(14, 134000000),
          point(14, 124000000, id: 'another'),
          point(14, 123000000, direction: ExchangeDirection.thbMmk),
        ],
      );
      final current = DateTime.utc(2026, 10, 16, 16);
      final intraday = history.referenceSeries(q, 1, now: current);
      expect(intraday.length, 3);
      expect(intraday.first.sourceName, 'Old label');
      expect(intraday.last.rateMicros, q.rateMicros);
      final daily = history.referenceSeries(q, 7, now: current);
      expect(daily.length, 1);
      expect(daily.single.rateMicros, q.rateMicros);
      expect(history.series(q, 7, now: current), isEmpty);
      final single = const RateHistory([]).referenceSeries(q, 1, now: current);
      expect(single.length, 1);
      expect(single.single.observedAt, q.observedAt);
    },
  );
}
