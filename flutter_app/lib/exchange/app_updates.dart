import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'rates_repository.dart';

class InstalledApp {
  final String packageId, version;
  final int build;
  final String? installer;
  const InstalledApp(this.packageId, this.version, this.build, {this.installer});
  String get channel => installer == 'com.android.vending' ? 'play' : 'apk';
}

class AvailableAppUpdate {
  final String version, notes, channel;
  final int build;
  final Uri url;
  const AvailableAppUpdate(this.version, this.build, this.notes, this.channel, this.url);
  static AvailableAppUpdate? parse(Map<String, dynamic> manifest, InstalledApp app) {
    final release = manifest['release'];
    if (release is! Map || release['schema_version'] != 1) throw const FormatException('Release format');
    if (release['package_id'] == '' && release['apk'] == null && release['play'] == null) return null;
    if (release['package_id'] != app.packageId) throw const FormatException('App ID mismatch');
    final data = release[app.channel];
    if (data == null) return null;
    if (data is! Map || data['enabled'] != true || data['build'] is! int) throw const FormatException('Release channel');
    final build = data['build'] as int;
    if (build < 1 || build > 2100000000) throw const FormatException('Release build');
    if (build <= app.build) return null;
    final version = data['version'], notes = data['notes'], raw = data['url'];
    if (version is! String || version.length > 50 || notes is! String || notes.length > 2000 || raw is! String || raw.length > 2000) throw const FormatException('Release details');
    if (!RegExp(r'^\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?$').hasMatch(version)) throw const FormatException('Release version');
    final url = Uri.tryParse(raw);
    if (url == null || url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty || url.hasPort || url.hasFragment) throw const FormatException('Update URL');
    if (app.channel == 'play') {
      if (url.host != 'play.google.com' || url.path != '/store/apps/details' || url.queryParameters['id'] != app.packageId) throw const FormatException('Play URL');
    } else if (!url.path.toLowerCase().endsWith('.apk')) {
      throw const FormatException('APK URL');
    }
    return AvailableAppUpdate(version, build, notes, app.channel, url);
  }
}

class AppUpdateCheck {
  final InstalledApp? installed;
  final AvailableAppUpdate? update;
  const AppUpdateCheck(this.installed, this.update);
}

class AppUpdateService {
  final http.Client? client;
  final Future<InstalledApp?> Function()? installedApp;
  const AppUpdateService({this.client, this.installedApp});
  Future<AppUpdateCheck> check() async {
    final app = await (installedApp?.call() ?? nativeApp());
    if (app == null) return const AppUpdateCheck(null, null);
    final base = RatesRepository.apiBase.isEmpty
        ? 'https://bahtzay-rates.muddyhinny2048.chatgpt.site'
        : RatesRepository.apiBase.replaceFirst(RegExp(r'/$'), '');
    final connection = client ?? http.Client();
    try {
      final response = await connection.get(Uri.parse('$base/api/v2/app-release')).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.length > 32768) throw const FormatException('Release unavailable');
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException('Release format');
      return AppUpdateCheck(app, AvailableAppUpdate.parse(data, app));
    } finally {
      if (client == null) connection.close();
    }
  }
  static Future<InstalledApp?> nativeApp() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final info = await PackageInfo.fromPlatform().timeout(const Duration(seconds: 4));
    final build = int.tryParse(info.buildNumber);
    if (build == null || build < 1) throw const FormatException('Installed build');
    return InstalledApp(info.packageName, info.version, build, installer: info.installerStore);
  }
}

