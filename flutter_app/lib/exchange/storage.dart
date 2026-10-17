import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class PersonalRecord {
  final String id, name, note;
  final ExchangeQuote quote;
  final int budgetMinor, receivedMinor;
  final DateTime savedAt;
  final DateTime? completedAt;
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
    this.completedAt,
  });
  factory PersonalRecord.fromJson(Map<String, dynamic> j) {
    final budget = j['budget_minor'], received = j['received_minor'];
    for (final pair in [('id', 100), ('name', 200), ('note', 250)]) {
      final value = j[pair.$1] ?? (pair.$1 == 'note' ? '' : null);
      if (value is! String ||
          value.length > pair.$2 ||
          (pair.$1 == 'id' && value.isEmpty)) {
        throw const FormatException('Invalid record text');
      }
    }
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
      completedAt: j['completed_at'] == null
          ? null
          : DateTime.parse(j['completed_at'] as String),
    );
  }
  PersonalRecord withCompleted(bool value, {DateTime? at}) => PersonalRecord(
    id: id,
    name: name,
    note: note,
    quote: quote,
    budgetMinor: budgetMinor,
    receivedMinor: receivedMinor,
    savedAt: savedAt,
    completed: value,
    completedAt: value ? at ?? DateTime.now() : null,
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
    if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
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

class ImportPreview {
  final List<PersonalRecord> records;
  final int added, skipped;
  const ImportPreview(this.records, this.added, this.skipped);
}

ImportPreview previewRecordImport(String raw, List<PersonalRecord> existing) {
  if (raw.length > 2000000)
    throw const FormatException(
      'ဖိုင်ကြီးလွန်းတယ်။ မှတ်တမ်းဖိုင်ကို ပြန်စစ်ပေးပါ။',
    );
  final data = jsonDecode(raw);
  if (data is! Map<String, dynamic> ||
      data['schema_version'] != 1 ||
      data['records'] is! List ||
      (data['records'] as List).length > RecordStore.limit)
    throw const FormatException(
      'ဘတ်ဈေး app က ထုတ်ထားတဲ့ မှတ်တမ်း JSON ဖိုင်ကို ရွေးပေးပါ။',
    );
  final seen = existing.map((r) => r.id).toSet(), next = [...existing];
  var added = 0, skipped = 0;
  for (final item in data['records'] as List) {
    if (item is! Map<String, dynamic>)
      throw const FormatException('မှတ်တမ်းဖိုင်ထဲက အချက်အလက် မပြည့်စုံပါ။');
    final r = PersonalRecord.fromJson(item);
    if (!seen.add(r.id)) {
      skipped++;
      continue;
    }
    next.add(r);
    added++;
  }
  if (next.length > RecordStore.limit)
    throw const FormatException(
      'ပေါင်းလိုက်ရင် မှတ်တမ်း ၅၀၀ ကျော်သွားမယ်။ အဟောင်းတွေ ဖိုင်ထုတ်သိမ်းပြီးမှ ပြန်သွင်းပေးပါ။',
    );
  next.sort((a, b) => b.savedAt.compareTo(a.savedAt));
  return ImportPreview(next, added, skipped);
}
