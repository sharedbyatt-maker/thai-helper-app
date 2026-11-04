import 'package:flutter/material.dart';
import 'models.dart';

class CalcLine {
  final TextEditingController name, rate, fee, percent;
  bool perLakh;
  ExchangeQuote? original;
  String? error;
  bool editingRate = false;
  final fieldKey = GlobalKey();
  CalcLine({String label = '', ExchangeQuote? quote})
    : perLakh = quote != null,
      name = TextEditingController(text: quote?.label ?? label),
      rate = TextEditingController(
        text: quote == null ? '' : referenceRateText(quote.rateMicros),
      ),
      fee = TextEditingController(
        text: quote == null ? '0' : '${quote.flatFeeMinor / 100}',
      ),
      percent = TextEditingController(
        text: quote == null ? '0' : '${quote.feeBps / 100}',
      ),
      original = quote;
  void dispose() {
    name.dispose();
    rate.dispose();
    fee.dispose();
    percent.dispose();
  }

  ExchangeQuote quote(ExchangeDirection direction, int index) {
    final value = double.tryParse(
      normalizeDigits(rate.text).replaceAll(',', '').trim(),
    );
    final flat = parseMoney(fee.text, allowZero: true);
    final bps = parseMoney(percent.text, allowZero: true);
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        flat == null ||
        bps == null ||
        bps >= 10000) {
      throw FormatException('ဈေး ${index + 1}: ထည့်ထားတဲ့ဈေးကို ပြန်စစ်ပေးပါ');
    }
    final scaled = (perLakh ? 100000 / value : value) * rateScale;
    if (!scaled.isFinite || scaled < 1 || scaled > 1000000000000) {
      throw const FormatException('ထည့်ထားတဲ့ဈေးကို ပြန်စစ်ပေးပါ');
    }
    final now = DateTime.now();
    return original ??
        ExchangeQuote(
          id: 'personal_$index',
          label: name.text.trim().isEmpty
              ? 'ဈေး ${index + 1}'
              : name.text.trim(),
          direction: direction,
          rateMicros: scaled.round(),
          flatFeeMinor: flat,
          feeBps: bps,
          sourceName: 'ကိုယ်ထည့်ထားတဲ့ဈေး',
          observedAt: now,
          validUntil: now.add(const Duration(days: 1)),
        );
  }
}

class Calculation {
  final ExchangeQuote quote;
  final int budget, received;
  const Calculation(this.quote, this.budget, this.received);
}

