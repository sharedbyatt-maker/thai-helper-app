import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart' hide Text;
import 'user_language.dart' show LanguageMenu, Text, uiText;

/// One accessible settings surface for every public main tab.
///
/// Changes to language/theme are delegated to the app-wide persisted settings
/// state. Private exchange and budget data never enter this widget.
class AppSettingsSheet extends StatelessWidget {
  final VoidCallback onTheme;
  final VoidCallback onHelp;
  final VoidCallback onNotifications;
  final VoidCallback onUpdate;
  final VoidCallback onBackup;

  const AppSettingsSheet({
    super.key,
    required this.onTheme,
    required this.onHelp,
    required this.onNotifications,
    required this.onUpdate,
    required this.onBackup,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    void open(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.78,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: const ValueKey('app_settings_list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ဆက်တင်',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('settings_close'),
                      onPressed: () => Navigator.pop(context),
                      tooltip: uiText(context, 'ပိတ်မယ်'),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 16),
                const ListTile(
                  key: ValueKey('settings_language'),
                  leading: Icon(Icons.language_rounded),
                  title: Text('ဘာသာစကား'),
                  subtitle: Text('မြန်မာ / English'),
                  trailing: LanguageMenu(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                ListTile(
                  key: const ValueKey('settings_theme'),
                  leading: Icon(dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                  title: const Text('အလင်း / အမှောင်'),
                  subtitle: Text(dark ? 'အမှောင်' : 'အလင်း'),
                  trailing: Switch(
                    value: dark,
                    onChanged: (_) => onTheme(),
                  ),
                  onTap: onTheme,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const Divider(height: 16),
                ListTile(
                  key: const ValueKey('settings_notifications'),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('ဈေးနဲ့ ကြေညာချက် အသိပေးမယ်'),
                  subtitle: Text(!kIsWeb && defaultTargetPlatform == TargetPlatform.android
                      ? 'ဖုန်း noti'
                      : 'ဖုန်း noti / Telegram'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(onNotifications),
                ),
                ListTile(
                  key: const ValueKey('settings_backup'),
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('မှတ်တမ်းအားလုံး Backup'),
                  subtitle: const Text('ကိုယ့်မှတ်တမ်းတွေ သိမ်း / ပြန်ထည့်'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(onBackup),
                ),
                ListTile(
                  key: const ValueKey('settings_help'),
                  leading: const Icon(Icons.help_outline),
                  title: const Text('အသုံးပြုနည်း'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(onHelp),
                ),
                ListTile(
                  key: const ValueKey('settings_update'),
                  leading: const Icon(Icons.system_update_alt_rounded),
                  title: const Text('App version / Update စစ်မယ်'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(onUpdate),
                ),
                const Divider(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'ကိုယ့်ငွေစာရင်းနဲ့ ငွေလဲမှတ်တမ်းတွေကို ဒီဖုန်း / browser ထဲမှာပဲ သိမ်းထားပါတယ်။ Backup ဖိုင်ကို ကိုယ်တိုင် လုံခြုံစွာ သိမ်းထားပါ။',
                    style: TextStyle(fontSize: 12, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
