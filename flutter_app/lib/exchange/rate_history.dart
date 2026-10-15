import 'dart:convert';

import 'models.dart';

class RatePoint {
  final DateTime day;
  final int rateMicros;
  final String quoteId, sourceName, sourceUrl, payoutMethod;
  final ExchangeDirection direction;
  const RatePoint({
    required this.day,
    required this.rateMicros,
    required this.quoteId,
    required this.sourceName,
    required this.sourceUrl,
    required this.payoutMethod,
    required this.direction,
  });
  factory RatePoint.fromJson(Map<String, dynamic> j) {
    final raw = j['day'] as String;
    final day = DateTime.parse('${raw}T00:00:00Z');
    final rate = j['rate_micros'];
    if (day.toIso8601String().substring(0, 10) != raw ||
        rate is! int ||
        rate < 1 ||
        rate > 1000000000000) {
      throw const FormatException('Invalid history point');
    }
    return RatePoint(
      day: day,
      rateMicros: rate,
      quoteId: j['quote_id'] as String,
      sourceName: j['source_name'] as String,
      sourceUrl: j['source_url'] as String,
      payoutMethod: j['payout_method'] as String,
      direction: parseDirection(j['direction']),
    );
  }
  bool matches(ExchangeQuote q) =>
      quoteId == q.id &&
      direction == q.direction &&
      sourceName == q.sourceName &&
      sourceUrl == q.sourceUrl &&
      payoutMethod == q.payoutMethod;
}

class RateHistory {
  final List<RatePoint> points;
  final bool cached;
  const RateHistory(this.points, {this.cached = false});
  factory RateHistory.decode(String raw, {bool cached = false}) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['schema_version'] != 1 ||
        j['timezone'] != 'Asia/Bangkok' ||
        j['points'] is! List ||
        (j['points'] as List).length > 12000) {
      throw const FormatException('Invalid history');
    }
    return RateHistory(
      (j['points'] as List)
          .map((p) => RatePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      cached: cached,
    );
  }
  List<RatePoint> series(ExchangeQuote q, int days, {DateTime? now}) {
    final bangkok = (now ?? DateTime.now()).toUtc().add(
      const Duration(hours: 7),
    );
    final today = DateTime.utc(bangkok.year, bangkok.month, bangkok.day);
    final first = today.subtract(Duration(days: days - 1));
    final daily = <DateTime, RatePoint>{};
    for (final p in points) {
      if (p.matches(q) && !p.day.isBefore(first) && !p.day.isAfter(today)) {
        daily[p.day] = p;
      }
    }
    return daily.values.toList()..sort((a, b) => a.day.compareTo(b.day));
  }
}
