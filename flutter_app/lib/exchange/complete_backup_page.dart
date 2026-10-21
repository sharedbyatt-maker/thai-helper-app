import 'dart:convert';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;

import 'user_language.dart' show Text, uiText;

import 'package:flutter/services.dart';

import 'complete_backup.dart';
import 'platform_files.dart';
import 'ux_widgets.dart';

/// Optional combined backup. Existing individual backup screens remain usable.
class CompleteBackupPage extends StatefulWidget {
  final CompleteBackupService? service;
  const CompleteBackupPage({super.key, this.service});

  @override
  State<CompleteBackupPage> createState() => _CompleteBackupPageState();
}

class _CompleteBackupPageState extends State<CompleteBackupPage> {
  late final CompleteBackupService service =
      widget.service ?? CompleteBackupService();
  final text = TextEditingController();
  CompleteBackupPreview? preview;
  String? exported, error;
  bool busy = false, accepted = false;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  String errorMessage(Object e) => e is FormatException
      ? e.message.toString()
      : 'ဖိုင်ကို ဖတ်/သိမ်းမရသေးပါ။ မှတ်တမ်းတွေကို မပြောင်းထားပါဘူး။';

  Future<void> exportAll() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final raw = await service.exportAll();
      if (!mounted) return;
      setState(() => exported = raw);
      final name =
          'bahtzay-all-${DateTime.now().toIso8601String().substring(0, 10)}.json';
      final bytes = Uint8List.fromList(utf8.encode(raw));
      if (kIsWeb) {
        downloadBytes(bytes, name, 'application/json');
      } else {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
          fileNameOverrides: [name],
          sharePositionOrigin: box == null
              ? const Rect.fromLTWH(1, 1, 1, 1)
              : box.localToGlobal(Offset.zero) & box.size,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              kIsWeb
                  ? 'Backup ဖိုင် ထုတ်ပေးပြီးပြီ။ ဖိုင်ကို လုံခြုံတဲ့နေရာမှာ သိမ်းပေးပါ။'
                  : 'Share menu ကနေ Backup ဖိုင်ကို သိမ်းပေးပါ။ အောက်ကစာကိုလည်း ကူးသိမ်းနိုင်ပါတယ်။',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> copyExport() async {
    if (exported == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: exported!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Backup စာ ကူးပြီးပြီ။ ကိုယ်ပိုင်နေရာမှာ သိမ်းထားပေးပါ။',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    }
  }

  Future<void> chooseFile() async {
    if (busy) return;
    try {
      final raw = await pickBackup();
      if (raw == null || !mounted) return;
      text.text = raw;
      await check();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorMessage(e);
          preview = null;
          accepted = false;
        });
      }
    }
  }

  Future<void> check() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      preview = null;
      accepted = false;
    });
    try {
      final next = await service.preview(text.text);
      if (mounted) setState(() => preview = next);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    if (busy || !accepted || preview == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await service.restore(preview!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorMessage(e);
          preview = null;
          accepted = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('မှတ်တမ်းအားလုံး Backup')),
    body: SafeArea(
      child: ContentWidth(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'ငွေလဲမှတ်တမ်းနဲ့ ကိုယ့်ငွေစာရင်းကို ဖိုင်တစ်ခုထဲ သိမ်းနိုင်တယ်။ ဒီဖိုင်ထဲမှာ ကိုယ်ပိုင်ငွေကြေးအချက်အလက်တွေ ပါလို့ သူများကို မပို့ပါနဲ့။',
              style: TextStyle(height: 1.8),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('complete_backup_export'),
              onPressed: busy ? null : exportAll,
              icon: const Icon(Icons.download_outlined),
              label: const Text('မှတ်တမ်းအားလုံး သိမ်းမယ်'),
            ),
            if (exported != null)
              TextButton.icon(
                key: const ValueKey('complete_backup_copy'),
                onPressed: busy ? null : copyExport,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Backup စာ ကူးမယ်'),
              ),
            const Divider(height: 40),
            Text(
              'Backup ပြန်ထည့်မယ်',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'အရင်ဆုံး ဒီဖုန်းထဲက မှတ်တမ်းတွေကို Backup သိမ်းထားပါ။ ပြန်ထည့်တဲ့အခါ ကိုယ့်ငွေစာရင်းကို အစားထိုးမယ်။ ငွေလဲမှတ်တမ်းကတော့ ရှိပြီးသားတွေ မဖျက်ဘဲ အသစ်တွေ ပေါင်းထည့်မယ်။',
              style: TextStyle(height: 1.8),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('complete_backup_pick'),
              onPressed: busy ? null : chooseFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Backup ဖိုင် ရွေးမယ်'),
            ),
            const SizedBox(height: 10),
            if (kIsWeb)
              Card(
                child: ExpansionTile(
                  key: const PageStorageKey('complete_backup_advanced'),
                  title: const Text(
                    'Backup စာ ကူးထည့်မယ် (အပိုရွေးချယ်မှု)',
                    style: TextStyle(fontSize: 13),
                  ),
                  childrenPadding: const EdgeInsets.all(14),
                  children: [
                    TextField(
                      key: const ValueKey('complete_backup_text'),
                      controller: text,
                      enabled: !busy,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: uiText(
                          context,
                          'ဒါမှမဟုတ် Backup စာကို ကူးထည့်ပါ',
                        ),
                      ),
                      onChanged: (_) => setState(() {
                        preview = null;
                        accepted = false;
                        error = null;
                      }),
                    ),
                  ],
                ),
              )
            else
              TextField(
                key: const ValueKey('complete_backup_text'),
                controller: text,
                enabled: !busy,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: uiText(
                    context,
                    'ဒါမှမဟုတ် Backup စာကို ကူးထည့်ပါ',
                  ),
                ),
                onChanged: (_) => setState(() {
                  preview = null;
                  accepted = false;
                  error = null;
                }),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('complete_backup_check'),
              onPressed: busy ? null : check,
              child: const Text('Backup ဖိုင်ကို အရင်စစ်မယ်'),
            ),
            if (preview != null) ...[
              const SizedBox(height: 16),
              Text(
                'ကိုယ့်ငွေစာရင်း ${preview!.previousBudget.entries.length} ခု → ${preview!.incoming.budget.entries.length} ခု\n'
                'ငွေစီမံအစီအစဉ် ${preview!.previousBudget.plans.length} ခု → ${preview!.incoming.budget.plans.length} ခု\n'
                'ငွေလဲမှတ်တမ်း ${preview!.previousRecords.length} ခု → ${preview!.mergedRecords.records.length} ခု\n'
                'အသစ် ${preview!.mergedRecords.added} ခု · ရှိပြီးသား ${preview!.mergedRecords.skipped} ခု',
                style: const TextStyle(
                  height: 1.9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              CheckboxListTile(
                key: const ValueKey('complete_backup_confirm'),
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: busy
                    ? null
                    : (value) => setState(() => accepted = value ?? false),
                title: const Text(
                  'ကိုယ့်ငွေစာရင်းကို အစားထိုးမယ်ဆိုတာ နားလည်ပြီး အတည်ပြုတယ်',
                ),
              ),
              FilledButton(
                key: const ValueKey('complete_backup_restore'),
                onPressed: accepted && !busy ? restore : null,
                child: const Text('အတည်ပြုပြီး ပြန်ထည့်မယ်'),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.8,
                  ),
                ),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}
