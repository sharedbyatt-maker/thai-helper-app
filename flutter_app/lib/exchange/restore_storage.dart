import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const restoreLock = 'bahtzay_financial_storage';
const restoreJournal = 'bahtzay_restore_journal_v1';
const budgetStorageKey = 'bahtzay_budget_v1';
const recordStorageKey = 'exchange_records_v2';

Map<String, String>? pendingRestore(SharedPreferences preferences) {
  final raw = preferences.getString(restoreJournal);
  if (raw == null) return null;
  final data = jsonDecode(raw);
  if (data is! Map<String, dynamic> ||
      data[budgetStorageKey] is! String ||
      data[recordStorageKey] is! String) {
    throw const FormatException('Backup ပြန်ထည့်ထားတဲ့ စာရင်းကို ဖတ်မရပါ။');
  }
  return {
    budgetStorageKey: data[budgetStorageKey] as String,
    recordStorageKey: data[recordStorageKey] as String,
  };
}

// The journal is authoritative until both existing keys are copied. Repeating
// a partial copy after interruption is safe while holding the shared lock.
Future<void> finishRestore(SharedPreferences preferences) async {
  final pending = pendingRestore(preferences);
  if (pending == null) return;
  for (final entry in pending.entries) {
    if (preferences.getString(entry.key) == entry.value) continue;
    if (!await preferences.setString(entry.key, entry.value)) {
      throw const FormatException('Backup စာရင်းကို သိမ်းမရသေးပါ။ ပြန်စမ်းပေးပါ။');
    }
  }
  if (!await preferences.remove(restoreJournal)) {
    throw const FormatException('Backup စာရင်းကို သိမ်းမရသေးပါ။ ပြန်စမ်းပေးပါ။');
  }
}
