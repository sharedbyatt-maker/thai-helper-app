import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'rates_repository.dart';
import 'storage.dart';
import 'rate_history.dart';
import 'trend_card.dart';
import 'daily_tools.dart';
import 'platform_files.dart';

class CurrencyApp extends StatefulWidget {
  final RatesRepository? repository;
  const CurrencyApp({super.key, this.repository});
  @override
  State<CurrencyApp> createState() => _CurrencyAppState();
}

class _CurrencyAppState extends State<CurrencyApp> {
  ThemeMode mode = ThemeMode.system;
  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
      );
      if (!mounted) return;
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

  Future<void> _toggleTheme() async {
    final next = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
    ThemeData theme(Brightness b) {
      final dark = b == Brightness.dark;
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xff087f6d),
        brightness: b,
      );
      return ThemeData(
        useMaterial3: true,
        brightness: b,
        colorScheme: scheme,
        scaffoldBackgroundColor: dark
            ? const Color(0xff101c1a)
            : const Color(0xfff3f7f5),
        appBarTheme: AppBarTheme(
          backgroundColor: dark
              ? const Color(0xff101c1a)
              : const Color(0xfff3f7f5),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 7),
          color: dark ? const Color(0xff192a26) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: dark ? const Color(0xff293e37) : const Color(0xffe3ebe6),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          filled: true,
          fillColor: dark ? const Color(0xff14231f) : const Color(0xfff7faf8),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: dark ? const Color(0xff14231f) : Colors.white,
          indicatorColor: scheme.primaryContainer,
          elevation: 0,
        ),
        fontFamily: 'Noto Sans Myanmar',
        fontFamilyFallback: const ['Noto Sans Symbols 2'],
      );
    }

    return MaterialApp(
      title: 'ဘတ်ဈေး',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: mode,
      home: ExchangeHome(onTheme: _toggleTheme, repository: widget.repository),
    );
  }
}

class CalcLine {
  final TextEditingController name, rate, fee, percent;
  bool perLakh;
  ExchangeQuote? original;
  CalcLine({String label = '', ExchangeQuote? quote})
    : perLakh = quote != null,
      name = TextEditingController(text: quote?.label ?? label),
      rate = TextEditingController(
        text: quote == null ? '' : referenceRateText(quote.rateMicros),
      ),
      fee = TextEditingController(
        text: quote == null ? '0' : '${quote.flatFeeMinor / 100}',
      ),
      percent = TextEditingController(
        text: quote == null ? '0' : '${quote.feeBps / 100}',
      ),
      original = quote;
  void dispose() {
    name.dispose();
    rate.dispose();
    fee.dispose();
    percent.dispose();
  }

  ExchangeQuote quote(ExchangeDirection direction, int index) {
    final value = double.tryParse(
      normalizeDigits(rate.text).replaceAll(',', '').trim(),
    );
    final flat = parseMoney(fee.text, allowZero: true);
    final bps = parseMoney(percent.text, allowZero: true);
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        flat == null ||
        bps == null ||
        bps >= 10000) {
      throw FormatException('ဈေး ${index + 1}: ထည့်ထားတဲ့ဈေးကို ပြန်စစ်ပေးပါ');
    }
    final scaled = (perLakh ? 100000 / value : value) * rateScale;
    if (!scaled.isFinite || scaled < 1 || scaled > 1000000000000) {
      throw const FormatException('ထည့်ထားတဲ့ဈေးကို ပြန်စစ်ပေးပါ');
    }
    final now = DateTime.now();
    return original ??
        ExchangeQuote(
          id: 'personal_$index',
          label: name.text.trim().isEmpty
              ? 'ဈေး ${index + 1}'
              : name.text.trim(),
          direction: direction,
          rateMicros: scaled.round(),
          flatFeeMinor: flat,
          feeBps: bps,
          sourceName: 'ကိုယ်ထည့်ထားတဲ့ဈေး',
          observedAt: now,
          validUntil: now.add(const Duration(days: 1)),
        );
  }
}

class Calculation {
  final ExchangeQuote quote;
  final int budget, received;
  const Calculation(this.quote, this.budget, this.received);
}

class ExchangeHome extends StatefulWidget {
  final VoidCallback onTheme;
  final RatesRepository? repository;
  const ExchangeHome({super.key, required this.onTheme, this.repository});
  @override
  State<ExchangeHome> createState() => _ExchangeHomeState();
}

