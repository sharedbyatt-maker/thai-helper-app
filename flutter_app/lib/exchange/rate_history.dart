import 'dart:convert';

import 'models.dart';

class RatePoint {
  final DateTime day;
  final DateTime? observedAt;
  DateTime get timestamp => observedAt ?? day;
  final int rateMicros, revision;
  final String quoteId, sourceName, sourceUrl, payoutMethod;
  final ExchangeDirection direction;
  const RatePoint({
    required this.day,
    this.observedAt,
    this.revision = 0,
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
      observedAt: j['observed_at'] == null
          ? null
          : DateTime.parse(j['observed_at'] as String).toUtc(),
      rateMicros: rate,
      revision: j['revision'] is int ? j['revision'] as int : 0,
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
      payoutMethod == q.payoutMethod;
}

class RateHistory {
  final List<RatePoint> points, observations;
  final bool cached;
  const RateHistory(
    this.points, {
    this.observations = const [],
    this.cached = false,
  });
  factory RateHistory.decode(String raw, {bool cached = false}) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['schema_version'] != 1 ||
        j['timezone'] != 'Asia/Bangkok' ||
        j['points'] is! List ||
        (j['points'] as List).length > 12000 ||
        (j['observations'] != null &&
            (j['observations'] is! List ||
                (j['observations'] as List).length > 12000))) {
      throw const FormatException('Invalid history');
    }
    return RateHistory(
      (j['points'] as List)
          .map((p) => RatePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      observations: (j['observations'] as List? ?? [])
          .map((p) => RatePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      cached: cached,
    );
  }
  List<RatePoint> referenceSeries(ExchangeQuote q, int days, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    final bangkok = current.add(const Duration(hours: 7));
    final today = DateTime.utc(bangkok.year, bangkok.month, bangkok.day);
    final first = today.subtract(Duration(days: days - 1));
    final candidates = days == 1 ? observations : points;
    final result = <DateTime, RatePoint>{};
    for (final p in candidates) {
      if (p.quoteId != q.id ||
          p.direction != q.direction ||
          p.payoutMethod != q.payoutMethod ||
          p.day.isBefore(first) ||
          p.day.isAfter(today) ||
          p.timestamp.isAfter(current.add(const Duration(minutes: 5))))
        continue;
      // One stable published quote ID is the owner's reference feed. Preserve
      // its real observations when the optional display/source name changes.
      final key = days == 1 ? p.timestamp : p.day;
      final existing = result[key];
      if (existing == null ||
          p.timestamp.isAfter(existing.timestamp) ||
          (p.timestamp == existing.timestamp &&
              p.revision >= existing.revision))
        result[key] = p;
    }
    final observed = q.observedAt.toUtc();
    final observedBangkok = observed.add(const Duration(hours: 7));
    final quoteDay = DateTime.utc(
      observedBangkok.year,
      observedBangkok.month,
      observedBangkok.day,
    );
    if (!quoteDay.isBefore(first) &&
        !quoteDay.isAfter(today) &&
        !observed.isAfter(current.add(const Duration(minutes: 5)))) {
      final point = RatePoint(
        day: quoteDay,
        observedAt: observed,
        rateMicros: q.rateMicros,
        quoteId: q.id,
        sourceName: q.sourceName,
        sourceUrl: q.sourceUrl,
        payoutMethod: q.payoutMethod,
        direction: q.direction,
      );
      final key = days == 1 ? observed : quoteDay;
      final existing = result[key];
      if (existing == null || !existing.timestamp.isAfter(observed))
        result[key] = point;
    }
    return result.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
