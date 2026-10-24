import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';
import 'user_language.dart' show Text, uiText;

const backupReminderKey = 'bahtzay.backup_reminder.shown.v1';

/// Only called after a successful first save. Preference failure must not turn
/// a successful financial write into a reported failure.
Future<void> remindBackup(BuildContext context, VoidCallback onBackup) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(backupReminderKey) == true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 10),
      content: const Text('စာရင်းကို ဒီဖုန်း / browser ထဲမှာပဲ သိမ်းထားပါတယ်။ Browser data မရှင်းခင် Backup သိမ်းပါ။'),
      action: SnackBarAction(label: uiText(context, 'Backup သိမ်းမယ်'), onPressed: onBackup),
    ));
    await prefs.setBool(backupReminderKey, true);
  } catch (_) {
    // The saved record remains valid even when reminder preferences fail.
  }
}
