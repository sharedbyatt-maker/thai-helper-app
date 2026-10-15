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
}
