import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class PersonalRecord {
  final String id, name, note;
  final ExchangeQuote quote;
  final int budgetMinor, receivedMinor;
  final DateTime savedAt;
  final bool completed;
  const PersonalRecord({
    required this.id,
    required this.name,
    required this.note,
    required this.quote,
    required this.budgetMinor,
    required this.receivedMinor,
    required this.savedAt,
    this.completed = false,
  });
  factory PersonalRecord.fromJson(Map<String, dynamic> j) {
    final budget = j['budget_minor'], received = j['received_minor'];
    if (budget is! int ||
        received is! int ||
        budget <= 0 ||
        received <= 0 ||
        budget > maxMoneyMinor ||
        received > maxMoneyMinor) {
      throw const FormatException('Invalid stored amounts');
    }
    return PersonalRecord(
      id: j['id'] as String,
      name: j['name'] as String,
      note: j['note'] as String? ?? '',
      quote: ExchangeQuote.fromJson(j['quote'] as Map<String, dynamic>),
      budgetMinor: budget,
      receivedMinor: received,
      savedAt: DateTime.parse(j['saved_at'] as String),
      completed: j['completed'] == true,
    );
  }
  PersonalRecord withCompleted(bool value) => PersonalRecord(
    id: id,
    name: name,
    note: note,
    quote: quote,
    budgetMinor: budgetMinor,
    receivedMinor: receivedMinor,
    savedAt: savedAt,
    completed: value,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'quote': quote.toJson(),
    'budget_minor': budgetMinor,
    'received_minor': receivedMinor,
    'saved_at': savedAt.toIso8601String(),
    'completed': completed,
  };
}

class RecordStore {
  static const key = 'exchange_records_v2';
  static const limit = 500;
  Future<List<PersonalRecord>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) return [];
    // Never overwrite a corrupt/unsupported history silently.
    final list = jsonDecode(raw) as List;
    if (list.length > limit) {
      throw const FormatException('Unsupported history size');
    }
    return list
        .map((r) => PersonalRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<PersonalRecord> records) async {
    if (records.length > limit) {
      throw const FormatException(
        'မှတ်တမ်း ၅၀၀ ပြည့်နေပြီ။ အဟောင်းတွေကို ဖိုင်ထုတ်သိမ်းပြီးမှ ရှင်းပေးပါ။',
      );
    }
    final p = await SharedPreferences.getInstance();
    final ok = await p.setString(
      key,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
    if (!ok) throw const FormatException('ဖုန်းထဲ သိမ်းမရပါ။ ပြန်စမ်းပါ။');
  }

  String export(List<PersonalRecord> records) =>
      const JsonEncoder.withIndent('  ').convert({
        'schema_version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
      });
}
