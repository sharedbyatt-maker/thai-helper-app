import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// THB -> MMK remittance channel data + comparison logic.
///
/// Data source: backend API (/api/rates) when RATES_API is set and
/// reachable, otherwise the bundled snapshot (manual, may be stale).
/// The snapshot's updated_at is always shown so staleness is honest.

class FeeTier {
  final double min;
  final double max;
  final double fee;

  FeeTier({required this.min, required this.max, required this.fee});

  factory FeeTier.fromJson(Map<String, dynamic> j) => FeeTier(
        min: (j['min'] as num).toDouble(),
        max: (j['max'] as num).toDouble(),
        fee: (j['fee'] as num).toDouble(),
      );
}

class RateChannel {
  final String id;
  final String name;
  final String nameMy;
  final double rateThbMmk;
  final double? flatFee;
  final double? feePercent;
  final List<FeeTier> feeTiers;
  final String transferTimeMy;
  final String payoutMy;
  final String notesMy;
  final String referralUrl;
  final bool verified;

  RateChannel({
    required this.id,
    required this.name,
    required this.nameMy,
    required this.rateThbMmk,
    this.flatFee,
    this.feePercent,
    required this.feeTiers,
    required this.transferTimeMy,
    required this.payoutMy,
    required this.notesMy,
    required this.referralUrl,
    required this.verified,
  });

  factory RateChannel.fromJson(Map<String, dynamic> j) => RateChannel(
        id: j['id'] as String,
        name: j['name'] as String,
        nameMy: j['name_my'] as String? ?? j['name'] as String,
        rateThbMmk: (j['rate_thb_mmk'] as num).toDouble(),
        flatFee: (j['flat_fee'] as num?)?.toDouble(),
        feePercent: (j['fee_percent'] as num?)?.toDouble(),
        feeTiers: ((j['fee_tiers'] ?? []) as List)
            .map((t) => FeeTier.fromJson(t as Map<String, dynamic>))
            .toList(),
        transferTimeMy: j['transfer_time_my'] as String? ?? '',
        payoutMy: j['payout_my'] as String? ?? '',
        notesMy: j['notes_my'] as String? ?? '',
        referralUrl: j['referral_url'] as String? ?? '',
        verified: j['verified'] as bool? ?? false,
      );

  double? feeFor(double amount) {
    if (flatFee != null) return flatFee;
    if (feePercent != null) {
      return double.parse(
          (amount * feePercent! / 100).toStringAsFixed(2));
    }
    for (final t in feeTiers) {
      if (t.min <= amount && amount <= t.max) return t.fee;
    }
    return null;
  }
}

class RateQuote {
  final RateChannel channel;
  final double amountThb;
  final double feeThb;
  final int receivedMmk;

  RateQuote({
    required this.channel,
    required this.amountThb,
    required this.feeThb,
    required this.receivedMmk,
  });
}

class RateData {
  final String updatedAt;
  final double midMarketRate;
  final String disclaimerMy;
  final List<RateChannel> channels;
  final List<HistoryPoint> history;

  RateData({
    required this.updatedAt,
    required this.midMarketRate,
    required this.disclaimerMy,
    required this.channels,
    required this.history,
  });

  factory RateData.fromJson(Map<String, dynamic> j) => RateData(
        updatedAt: j['updated_at'] as String? ?? '',
        midMarketRate:
            ((j['mid_market_rate'] ?? 0) as num).toDouble(),
        disclaimerMy: j['disclaimer_my'] as String? ?? '',
        channels: ((j['channels'] ?? []) as List)
            .map((c) =>
                RateChannel.fromJson(c as Map<String, dynamic>))
            .toList(),
        history: ((j['history'] ?? []) as List)
            .map((h) =>
                HistoryPoint.fromJson(h as Map<String, dynamic>))
            .toList(),
      );

  /// 7-day change in percent, null when not enough data.
  double? get change7dPct {
    if (history.length < 2) return null;
    final first = history.first.mid;
    final last = history.last.mid;
    if (first == 0) return null;
    return (last - first) / first * 100;
  }

  double? get high7d => history.isEmpty
      ? null
      : history
          .map((h) => h.mid)
          .reduce((a, b) => a > b ? a : b);

  double? get low7d => history.isEmpty
      ? null
      : history
          .map((h) => h.mid)
          .reduce((a, b) => a < b ? a : b);
}

class HistoryPoint {
  final String date;
  final double mid;

  HistoryPoint({required this.date, required this.mid});

  factory HistoryPoint.fromJson(Map<String, dynamic> j) =>
      HistoryPoint(
        date: j['date'] as String? ?? '',
        mid: ((j['mid'] ?? 0) as num).toDouble(),
      );
}

class RatesService {
  /// Set at build time: flutter build web --dart-define=RATES_API=https://...
  static const apiBase =
      String.fromEnvironment('RATES_API', defaultValue: '');

  static final RatesService _i = RatesService._internal();
  factory RatesService() => _i;
  RatesService._internal();

  RateData? _cache;

  Future<RateData> load() async {
    if (apiBase.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse('$apiBase/api/rates'))
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          _cache = RateData.fromJson(
              json.decode(res.body) as Map<String, dynamic>);
          return _cache!;
        }
      } catch (_) {
        // fall through to bundled snapshot
      }
    }
    final raw = await rootBundle
        .loadString('assets/data/rates_snapshot.json');
    _cache = RateData.fromJson(
        json.decode(raw) as Map<String, dynamic>);
    return _cache!;
  }

  bool get usingLiveApi => apiBase.isNotEmpty;

  List<RateQuote> compare(RateData data, double amount) {
    final quotes = <RateQuote>[];
    for (final ch in data.channels) {
      final fee = ch.feeFor(amount);
      if (fee == null || fee >= amount) continue;
      quotes.add(RateQuote(
        channel: ch,
        amountThb: amount,
        feeThb: fee,
        receivedMmk:
            ((amount - fee) * ch.rateThbMmk).round(),
      ));
    }
    quotes.sort((a, b) =>
        b.receivedMmk.compareTo(a.receivedMmk));
    return quotes;
  }
}
