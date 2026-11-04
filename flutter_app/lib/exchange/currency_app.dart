import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_updates.dart';
import 'exchange_home.dart';
import 'rates_repository.dart';
import 'user_language.dart' show UserLanguage, UserLanguageScope;

class CurrencyApp extends StatefulWidget {
  final RatesRepository? repository;
  final AppUpdateService updates;
  const CurrencyApp({
    super.key,
    this.repository,
    this.updates = const AppUpdateService(),
  });
  @override
  State<CurrencyApp> createState() => _CurrencyAppState();
}

class _CurrencyAppState extends State<CurrencyApp> {
  ThemeMode mode = ThemeMode.system;
  bool themeChosen = false;
  bool languageChosen = false;
  UserLanguage language = UserLanguage.myanmar;
  @override
  void initState() {
    super.initState();
    _restoreTheme();
    _restoreLanguage();
  }

  Future<void> _restoreTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
      );
      if (!mounted || themeChosen) return;
      final raw = prefs.getString('currency_theme');
      setState(
        () => mode = raw == 'dark'
            ? ThemeMode.dark
            : raw == 'light'
            ? ThemeMode.light
            : ThemeMode.system,
      );
    } catch (_) {
      // The system theme remains usable when browser storage is blocked.
    }
  }

  Future<void> _restoreLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
      );
      final raw = prefs.getString('user_language');
      if (mounted && !languageChosen) {
        setState(
          () => language = raw == 'en'
              ? UserLanguage.english
              : UserLanguage.myanmar,
        );
      }
    } catch (_) {
      // Language still works in memory if private browser storage is blocked.
    }
  }

  Future<void> _changeLanguage(UserLanguage next) async {
    languageChosen = true;
    setState(() => language = next);
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
      );
      await prefs.setString(
        'user_language',
        next == UserLanguage.english ? 'en' : 'my',
      );
    } catch (_) {
      // Keep the selected language available for this session.
    }
  }

  Future<void> _toggleTheme() async {
    themeChosen = true;
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    setState(() => mode = next);
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
      );
      await prefs.setString('currency_theme', next.name);
    } catch (_) {
      // Theme changes still apply for this session without local storage.
    }
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'ဘတ်ဈေး',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('my'), Locale('en')],
      locale: language == UserLanguage.english
          ? const Locale('en')
          : const Locale('my'),
      builder: (context, child) => UserLanguageScope(
        language: language,
        onChanged: _changeLanguage,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppUpdateHost(
        service: widget.updates,
        child: ExchangeHome(
          onTheme: _toggleTheme,
          repository: widget.repository,
        ),
      ),
    );
  }
}

