import 'dart:convert';

import 'budget.dart';
import 'storage.dart';

/// One portable file containing *only* the user's two local data sets.
/// Published rate sheets and admin settings are intentionally excluded.
class CompleteBackup {
  final BudgetData budget;
  final List<PersonalRecord> records;
  const CompleteBackup({required this.budget, required this.records});
}

class CompleteBackupPreview {
  final CompleteBackup incoming;
  final BudgetData previousBudget;
  final List<PersonalRecord> previousRecords;
  final ImportPreview mergedRecords;
  final String previousRecordsSignature;
  const CompleteBackupPreview({
    required this.incoming,
    required this.previousBudget,
    required this.previousRecords,
    required this.mergedRecords,
    required this.previousRecordsSignature,
  });
}

/// An additive alternative to the existing separate backup formats.
/// Existing budget-only and exchange-only imports are deliberately unchanged.
class CompleteBackupService {
  static const maxBytes = 2000000;
  final BudgetStore budgetStore;
  final RecordStore recordStore;
  CompleteBackupService({BudgetStore? budgetStore, RecordStore? recordStore})
      : budgetStore = budgetStore ?? BudgetStore(),
        recordStore = recordStore ?? RecordStore();

  String encode(CompleteBackup backup) => const JsonEncoder.withIndent('  ').convert({
        'kind': 'bahtzay_complete_backup',
        'schema_version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'budget': backup.budget.toJson(),
        'exchange_records': backup.records.map((r) => r.toJson()).toList(),
      });

  Future<String> exportAll() async {
    // Never export an empty replacement when either existing store is corrupt.
    final budget = await budgetStore.load();
    final records = await recordStore.load();
    final output = encode(CompleteBackup(budget: budget, records: records));
    if (utf8.encode(output).length > maxBytes) {
      throw const FormatException('Backup ဖိုင်ကြီးလွန်းနေပါတယ်။ သီးခြား Backup နှစ်ခုအဖြစ် သိမ်းပေးပါ။');
    }
    return output;
  }

  CompleteBackup decode(String raw) {
    if (utf8.encode(raw).length > maxBytes) {
      throw const FormatException('Backup ဖိုင်ကြီးလွန်းနေပါတယ်။');
    }
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value['kind'] != 'bahtzay_complete_backup' ||
          value['schema_version'] != 1 ||
          value['budget'] is! Map<String, dynamic> ||
          value['exchange_records'] is! List) {
        throw const FormatException('မှတ်တမ်းနှစ်မျိုးပါတဲ့ ဘတ်ဈေး Backup ဖိုင်ကို ရွေးပေးပါ။');
      }
      final exported = DateTime.tryParse(value['exported_at'] is String ? value['exported_at'] as String : '');
      if (exported == null) {
        throw const FormatException('Backup ထုတ်ထားတဲ့အချိန် မပြည့်စုံပါ။');
      }
      final budget = budgetStore.decode(jsonEncode(value['budget']));
      final rawRecords = value['exchange_records'] as List;
      if (rawRecords.length > RecordStore.limit) {
        throw const FormatException('ငွေလဲမှတ်တမ်း ၅၀၀ ကျော်နေပါတယ်။');
      }
      final ids = <String>{};
      for (final item in rawRecords) {
        if (item is! Map<String, dynamic> || item['id'] is! String ||
            !ids.add(item['id'] as String)) {
          throw const FormatException('Backup ထဲမှာ ငွေလဲမှတ်တမ်း ထပ်နေတယ်၊ ဒါမှမဟုတ် မပြည့်စုံပါ။');
        }
      }
      final checked = previewRecordImport(
        jsonEncode({'schema_version': 1, 'records': rawRecords}), const [],
      );
      return CompleteBackup(budget: budget, records: checked.records);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Backup ဖိုင်ထဲက အချက်အလက် မမှန်ပါ။ မူရင်းဖိုင်ကို ပြန်စစ်ပေးပါ။');
    }
  }

  Future<CompleteBackupPreview> preview(String raw) async {
    final incoming = decode(raw); // Validate before touching either live store.
    final previousBudget = await budgetStore.load();
    final previousRecords = await recordStore.load();
    final merged = previewRecordImport(
      jsonEncode({
        'schema_version': 1,
        'records': incoming.records.map((r) => r.toJson()).toList(),
      }),
      previousRecords,
    );
    return CompleteBackupPreview(
      incoming: incoming,
      previousBudget: previousBudget,
      previousRecords: previousRecords,
      mergedRecords: merged,
      previousRecordsSignature: _signature(previousRecords),
    );
  }

  String _signature(List<PersonalRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());

  /// Budget is replaced only after explicit UI confirmation; exchange records
  /// are merged by ID. If the budget write fails, undo the additive merge.
  /// Browser storage is not a transactional database, so a separate backup
  /// should still be saved before a restore.
  Future<void> restore(CompleteBackupPreview preview) async {
    final currentBudget = await budgetStore.load();
    final currentRecords = await recordStore.load();
    if (currentBudget.revision != preview.previousBudget.revision ||
        _signature(currentRecords) != preview.previousRecordsSignature) {
      throw const FormatException('ဒီဖုန်းထဲက စာရင်း ပြောင်းထားပြီ။ ဖိုင်ကို ပြန်စစ်ပြီးမှ ပြန်ထည့်ပေးပါ။');
    }
    final historyChanged = preview.mergedRecords.added > 0;
    if (historyChanged) {
      await recordStore.save(preview.mergedRecords.records);
    }
    try {
      await budgetStore.save(
        preview.incoming.budget.copy(revision: currentBudget.revision),
        expectedRevision: currentBudget.revision,
      );
    } catch (_) {
      if (historyChanged) {
        try {
          await recordStore.save(currentRecords);
        } catch (_) {
          throw const FormatException('ငွေစာရင်းသိမ်းမရခဲ့ပါ။ ငွေလဲမှတ်တမ်းကိုလည်း အရင်အတိုင်း ပြန်မထားနိုင်ခဲ့လို့ Backup နဲ့ စစ်ပေးပါ။');
        }
      }
      throw const FormatException('ငွေစာရင်းသိမ်းမရလို့ ပြန်ထည့်ခြင်းကို ရပ်ထားပါတယ်။ အရင်မှတ်တမ်းတွေ ပြန်ထားပြီးပါပြီ။');
    }
  }
}
