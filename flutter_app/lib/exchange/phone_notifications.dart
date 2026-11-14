import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart' hide Text;
import 'user_language.dart' show Text;
import 'package:url_launcher/url_launcher.dart';
import 'platform_files.dart';
import 'app_links.dart';
import 'rates_repository.dart';

class PhoneNotifications extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String)? action;
  const PhoneNotifications({super.key, this.action});
  @override
  State<PhoneNotifications> createState() => _PhoneNotificationsState();
}

class _PhoneNotificationsState extends State<PhoneNotifications> {
  Map<String, dynamic>? info;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    run('status');
  }

  Future<void> run(String action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await (widget.action?.call(action) ?? phoneNotifications(action, RatesRepository.apiBase));
      if (mounted) {
        setState(() => info = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => info = {'supported': true, 'active': false, 'error': 'Noti ချိတ်ဆက်မှု မရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။'});
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final active = info?['active'] == true;
    final subscribed = active || info?['subscribed'] == true;
    final supported = info?['supported'] == true;
    return Container(
      key: const ValueKey('phone_notifications'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ဖုန်းမှာ အသိပေးမယ်', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('ဈေးနှုန်း ဒါမှမဟုတ် ကြေညာချက်အသစ်တင်ရင် App မဖွင့်ထားလည်း အသိပေးမယ်။ Noti ကိုနှိပ်ရင် App ပြန်ဖွင့်ပေးမယ်။', style: TextStyle(fontSize: 12, height: 1.8)),
          const SizedBox(height: 10),
          if (info == null)
            const LinearProgressIndicator()
          else if (!supported)
            Text(info?['reason'] as String? ?? 'ဒီ browser မှာ noti မသုံးနိုင်သေးဘူး။', key: const ValueKey('phone_push_guide'), style: const TextStyle(fontSize: 12, height: 1.8))
          else ...[
            Text(active ? '✓ ဖုန်း noti ဖွင့်ထားတယ်' : 'ဖုန်း noti မဖွင့်ရသေးဘူး', key: const ValueKey('phone_push_status'), style: TextStyle(color: active ? colors.primary : colors.onSurfaceVariant, height: 1.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('phone_push_toggle'),
                  onPressed: busy ? null : () => run(subscribed ? 'disable' : 'enable'),
                  icon: Icon(active ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, size: 18),
                  label: Text(busy ? 'ချိတ်ဆက်နေတယ်…' : subscribed ? 'Noti ပိတ်မယ်' : 'ဖုန်း noti ဖွင့်မယ်'),
                ),
                if (active && !android)
                  TextButton(
                    key: const ValueKey('phone_push_test'),
                    onPressed: busy ? null : () => run('test'),
                    child: const Text('Noti စမ်းကြည့်မယ်'),
                  ),
              ],
            ),
          ],
          if (info?['error'] != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(info!['error'] as String, style: TextStyle(color: colors.error, fontSize: 12, height: 1.8))),
          if (info?['message'] != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(info!['message'] as String, style: const TextStyle(fontSize: 12, height: 1.8))),
          TextButton(onPressed: () async {
            try { await launchUrl(Uri.parse(publicAppUrl).resolve('privacy.html'), mode: LaunchMode.externalApplication); } catch (_) { /* The disclosure remains available in this panel. */ }
          }, child: const Text('ကိုယ်ရေးအချက်အလက် အသေးစိတ်')),
          const SizedBox(height: 8),
          if (!android) const Text('Noti ပို့ဖို့ browser ရဲ့ ချိတ်ဆက်လိပ်စာကိုပဲ သိမ်းမယ်။ ကိုယ့်ငွေပမာဏနဲ့ မှတ်တမ်းတွေ မပို့ပါဘူး။ ဒီနေရာကနေ အချိန်မရွေး ပိတ်နိုင်တယ်။', style: TextStyle(fontSize: 11, height: 1.8))
          else const Text('ဖုန်း noti ဖွင့်ရင် Firebase က ဒီစက်အတွက် notification စာရင်းသွင်းမှုကို စီမံပေးမယ်။ ကိုယ့်ငွေပမာဏနဲ့ မှတ်တမ်းတွေ မပို့ပါဘူး။', style: TextStyle(fontSize: 11, height: 1.8)),
        ],
      ),
    );
  }
}