class AppUpdateHost extends StatefulWidget {
  final Widget child;
  final AppUpdateService service;
  const AppUpdateHost({super.key, required this.child, this.service = const AppUpdateService()});
  static void open(BuildContext context) {
    final host = context.findAncestorStateOfType<_AppUpdateHostState>();
    showDialog<void>(context: context, builder: (_) => AppUpdateDialog(service: host?.widget.service ?? const AppUpdateService()));
  }
  @override
  State<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends State<AppUpdateHost> with WidgetsBindingObserver {
  bool checking = false;
  DateTime? lastCheck;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }
  Future<void> check() async {
    if (!mounted || checking || lastCheck != null && DateTime.now().difference(lastCheck!) < const Duration(hours: 6)) return;
    checking = true;
    try {
      final result = await widget.service.check();
      lastCheck = DateTime.now();
      if (!mounted || result.update == null || result.installed == null) return;
      final update = result.update!;
      final preferences = await SharedPreferences.getInstance();
      final key = 'app_update_later_${result.installed!.packageId}_${update.channel}_${update.build}';
      final until = preferences.getInt(key) ?? 0;
      if (!mounted || until > DateTime.now().millisecondsSinceEpoch || ModalRoute.of(context)?.isCurrent == false) return;
      await showDialog<void>(context: context, builder: (_) => AppUpdateDialog(initial: result, service: widget.service));
      await preferences.setInt(key, DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch);
    } catch (_) {
      // Offline or unavailable update metadata must never block the calculator.
    } finally {
      checking = false;
    }
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateService service;
  final AppUpdateCheck? initial;
  final Future<bool> Function(Uri)? openUrl;
  const AppUpdateDialog({super.key, this.service = const AppUpdateService(), this.initial, this.openUrl});
  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  AppUpdateCheck? result;
  String? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      result = widget.initial;
      busy = false;
    } else {
      check();
    }
  }
  Future<void> check() async {
    setState(() { busy = true; error = null; });
    try {
      final value = await widget.service.check();
      if (mounted) setState(() => result = value);
    } catch (_) {
      if (mounted) setState(() => error = 'Update စစ်မရသေးဘူး။ လိုင်းရရင် ပြန်စမ်းပေးပါ။');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> download() async {
    final update = result?.update;
    if (update == null || busy) return;
    setState(() { busy = true; error = null; });
    try {
      final opened = await (widget.openUrl?.call(update.url) ?? launchUrl(update.url, mode: LaunchMode.externalApplication));
      if (!opened) throw StateError('Download unavailable');
    } catch (_) {
      if (mounted) setState(() => error = 'Download link ဖွင့်မရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final update = result?.update, installed = result?.installed;
    return AlertDialog(
      title: Text(update == null ? 'App version / Update' : 'Version အသစ်ရပြီ'),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (installed != null) Text('လက်ရှိ v${installed.version} · Build ${installed.build}'),
          if (update != null) ...[
            const SizedBox(height: 12),
            Text('အသစ် v${update.version} · Build ${update.build}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (update.notes.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(update.notes, style: const TextStyle(height: 1.8))),
            Text(update.channel == 'play' ? 'Play Store မှာ Update နှိပ်ပြီး တင်နိုင်တယ်။' : 'APK အသစ်ကို download လုပ်ပြီး Android ရဲ့ Update ခွင့်ပြုချက်ကို အတည်ပြုပေးပါ။ အရင် App ကို မဖျက်ပါနဲ့။', style: const TextStyle(height: 1.8)),
          ] else if (!busy && error == null)
            Text(installed == null ? 'ဒီ Website / Home Screen app အတွက် APK update မလိုပါဘူး။ ပြင်ဆင်ချက်တွေ မြင်ရဖို့ App ကို ပိတ်ပြီး ပြန်ဖွင့်နိုင်တယ်။' : 'ဒီ channel မှာ Update အသစ် မရှိသေးဘူး။', style: const TextStyle(height: 1.8)),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.8)),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(update == null ? 'ပိတ်မယ်' : 'နောက်မှလုပ်မယ်')),
        if (error != null && update == null) TextButton(onPressed: busy ? null : check, child: const Text('ပြန်စစ်မယ်')),
        if (update != null) FilledButton.icon(
          key: const ValueKey('app_update_download'),
          onPressed: busy ? null : download,
          icon: const Icon(Icons.system_update_alt),
          label: Text(update.channel == 'play' ? 'Play Store မှာ Update လုပ်မယ်' : 'APK အသစ်ယူမယ်'),
        ),
      ],
    );
  }
}