class _ExchangeHomeState extends State<ExchangeHome>
    with WidgetsBindingObserver {
  late final repo = widget.repository ?? RatesRepository();
  final store = RecordStore();
  final amount = TextEditingController();
  final lines = <CalcLine>[CalcLine(label: 'ဈေး A')];
  List<Calculation> results = [];
  List<PersonalRecord> records = [];
  LoadedSheet? loaded;
  DateTime? lastFetched;
  RateHistory? rateHistory;
  bool trendLoading = true, trendUnavailable = false;
  ExchangeDirection direction = ExchangeDirection.thbMmk;
  ExchangeDirection? recordsDirection;
  bool directionChosen = false;
  bool appVisible = true;
  int? historyRevision;
  DateTime? historyFetchedAt;
  bool targetMode = false,
      loading = true,
      recordsReady = false,
      writingRecord = false;
  String? calcError, loadError, recordError;
  int tab = 0, requestId = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _loadRecords();
    restoreDirection();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (appVisible) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    repo.close();
    amount.dispose();
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appVisible = state == AppLifecycleState.resumed;
    if (appVisible) _refresh(silent: true);
  }

  void toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    final id = ++requestId;
    if (!silent && mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final next = await repo.load();
      if (!mounted || id != requestId) return;
      setState(() {
        if (loaded != null &&
            next.origin == SheetOrigin.server &&
            next.sheet.revision != loaded!.sheet.revision &&
            lines.any((line) => line.original?.sourceChecked == true)) {
          var changedQuote = false;
          for (var i = 0; i < lines.length; i++) {
            final original = lines[i].original;
            if (original == null || !original.sourceChecked) continue;
            final replacement = next.sheet.quotes
                .where(
                  (q) =>
                      q.id == original.id &&
                      q.direction == original.direction &&
                      q.activeAt(DateTime.now()),
                )
                .firstOrNull;
            final same =
                replacement != null &&
                replacement.rateMicros == original.rateMicros &&
                replacement.flatFeeMinor == original.flatFeeMinor &&
                replacement.feeBps == original.feeBps &&
                replacement.observedAt == original.observedAt &&
                replacement.validUntil == original.validUntil &&
                replacement.sourceName == original.sourceName;
            if (same) continue;
            final previousLine = lines[i];
            lines[i] = replacement == null
                ? CalcLine(label: previousLine.name.text)
                : CalcLine(quote: replacement);
            previousLine.dispose();
            changedQuote = true;
          }
          if (changedQuote) {
            results = [];
            calcError = 'ဈေးအသစ် ရောက်လာပြီ။ ထည့်ထားတဲ့ပမာဏနဲ့ ပြန်တွက်ပေးပါ။';
          }
        }
        // Opening the app should show a published direction, even when only
        // MMK -> THB exists. Respect an explicit selection after that.
        if (!directionChosen &&
            next.sheet.quotes.isNotEmpty &&
            lines.every((line) => line.rate.text.trim().isEmpty) &&
            amount.text.trim().isEmpty) {
          final active = next.sheet.quotes
              .where((q) => q.activeAt(DateTime.now()))
              .toList();
          final available = active.isNotEmpty ? active : next.sheet.quotes;
          if (!available.any((q) => q.direction == direction)) {
            direction = available.first.direction;
          }
        }
        loaded = next;
        lastFetched = DateTime.now();
        loading = false;
        loadError = null;
      });
      try {
        if (historyRevision == next.sheet.revision &&
            rateHistory != null &&
            historyFetchedAt != null &&
            DateTime.now().difference(historyFetchedAt!) <
                const Duration(minutes: 15)) {
          return;
        }
        final history = await repo.loadHistory();
        if (!mounted || id != requestId) return;
        setState(() {
          rateHistory = history;
          historyRevision = history.cached ? null : next.sheet.revision;
          historyFetchedAt = DateTime.now();
          trendLoading = false;
          trendUnavailable = false;
        });
      } catch (_) {
        if (!mounted || id != requestId) return;
        setState(() {
          trendLoading = false;
          trendUnavailable = rateHistory == null;
          if (rateHistory != null) {
            rateHistory = RateHistory(
              rateHistory!.points,
              observations: rateHistory!.observations,
              cached: true,
            );
          }
        });
      }
    } catch (_) {
      if (!mounted || id != requestId) return;
      setState(() {
        loading = false;
        loadError = 'ဈေးအသစ် ယူမရသေးဘူး။ ကိုယ်ရထားတဲ့ဈေးနဲ့ တွက်လို့ရပါတယ်။';
      });
    }
  }

  Future<void> _loadRecords() async {
    try {
      final saved = await store.load();
      if (mounted) {
        setState(() {
          records = saved;
          recordsReady = true;
          recordError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => recordError =
              'မှတ်တမ်းတွေ ဖတ်မရသေးဘူး။ သိမ်းထားတဲ့စာရင်းကို မပြောင်းထားပါဘူး။',
        );
      }
    }
  }

  void invalidate([CalcLine? line]) {
    setState(() {
      if (line != null) {
        line.original = null;
        line.fee.text = '0';
        line.percent.text = '0';
      }
      results = [];
      calcError = null;
    });
  }

  Future<void> restoreDirection() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('preferred_direction');
      await p.setInt('app_open_count', (p.getInt('app_open_count') ?? 0) + 1);
      if (!mounted || directionChosen || raw == null) return;
      setState(() {
        direction = parseDirection(raw);
        directionChosen = true;
      });
    } catch (_) {}
  }

  Future<void> rememberDirection(ExchangeDirection value) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        'preferred_direction',
        value.key,
      );
    } catch (_) {}
  }

  void changeDirection(ExchangeDirection next) {
    rememberDirection(next);
    directionChosen = true;
    if (next == direction) return;
    setState(() {
      direction = next;
      results = [];
      calcError = null;
      amount.clear();
      for (final line in lines) {
        line.dispose();
      }
      lines
        ..clear()
        ..add(
          CalcLine(quote: dailyQuote(next, onlyActive: true), label: 'ဈေး A'),
        );
    });
  }

  void calculate() {
    FocusScope.of(context).unfocus();
    try {
      final value = parseMoney(amount.text);
      if (value == null) {
        throw const FormatException(
          '0 ထက်ကြီးတဲ့ ပမာဏထည့်ပေးပါ။ ဒသမဆို ၂ နေရာအထိ ရပါတယ်။',
        );
      }
      final now = DateTime.now();
      final calculated = <Calculation>[];
      for (var i = 0; i < lines.length; i++) {
        final q = lines[i].quote(direction, i);
        if (q.sourceChecked && !q.activeAt(now)) {
          throw const FormatException(
            'ဒီဈေးကို ပြန်စစ်ဖို့လိုပြီ။ အပေါ်က refresh ကိုနှိပ်ပြီး ဈေးအသစ်ယူပေးပါ။',
          );
        }
        final budget = targetMode ? q.requiredBudget(value) : value;
        if (budget == null) {
          throw const FormatException(
            'ဒီပမာဏက တွက်ပေးနိုင်တဲ့ အကန့်အသတ်ထက် များနေပါတယ်။',
          );
        }
        final received = q.payout(budget);
        if (received <= 0) {
          throw const FormatException(
            'ပေးမယ့်ငွေက သီးသန့်နုတ်ငွေထက် နည်းနေပါတယ်။',
          );
        }
        calculated.add(Calculation(q, budget, received));
      }
      calculated.sort(
        (a, b) => targetMode
            ? a.budget.compareTo(b.budget)
            : b.received.compareTo(a.received),
      );
      setState(() {
        results = calculated;
        calcError = null;
      });
    } on FormatException catch (e) {
      setState(() {
        calcError = e.message;
        results = [];
      });
    }
  }

  Future<void> openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['https', 'http'].contains(uri.scheme)) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        toast('Link ဖွင့်မရပါ');
      }
    } catch (_) {
      toast('Link ဖွင့်မရပါ');
    }
  }

  String when(DateTime date) {
    final d = date.toUtc().add(const Duration(hours: 7));
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }

  Widget panel(Widget child, {Color? color}) => Card(
    color: color,
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
  Widget pill(String text, {bool warning = false}) => Chip(
    avatar: Icon(warning ? Icons.schedule : Icons.info_outline, size: 16),
    label: Text(text),
  );
  ExchangeQuote? dailyQuote(ExchangeDirection d, {bool onlyActive = false}) {
    final quotes =
        loaded?.sheet.quotes.where((q) => q.direction == d).toList() ?? [];
    quotes.sort((a, b) => b.observedAt.compareTo(a.observedAt));
    return quotes.where((q) => q.activeAt(DateTime.now())).firstOrNull ??
        (onlyActive ? null : quotes.firstOrNull);
  }

  Widget pageHeading(String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 20, top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: schemeColor(context), size: 25),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget stepHeading(String step, String title) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          step,
          style: TextStyle(
            color: schemeColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    ],
  );

  Widget directionPicker({bool showRates = false}) => LayoutBuilder(
    builder: (context, constraints) {
      final scheme = Theme.of(context).colorScheme;
      final compact = MediaQuery.sizeOf(context).width < 600;
      Widget tile(ExchangeDirection d) {
        final q = dailyQuote(d), selected = d == direction;
        final price = q == null
            ? 'မတင်ရသေးပါ'
            : compact
            ? d == ExchangeDirection.thbMmk
                  ? '${referenceRateText(q.rateMicros)} ဘတ်\nကျပ် ၁ သိန်း'
                  : 'ကျပ် ၁ သိန်း\n${referenceRateText(q.rateMicros)} ဘတ်'
            : quoteRateLabel(q).replaceFirst(' = ', ' → ');
        return Semantics(
          key: ValueKey('direction_${d.key}'),
          button: true,
          selected: selected,
          label: '${d.label}။ ${q == null ? 'မတင်ရသေးပါ' : quoteRateLabel(q)}',
          onTap: () => changeDirection(d),
          child: ExcludeSemantics(
            child: Material(
              color: selected
                  ? scheme.primaryContainer.withValues(alpha: .7)
                  : Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => changeDirection(d),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 12 : 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.label,
                        softWrap: true,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        style: TextStyle(
                          fontSize: compact ? 12 : 14,
                          height: 1.5,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        softWrap: true,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        style: TextStyle(
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      if (q != null && !q.activeAt(DateTime.now()))
                        const Text(
                          'ပြန်မစစ်ရသေး',
                          style: TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (showRates) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tile(ExchangeDirection.thbMmk)),
              const SizedBox(width: 10),
              Expanded(child: tile(ExchangeDirection.mmkThb)),
            ],
          ),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ExchangeDirection.values
            .map(
              (d) => ChoiceChip(
                key: ValueKey('direction_${d.key}'),
                label: Text(d.label),
                selected: d == direction,
                onSelected: (_) => changeDirection(d),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
            .toList(),
      );
    },
  );
  void selectTab(int value) {
    if (value == 1 &&
        lines.length == 1 &&
        lines.first.rate.text.trim().isEmpty) {
      final q = dailyQuote(direction, onlyActive: true);
      if (q != null) {
        lines.first.dispose();
        lines[0] = CalcLine(quote: q);
      }
    }
    FocusScope.of(context).unfocus();
    setState(() => tab = value);
  }

  Widget connectionBanner(LoadedSheet data) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(
          data.origin == SheetOrigin.server
              ? Icons.cloud_done_outlined
              : Icons.offline_bolt_outlined,
          size: 17,
          color: schemeColor(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            data.origin == SheetOrigin.server
                ? 'နောက်ဆုံးချိတ်ဆက်ချိန် ${lastFetched == null ? '—' : when(lastFetched!)} · ထိုင်းအချိန်'
                : data.origin == SheetOrigin.cache
                ? 'လိုင်းမရသေးလို့ သိမ်းထားတဲ့ဈေးကို ပြထားပါတယ်'
                : 'ဈေးအသစ် မရသေးပါဘူး',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.currency_exchange_rounded,
                color: scheme.onPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            const Flexible(
              child: Text(
                'ဘတ်ဈေး',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'ဈေးအသစ် ယူမယ်',
            onPressed: loading ? null : _refresh,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'အလင်း / အမှောင်',
            onPressed: widget.onTheme,
            icon: const Icon(Icons.contrast),
          ),
          IconButton(
            tooltip: 'အသုံးပြုနည်း',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('အသုံးပြုနည်း'),
                content: const SingleChildScrollView(
                  child: Text(
                    'ဘတ်ပေးမလား၊ ကျပ်ပေးမလား အရင်ရွေးပါ။ နှစ်ဘက်ဈေးက မတူပါဘူး။\n\nနေ့စဉ်ဈေးမှ လက်ရှိနှုန်းကိုကြည့်ပြီး “ဒီနှုန်းနဲ့ တွက်မယ်” ကိုနှိပ်ပါ။ ပေးမယ့်ငွေထည့်ရုံနဲ့ ရမယ့်ငွေကို တွက်ပေးမယ်။\n\nဒီ app က ငွေလဲနှုန်းအချက်အလက်နဲ့ တွက်ချက်မှုကို ပေးပါတယ်။ ငွေလဲမလုပ်ခင် သင်လဲမယ့်သူရဲ့ နောက်ဆုံးဈေးကို ပြန်မေးပါ။\n\nကိုယ့်မှတ်တမ်းတွေကို ဒီဖုန်းရဲ့ browser ထဲမှာပဲ သိမ်းထားပါတယ်။ Browser data ဖျက်ရင် ပျောက်နိုင်လို့ အရင် ဖိုင်ထုတ်သိမ်းထားပါ။',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('နားလည်ပါပြီ'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tab == 1 ? 660 : 960),
            child: tab == 0
                ? daily()
                : tab == 1
                ? calculator()
                : history(),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        indicatorColor: scheme.primaryContainer,
        onDestinationSelected: selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.currency_exchange),
            label: 'နေ့စဉ်ဈေး',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            label: 'ငွေတွက်',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'မှတ်တမ်း',
          ),
        ],
      ),
    );
  }

  Widget daily() {
    final data = loaded;
    final quotes =
        data?.sheet.quotes.where((q) => q.direction == direction).toList() ??
        [];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const PageStorageKey('daily'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          pageHeading(
            'ဒီနေ့ ဘတ်–ကျပ်ဈေး',
            'ဘတ်ပေးမလား၊ ကျပ်ပေးမလား ရွေးပြီး ဈေးကြည့်လိုက်ပါ။',
            Icons.show_chart_rounded,
          ),
          if (data != null) connectionBanner(data),
          if (loading) const LinearProgressIndicator(),
          if (loadError != null) panel(Text(loadError!)),
          if (data?.sheet.notice.isNotEmpty == true)
            panel(Text(data!.sheet.notice)),
          directionPicker(showRates: true),
          const SizedBox(height: 16),
          TrendCard(
            quotes: quotes,
            history: rateHistory,
            loading: loading || trendLoading,
            unavailable: trendUnavailable,
            onCalculate: useQuote,
          ),
          const SizedBox(height: 14),
          DailyTools(
            quote: dailyQuote(direction),
            history: rateHistory,
            quotes: data?.sheet.quotes ?? [],
            direction: direction,
          ),
          const SizedBox(height: 14),
          if (!loading &&
              quotes.isEmpty &&
              data != null &&
              data.sheet.quotes.isNotEmpty)
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${direction.label} နှုန်း မတင်ရသေးပါ။'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final available
                          in data.sheet.quotes.map((q) => q.direction).toSet())
                        FilledButton.tonal(
                          onPressed: () => changeDirection(available),
                          child: Text('${available.label} နှုန်းကြည့်မယ်'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (!loading && quotes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: FilledButton.icon(
                onPressed: () => selectTab(1),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('ကိုယ်ရထားတဲ့ဈေးနဲ့ တွက်မယ်'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'ငွေမလဲခင် ကိုယ်လဲမယ့်သူဆီမှာ နောက်ဆုံးဈေးကို ပြန်မေးပေးပါ။',
            ),
          ),
          if (data?.origin == SheetOrigin.server)
            TextButton.icon(
              onPressed: () {
                const base = RatesRepository.apiBase;
                openSource(
                  base.isEmpty
                      ? Uri.base.resolve('/admin/index.html').toString()
                      : '$base/admin/index.html',
                );
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin'),
            ),
        ],
      ),
    );
  }

  Color schemeColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  Widget quickAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_outward_rounded, size: 18),
          ],
        ),
      ),
    ),
  );

  void useQuote(ExchangeQuote q) {
    changeDirection(q.direction);
    setState(() {
      for (final line in lines) {
        line.dispose();
      }
      lines
        ..clear()
        ..add(CalcLine(quote: q));
      tab = 1;
      results = [];
      calcError = null;
    });
  }

  void setTargetMode(bool value) {
    setState(() {
      targetMode = value;
      results = [];
      calcError = null;
      amount.clear();
    });
  }

  Widget calculator() => ListView(
    key: const PageStorageKey('calculator'),
    padding: const EdgeInsets.all(14),
    children: [
      pageHeading(
        'ငွေလဲတွက်မယ်',
        'ပေးမယ့်ငွေနဲ့ ဈေးထည့်လိုက်ပါ။ ရမယ့်ငွေကို တွက်ပေးမယ်။',
        Icons.calculate_outlined,
      ),
      directionPicker(),
      const SizedBox(height: 14),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stepHeading(
              '၁',
              targetMode ? 'ဘယ်လောက် ရချင်လဲ?' : 'ဘယ်လောက် ပေးမလဲ?',
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('amount'),
              controller: amount,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => invalidate(),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => calculate(),
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                labelText: targetMode
                    ? 'ရချင်တဲ့ပမာဏ (${direction.to})'
                    : 'ပေးမယ့်စုစုပေါင်းငွေ (${direction.from})',
                hintText: (targetMode ? direction.to : direction.from) == 'ကျပ်'
                    ? 'ဥပမာ 100000'
                    : 'ဥပမာ 10000',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children:
                  ((targetMode ? direction.to : direction.from) == 'ကျပ်'
                          ? [100000, 500000, 1000000]
                          : [1000, 5000, 10000])
                      .map(
                        (n) => ActionChip(
                          label: Text(money(n * 100)),
                          onPressed: () {
                            amount.text = '$n';
                            invalidate();
                          },
                        ),
                      )
                      .toList(),
            ),
            if (targetMode)
              TextButton(
                onPressed: () => setTargetMode(false),
                child: const Text('ပေးမယ့်ငွေနဲ့ ပြန်တွက်မယ်'),
              ),
          ],
        ),
      ),
      for (var i = 0; i < lines.length; i++) lineEditor(lines[i], i),
      FilledButton.icon(
        key: const ValueKey('calculate'),
        onPressed: calculate,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          elevation: 2,
          shadowColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .25),
        ),
        icon: const Icon(Icons.calculate_outlined),
        label: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            targetMode
                ? 'လိုအပ်မယ့်ငွေ တွက်မယ်'
                : lines.length > 1
                ? 'တွက်ပြီး နှိုင်းမယ်'
                : 'ရမယ့်ငွေ တွက်မယ်',
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (calcError != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            calcError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (results.length > 1)
        panel(
          Text(
            targetMode
                ? 'အနည်းဆုံးနဲ့ အများဆုံး ကွာခြားချက် ${money(results.last.budget - results.first.budget)} ${direction.from}'
                : 'အများဆုံးနဲ့ အနည်းဆုံး ကွာခြားချက် ${money(results.first.received - results.last.received)} ${direction.to}',
          ),
        ),
      for (var i = 0; i < results.length; i++) resultCard(results[i], i),
      const SizedBox(height: 10),
      Card(
        child: ExpansionTile(
          key: const PageStorageKey('calculator_options'),
          title: const Text(
            'ဈေးနှိုင်းမယ် / ရချင်တဲ့ငွေနဲ့ တွက်မယ်',
            style: TextStyle(fontSize: 14),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: const EdgeInsets.all(12),
          children: [
            const Text(
              'တခြားလူပေးတဲ့ဈေးနဲ့ နှိုင်းချင်မှ နှုန်းအသစ် ထပ်ထည့်ပါ။ အများဆုံး ၃ ခု နှိုင်းနိုင်ပါတယ်။',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: lines.length < 3
                  ? () => setState(() {
                      lines.add(CalcLine(label: 'ဈေး ${lines.length + 1}'));
                      results = [];
                    })
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('နှိုင်းဖို့ ဈေးတစ်ခု ထပ်ထည့်မယ်'),
            ),
            TextButton(
              onPressed: () => setTargetMode(!targetMode),
              child: Text(
                targetMode
                    ? 'ပေးမယ့်ငွေနဲ့ တွက်မယ်'
                    : 'ရချင်တဲ့ငွေကနေ ပြန်တွက်မယ်',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
    ],
  );

  Widget lineEditor(CalcLine line, int index) {
    final hasDeduction =
        (parseMoney(line.fee.text, allowZero: true) ?? 0) > 0 ||
        (parseMoney(line.percent.text, allowZero: true) ?? 0) > 0;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '၂',
                  style: TextStyle(
                    color: schemeColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  lines.length == 1
                      ? 'ရထားတဲ့ ငွေလဲနှုန်း'
                      : 'နှိုင်းမယ့်ဈေး ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (lines.length > 1)
                IconButton(
                  tooltip: 'ဒီဈေးကို ဖယ်မယ်',
                  onPressed: () => setState(() {
                    lines.removeAt(index).dispose();
                    results = [];
                  }),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<bool>(
            key: ValueKey('${identityHashCode(line)}_${line.perLakh}'),
            initialValue: line.perLakh,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'ဈေးရေးပုံ'),
            items: const [
              DropdownMenuItem(value: false, child: Text('၁ ဘတ်အတွက် ကျပ်')),
              DropdownMenuItem(
                value: true,
                child: Text('ကျပ် ၁ သိန်းအတွက် ဘတ်'),
              ),
            ],
            onChanged: (value) {
              if (value == null || value == line.perLakh) return;
              final old = double.tryParse(
                normalizeDigits(line.rate.text).replaceAll(',', ''),
              );
              if (old != null && old.isFinite && old > 0) {
                line.rate.text = (100000 / old).toStringAsFixed(6);
              }
              line.perLakh = value;
              invalidate(line);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            key: ValueKey('rate_$index'),
            controller: line.rate,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => invalidate(line),
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              labelText: line.perLakh
                  ? 'ကျပ် ၁ သိန်းအတွက် ဘတ်'
                  : '၁ ဘတ်အတွက် ကျပ်',
              hintText: line.perLakh ? 'ဥပမာ 800' : 'ဥပမာ 125',
              helperText: '${direction.label} ဈေးကို ထည့်ပေးပါ။',
              helperMaxLines: 2,
            ),
          ),
          if (hasDeduction)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'ဒီဈေးမှာ ပေးငွေထဲက ${money(parseMoney(line.fee.text, allowZero: true) ?? 0)} ${direction.from} နဲ့ ${line.percent.text}% နုတ်တွက်ထားပါတယ်။',
                key: ValueKey('published_deduction_$index'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (lines.length > 1)
            ExpansionTile(
              key: PageStorageKey('quote_name_${identityHashCode(line)}'),
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'ဒီဈေးကို နာမည်ပေးထားချင်လား?',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                TextField(
                  controller: line.name,
                  maxLength: 100,
                  onChanged: (_) => invalidate(line),
                  decoration: const InputDecoration(
                    labelText: 'မှတ်ထားမယ့်နာမည်',
                    hintText: 'ဥပမာ အသိတစ်ယောက်ပေးတဲ့ဈေး',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget resultCard(Calculation result, int index) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          results.length > 1
              ? '${index + 1}. ${result.quote.label}'
              : 'တွက်ထားတဲ့ရလဒ်',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (results.length > 1 && index == 0)
          Text(
            targetMode
                ? 'ဒီဈေးနဲ့ဆို ပေးရမယ့်ငွေ အနည်းဆုံးပါ'
                : 'ဒီဈေးနဲ့ဆို ရမယ့်ငွေ အများဆုံးပါ',
          ),
        const SizedBox(height: 12),
        Text('ပေးငွေ ${money(result.budget)} ${result.quote.direction.from}'),
        Text(
          'ရငွေ ${money(result.received)} ${result.quote.direction.to}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: schemeColor(context),
            height: 1.7,
          ),
        ),
        if (result.quote.feeFor(result.budget) > 0)
          Text(
            'သီးသန့်နုတ်ငွေ ${money(result.quote.feeFor(result.budget))} ${result.quote.direction.from} ကို နုတ်ပြီးသားပါ။',
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: recordsReady && !writingRecord
                  ? () => saveResult(result)
                  : null,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('မှတ်တမ်းသိမ်း'),
            ),
            TextButton.icon(
              onPressed: () => shareResult(result),
              icon: const Icon(Icons.share_outlined),
              label: const Text('မျှဝေမယ်'),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> shareText(String text) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await Share.share(
        text,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      toast('မျှဝေလို့မရသေးလို့ စာသားကို ကူးပေးထားပါတယ်');
    }
  }

  void shareResult(Calculation result) {
    final q = result.quote;
    shareText(
      'ဘတ်ဈေး · ${q.direction.label}\n${q.label}\nပေးငွေ ${money(result.budget)} ${q.direction.from}\nရငွေ ${money(result.received)} ${q.direction.to}\n${q.feeFor(result.budget) > 0 ? 'သီးသန့်နုတ်ငွေ ${money(q.feeFor(result.budget))} ${q.direction.from}\n' : ''}${quoteRateLabel(q)}\n${q.sourceChecked ? 'ဈေးတင်ချိန် ${when(q.observedAt)}' : 'ကိုယ်ထည့်ထားတဲ့ဈေးနဲ့ တွက်ထားပါတယ်'}\nတွက်ချိန် ${when(DateTime.now())}\nငွေမလဲခင် နောက်ဆုံးဈေးကို ပြန်မေးပါ။',
    );
  }

  Future<void> saveResult(Calculation result) async {
    if (writingRecord || !recordsReady) return;
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('တွက်ထားတာကို သိမ်းမယ်'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'အခုတွက်ထားတာကို သိမ်းပေးမယ်။ တကယ်ငွေလဲပြီးရင် မှတ်တမ်းထဲမှာ အမှန်ခြစ်ထားလို့ရပါတယ်။',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 250,
              decoration: const InputDecoration(
                labelText: 'မှတ်ချက် (ရေးချင်မှ)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('မသိမ်းတော့'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('သိမ်းမယ်'),
          ),
        ],
      ),
    );
    final memo = note.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    note.dispose();
    if (!mounted || confirmed != true) return;
    final now = DateTime.now();
    final record = PersonalRecord(
      id: now.microsecondsSinceEpoch.toString(),
      name: result.quote.label,
      note: memo,
      quote: result.quote,
      budgetMinor: result.budget,
      receivedMinor: result.received,
      savedAt: now,
    );
    await writeRecords([record, ...records]);
  }

  Future<void> writeRecords(List<PersonalRecord> next) async {
    if (writingRecord) return;
    setState(() => writingRecord = true);
    try {
      await store.save(next);
      if (mounted) {
        setState(() => records = next);
        toast('သိမ်းပြီးပါပြီ');
      }
    } catch (_) {
      toast(
        'မှတ်တမ်း သိမ်းမရသေးဘူး။ စာရင်း ၅၀၀ ပြည့်နေလား၊ ဖုန်းမှာ နေရာရှိသေးလား စစ်ပေးပါ။ အရင်စာရင်းတွေကို မပြောင်းထားပါဘူး။',
      );
    } finally {
      if (mounted) setState(() => writingRecord = false);
    }
  }

  Widget history() {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final month = records.where((r) {
      final saved = (r.completedAt ?? r.savedAt).toUtc().add(
        const Duration(hours: 7),
      );
      return r.completed && saved.year == now.year && saved.month == now.month;
    }).toList();
    final visible =
        records
            .where(
              (r) =>
                  recordsDirection == null ||
                  r.quote.direction == recordsDirection,
            )
            .toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final thbCount = month
        .where((r) => r.quote.direction == ExchangeDirection.thbMmk)
        .length;
    final mmkCount = month.length - thbCount;
    return ListView(
      key: const PageStorageKey('records'),
      padding: const EdgeInsets.all(14),
      children: [
        pageHeading(
          'ကိုယ့်ငွေလဲမှတ်တမ်း',
          'တွက်ထားတာနဲ့ လဲပြီးတာကို ဒီမှာ မှတ်ထားလို့ရတယ်။ ဒီဖုန်းရဲ့ browser ထဲမှာပဲ သိမ်းထားတာပါ။',
          Icons.receipt_long_outlined,
        ),
        if (recordError != null)
          panel(
            Column(
              children: [
                Text(recordError!),
                TextButton(
                  onPressed: _loadRecords,
                  child: const Text('ပြန်ဖတ်မယ်'),
                ),
              ],
            ),
          ),
        if (!recordsReady && recordError == null)
          const Center(child: CircularProgressIndicator()),
        if (recordsReady && records.isNotEmpty) ...[
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: const PageStorageKey('monthly_records_summary'),
              leading: Icon(
                Icons.calendar_month_outlined,
                color: colors.primary,
              ),
              title: const Text(
                'ဒီလ ငွေလဲပြီးသမျှ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'ဘတ်ပေး $thbCount ကြိမ် · ကျပ်ပေး $mmkCount ကြိမ်',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final side in ExchangeDirection.values)
                  monthlyRecordSummary(side, month),
                const SizedBox(height: 8),
                const Text(
                  'လဲပြီးတဲ့ရက်အလိုက် ပေါင်းထားပါတယ်။ ရက်မမှတ်ခဲ့တဲ့ အဟောင်းတွေကိုတော့ သိမ်းတဲ့ရက် သုံးထားတယ်။',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final side in <ExchangeDirection?>[
                null,
                ...ExchangeDirection.values,
              ])
                ChoiceChip(
                  key: ValueKey('records_filter_${side?.key ?? 'all'}'),
                  label: Text(side?.label ?? 'အားလုံး'),
                  selected: recordsDirection == side,
                  onSelected: (_) => setState(() => recordsDirection = side),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'မှတ်တမ်း ${visible.length} ခု',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
        if (recordsReady && records.isEmpty)
          OutlinedButton.icon(
            onPressed: writingRecord ? null : importRecords,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('မှတ်တမ်းဖိုင် ပြန်သွင်းမယ်'),
          ),
        if (recordsReady && visible.isEmpty)
          panel(
            Column(
              children: [
                Icon(
                  Icons.bookmark_border_rounded,
                  size: 40,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  records.isEmpty
                      ? 'မှတ်တမ်း မရှိသေးဘူး'
                      : 'ဒီဘက်အတွက် မှတ်တမ်း မရှိသေးဘူး',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'ငွေတွက်ပြီးရင် ရလဒ်အောက်က “မှတ်တမ်းသိမ်း” ကို နှိပ်လိုက်ပါ။',
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  onPressed: () => selectTab(1),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('ငွေတွက်မယ်'),
                ),
              ],
            ),
          ),
        for (final r in visible) personalRecordCard(r),
        if (recordsReady && records.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: exportRecords,
                icon: const Icon(Icons.ios_share),
                label: const Text('မှတ်တမ်းဖိုင် သိမ်းမယ်'),
              ),
              OutlinedButton.icon(
                onPressed: writingRecord ? null : importRecords,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('မှတ်တမ်းဖိုင် ပြန်သွင်းမယ်'),
              ),
              TextButton(
                onPressed: writingRecord ? null : clearRecords,
                child: const Text('အားလုံးရှင်းမယ်'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }

  Widget monthlyRecordSummary(
    ExchangeDirection side,
    List<PersonalRecord> month,
  ) {
    final items = month.where((r) => r.quote.direction == side);
    final sent = items.fold<int>(0, (a, r) => a + r.budgetMinor);
    final received = items.fold<int>(0, (a, r) => a + r.receivedMinor);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('monthly_summary_${side.key}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            side.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text('စုစုပေါင်းပေးငွေ ${money(sent)} ${side.from}'),
          const SizedBox(height: 4),
          Text(
            'စုစုပေါင်းရငွေ ${money(received)} ${side.to}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget personalRecordCard(PersonalRecord r) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('personal_record_${r.id}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        r.quote.direction.label,
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      when(r.savedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${money(r.budgetMinor)} ${r.quote.direction.from} → ${money(r.receivedMinor)} ${r.quote.direction.to}',
                  key: ValueKey('record_amount_${r.id}'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  quoteRateLabel(r.quote),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                if (r.quote.feeFor(r.budgetMinor) > 0)
                  Text(
                    'နုတ်ပြီးသားငွေ ${money(r.quote.feeFor(r.budgetMinor))} ${r.quote.direction.from}',
                  ),
                if (r.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r.note),
                ],
              ],
            ),
          ),
          CheckboxListTile(
            key: ValueKey('record_completed_${r.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              r.completed ? 'ငွေလဲပြီးပြီ' : 'တွက်ထားတာပဲ ရှိသေးတယ်',
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: r.completed
                ? const Text(
                    'ကိုယ်တိုင် မှတ်ထားတာပါ',
                    style: TextStyle(fontSize: 12),
                  )
                : null,
            value: r.completed,
            onChanged: writingRecord
                ? null
                : (v) => writeRecords(
                    records
                        .map(
                          (x) => x.id == r.id ? x.withCompleted(v ?? false) : x,
                        )
                        .toList(),
                  ),
          ),
          if (r.completed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextButton.icon(
                key: ValueKey('record_date_${r.id}'),
                onPressed: writingRecord ? null : () => setCompletedDate(r),
                icon: const Icon(Icons.event_outlined, size: 17),
                label: Text(
                  'လဲပြီးတဲ့ရက် · ${when(r.completedAt ?? r.savedAt).split(' ').first}',
                ),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed:
                      r.quote.sourceChecked && !r.quote.activeAt(DateTime.now())
                      ? null
                      : () {
                          useQuote(r.quote);
                          toast(
                            'ဒါက အရင်သိမ်းထားတဲ့ဈေးပါ။ အခုဈေးနဲ့ တူမတူ ပြန်စစ်ပေးပါ။',
                          );
                        },
                  icon: const Icon(Icons.calculate_outlined, size: 18),
                  label: const Text('ဒီဈေးနဲ့ ပြန်တွက်မယ်'),
                ),
                TextButton.icon(
                  key: ValueKey('record_delete_${r.id}'),
                  onPressed: writingRecord ? null : () => deleteRecord(r),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('ဖျက်မယ်'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void exportRecords() {
    final bytes = Uint8List.fromList(utf8.encode(store.export(records)));
    downloadBytes(
      bytes,
      'bahtzay-records-${DateTime.now().toIso8601String().substring(0, 10)}.json',
      'application/json',
    );
  }

  Future<void> importRecords() async {
    if (writingRecord) return;
    try {
      final raw = await pickBackup();
      if (raw == null || !mounted) return;
      final preview = previewRecordImport(raw, records);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('မှတ်တမ်းဖိုင် ပြန်သွင်းမယ်'),
          content: Text(
            'အသစ်ထည့်မယ့်မှတ်တမ်း ${preview.added} ခု\nထပ်နေတာ ${preview.skipped} ခုကို ကျော်ထားမယ်။\n\nဒီဖုန်းထဲက ရှိပြီးသားတွေကို မဖျက်ပါဘူး။',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('မသွင်းတော့'),
            ),
            FilledButton(
              onPressed: preview.added == 0
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('ပေါင်းထည့်မယ်'),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) {
        await writeRecords(previewRecordImport(raw, records).records);
      }
    } catch (e) {
      if (mounted) {
        toast(
          e is FormatException
              ? e.message
              : 'မှတ်တမ်းဖိုင် ဖတ်မရသေးဘူး။ ဘတ်ဈေး app က ထုတ်ထားတဲ့ဖိုင်ကို ရွေးပေးပါ။',
        );
      }
    }
  }

  Future<void> setCompletedDate(PersonalRecord r) async {
    final now = DateTime.now();
    final current = (r.completedAt ?? r.savedAt).toLocal();
    final chosen = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'တကယ်ငွေလဲပြီးတဲ့ရက်',
    );
    if (chosen != null && mounted) {
      await writeRecords(
        records
            .map((x) => x.id == r.id ? x.withCompleted(true, at: chosen) : x)
            .toList(),
      );
    }
  }

  Future<bool> confirmDelete(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('တကယ်ဖျက်မလား?'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('မဖျက်တော့'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ဖျက်မယ်'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> deleteRecord(PersonalRecord r) async {
    if (await confirmDelete('${r.name} မှတ်တမ်းကို ဖျက်မလား?') && mounted) {
      await writeRecords(records.where((x) => x.id != r.id).toList());
    }
  }

  Future<void> clearRecords() async {
    if (await confirmDelete(
          'ဖိုင်ထုတ်သိမ်းပြီးပြီလား? ဒီဖုန်းထဲက မှတ်တမ်းအားလုံး ဖျက်တော့မလား?',
        ) &&
        mounted) {
      await writeRecords([]);
    }
  }
}
