import 'dart:convert';

const maxMoneyMinor = 100000000000; // 1 billion major units; safe in JS.
const rateScale = 1000000;

enum ExchangeDirection { thbMmk, mmkThb }

extension DirectionText on ExchangeDirection {
  String get key => this == ExchangeDirection.thbMmk ? 'thb_mmk' : 'mmk_thb';
  String get label =>
      this == ExchangeDirection.thbMmk ? 'ဘတ်ပေး → ကျပ်ယူ' : 'ကျပ်ပေး → ဘတ်ယူ';
  String get from => this == ExchangeDirection.thbMmk ? 'ဘတ်' : 'ကျပ်';
  String get to => this == ExchangeDirection.thbMmk ? 'ကျပ်' : 'ဘတ်';
}

String normalizeDigits(String value) {
  const burmese = '၀၁၂၃၄၅၆၇၈၉';
  const thai = '๐๑๒๓๔๕๖๗๘๙';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(burmese[i], '$i').replaceAll(thai[i], '$i');
  }
  return value;
}

int? parseMoney(String value, {bool allowZero = false}) {
  final raw = normalizeDigits(value).replaceAll(',', '').trim();
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(raw)) return null;
  final parts = raw.split('.');
  final n =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return n <= maxMoneyMinor && (allowZero ? n >= 0 : n > 0) ? n : null;
}

String money(int minor) {
  final major = minor ~/ 100;
  final s = major.toString();
  final grouped = s.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return minor % 100 == 0
      ? grouped
      : '$grouped.${(minor % 100).toString().padLeft(2, '0')}';
}

String rateText(int micros) =>
    (micros / rateScale).toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');

ExchangeDirection parseDirection(Object? raw) {
  if (raw == 'thb_mmk') return ExchangeDirection.thbMmk;
  if (raw == 'mmk_thb') return ExchangeDirection.mmkThb;
  throw const FormatException('Unknown direction');
}

class ExchangeQuote {
  final String id, label, sourceName, sourceUrl, payoutMethod, note;
  final ExchangeDirection direction;
  final int rateMicros, flatFeeMinor, feeBps;
  final DateTime observedAt, validUntil;
  final bool sourceChecked;

  const ExchangeQuote({
    required this.id,
    required this.label,
    required this.direction,
    required this.rateMicros,
    this.flatFeeMinor = 0,
    this.feeBps = 0,
    this.sourceName = '',
    this.sourceUrl = '',
    this.payoutMethod = '',
    this.note = '',
    required this.observedAt,
    required this.validUntil,
    this.sourceChecked = false,
  });

  factory ExchangeQuote.fromJson(Map<String, dynamic> j) {
    final rate = j['rate_micros'];
    final flat = j['flat_fee_minor'] ?? 0;
    final bps = j['fee_bps'] ?? 0;
    if (rate is! int ||
        rate <= 0 ||
        rate > 1000000000000 ||
        flat is! int ||
        flat < 0 ||
        flat > maxMoneyMinor ||
        bps is! int ||
        bps < 0 ||
        bps >= 10000) {
      throw const FormatException('Invalid rate or fee');
    }
    final observed = DateTime.parse(j['observed_at'] as String);
    final expires = DateTime.parse(j['valid_until'] as String);
    if (!expires.isAfter(observed)) {
      throw const FormatException('Invalid expiry');
    }
    return ExchangeQuote(
      id: j['id'] as String,
      label: j['label'] as String,
      direction: parseDirection(j['direction']),
      rateMicros: rate,
      flatFeeMinor: flat,
      feeBps: bps,
      sourceName: j['source_name'] as String? ?? '',
      sourceUrl: j['source_url'] as String? ?? '',
      payoutMethod: j['payout_method'] as String? ?? '',
      note: j['note'] as String? ?? '',
      observedAt: observed,
      validUntil: expires,
      sourceChecked: j['source_checked'] == true,
    );
  }

