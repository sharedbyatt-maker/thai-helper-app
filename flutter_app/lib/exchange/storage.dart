import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'personal_record.dart';
import 'storage_lock.dart';
import 'restore_storage.dart';

export 'personal_record.dart';

class RecordStore {
  static const key = recordStorageKey;
  static const limit = 500;
  String signature(List<PersonalRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());

  List<PersonalRecord> _decode(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is! List || list.length > limit) {
        throw const FormatException();
      }
      final records = list.map((r) => PersonalRecord.fromJson(r as Map<String, dynamic>)).toList();
      if (records.map((r) => r.id).toSet().length != records.length) {
        throw const FormatException();
      }
      return records;
    } catch (_) {
      throw const FormatException('မှတ်တမ်းတွေ ဖတ်မရသေးဘူး။ မူရင်းစာရင်းကို မပြောင်းထားပါဘူး။');
    }
  }

  Future<List<PersonalRecord>> load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final raw = pendingRestore(p)?[key] ?? p.getString(key);
    if (raw == null) return [];
    // Never overwrite a corrupt/unsupported history silently.
    return _decode(raw);
  }

  Future<void> save(List<PersonalRecord> records, {List<PersonalRecord>? expectedRecords}) =>
      withStorageLock(restoreLock, () async {
    if (records.length > limit) {
      throw const FormatException(
        'မှတ်တမ်း ၅၀၀ ပြည့်နေပြီ။ အဟောင်းတွေကို ဖိုင်ထုတ်သိမ်းပြီးမှ ရှင်းပေးပါ။',
      );
    }
    final checked = _decode(signature(records));
    final p = await SharedPreferences.getInstance();
    await p.reload();
    await finishRestore(p);
    final raw = p.getString(key);
    final current = raw == null ? <PersonalRecord>[] : _decode(raw);
    if (expectedRecords != null && signature(current) != signature(expectedRecords)) {
      throw const FormatException('မှတ်တမ်းတွေ ပြောင်းထားပြီ။ စာရင်းပြန်ဖတ်ပြီးမှ ထပ်လုပ်ပေးပါ။');
    }
    final ok = await p.setString(
      key,
      signature(checked),
    );
    if (!ok) throw const FormatException('ဖုန်းထဲ သိမ်းမရပါ။ ပြန်စမ်းပါ။');
  });

  String export(List<PersonalRecord> records) =>
      const JsonEncoder.withIndent('  ').convert({
        'schema_version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
      });
}

class ImportPreview {
  final List<PersonalRecord> records;
  final int added, skipped;
  const ImportPreview(this.records, this.added, this.skipped);
}

ImportPreview previewRecordImport(String raw, List<PersonalRecord> existing) {
  if (raw.length > 2000000) {
    throw const FormatException(
      'ဖိုင်ကြီးလွန်းတယ်။ မှတ်တမ်းဖိုင်ကို ပြန်စစ်ပေးပါ။',
    );
  }
  final data = jsonDecode(raw);
  if (data is! Map<String, dynamic> ||
      data['schema_version'] != 1 ||
      data['records'] is! List ||
      (data['records'] as List).length > RecordStore.limit) {
    throw const FormatException(
      'ဘတ်ဈေး app က ထုတ်ထားတဲ့ မှတ်တမ်း JSON ဖိုင်ကို ရွေးပေးပါ။',
    );
  }
  final seen = existing.map((r) => r.id).toSet(), next = [...existing];
  var added = 0, skipped = 0;
  for (final item in data['records'] as List) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('မှတ်တမ်းဖိုင်ထဲက အချက်အလက် မပြည့်စုံပါ။');
    }
    final r = PersonalRecord.fromJson(item);
    if (!seen.add(r.id)) {
      skipped++;
      continue;
    }
    next.add(r);
    added++;
  }
  if (next.length > RecordStore.limit) {
    throw const FormatException(
      'ပေါင်းလိုက်ရင် မှတ်တမ်း ၅၀၀ ကျော်သွားမယ်။ အဟောင်းတွေ ဖိုင်ထုတ်သိမ်းပြီးမှ ပြန်သွင်းပေးပါ။',
    );
  }
  next.sort((a, b) => b.savedAt.compareTo(a.savedAt));
  return ImportPreview(next, added, skipped);
}