  bool activeAt(DateTime now) =>
      !observedAt.isAfter(now) && validUntil.isAfter(now);
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'direction': direction.key,
    'rate_micros': rateMicros,
    'flat_fee_minor': flatFeeMinor,
    'fee_bps': feeBps,
    'source_name': sourceName,
    'source_url': sourceUrl,
    'payout_method': payoutMethod,
    'note': note,
    'observed_at': observedAt.toIso8601String(),
    'valid_until': validUntil.toIso8601String(),
    'source_checked': sourceChecked,
  };

  /// Input is the TOTAL budget. Percentage fee is rounded up to the next minor unit.
  int feeFor(int budget) =>
      flatFeeMinor +
      ((BigInt.from(budget) * BigInt.from(feeBps) + BigInt.from(9999)) ~/
              BigInt.from(10000))
          .toInt();

  int payout(int budget) {
    if (budget <= 0 || budget > maxMoneyMinor) return 0;
    final usable = budget - feeFor(budget);
    if (usable <= 0) return 0;
    final a = BigInt.from(usable);
    final rate = BigInt.from(rateMicros);
    final scale = BigInt.from(rateScale);
    final result = direction == ExchangeDirection.thbMmk
        ? a * rate ~/ scale
        : a * scale ~/ rate;
    if (result > BigInt.from(maxMoneyMinor)) {
      throw const FormatException('ရလဒ်ပမာဏ ကြီးလွန်းပါသည်');
    }
    return result.toInt();
  }

  /// Flat + percentage fee payout is monotonic; no stepped fee-tier search.
  int? requiredBudget(int target) {
    if (target <= 0 || target > maxMoneyMinor) return null;
    int output(int n) {
      try {
        return payout(n);
      } on FormatException {
        return maxMoneyMinor + 1;
      }
    }

    var lo = 1, hi = 100;
    while (hi < maxMoneyMinor && output(hi) < target) {
      hi = (hi * 2).clamp(1, maxMoneyMinor);
    }
    if (output(hi) < target) return null;
    while (lo < hi) {
      final mid = lo + (hi - lo) ~/ 2;
      if (output(mid) >= target) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }
}

class QuoteSheet {
  final int revision;
  final String notice;
  final DateTime? publishedAt;
  final List<ExchangeQuote> quotes;
  const QuoteSheet({
    required this.revision,
    required this.notice,
    required this.publishedAt,
    required this.quotes,
  });
  factory QuoteSheet.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['schema_version'] != 2 || j['revision'] is! int) {
      throw const FormatException('Unsupported rates');
    }
    return QuoteSheet(
      revision: j['revision'] as int,
      notice: j['notice'] as String? ?? '',
      publishedAt: j['published_at'] == null
          ? null
          : DateTime.parse(j['published_at'] as String),
      quotes: (j['quotes'] as List)
          .map((q) => ExchangeQuote.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ParsedRate {
  final int rateMicros;
  final String interpretation;
  const ParsedRate(this.rateMicros, this.interpretation);
}

/// Deliberately bounded parser. Direction and fees must be confirmed by the user.
/// Refuses messages with multiple different rate pairs rather than guessing.
ParsedRate? parseChatRate(String text) {
  if (text.length > 4000) return null;
  final raw = normalizeDigits(text).replaceAll(',', '').toLowerCase();
  const number = r'(\d+(?:\.\d+)?)';
  const baht = r'(?:ဘတ်|บาท|thb|฿)';
  const kyat = r'(?:ကျပ်|mmk)';
  final found = <ParsedRate>[];
  void collect(RegExp exp, bool bahtFirst, {bool lakh = false}) {
    for (final m in exp.allMatches(raw)) {
      final a = double.tryParse(m[1]!);
      final b = double.tryParse(m[2]!);
      if (a == null ||
          b == null ||
          !a.isFinite ||
          !b.isFinite ||
          a <= 0 ||
          b <= 0 ||
          a > 1e12 ||
          b > 1e12) {
        continue;
      }
      final rate = lakh ? a * 100000 / b : (bahtFirst ? b / a : a / b);
      final scaled = rate * rateScale;
      if (!scaled.isFinite || scaled < 1 || scaled > 1000000000000) {
        continue;
      }
      final micros = scaled.round();
      if (micros > 0 && micros <= 1000000000000) {
        found.add(
          ParsedRate(
            micros,
            '၁ ဘတ် = ${(micros / rateScale).toStringAsFixed(6)} ကျပ်',
          ),
        );
      }
    }
  }

  collect(
    RegExp('$number\\s*$baht\\s*(?:=|ကို|လျှင်|ဆို)\\s*$number\\s*$kyat'),
    true,
  );
  collect(
    RegExp('$number\\s*$kyat\\s*(?:=|ကို|လျှင်|ဆို)\\s*$number\\s*$baht'),
    false,
  );
  collect(
    RegExp(
      '(?:ကျပ်\\s*)?$number\\s*သိန်း\\s*(?:ကျပ်\\s*)?(?:=|ကို|လျှင်|ဆို)\\s*$number\\s*$baht',
    ),
    false,
    lakh: true,
  );
  if (found.isEmpty || found.map((r) => r.rateMicros).toSet().length != 1) {
    return null;
  }
  return found.first;
}
