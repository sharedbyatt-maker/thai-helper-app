import 'dart:async';

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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = prefs.getString('currency_theme');
    setState(
      () => mode = raw == 'dark'
          ? ThemeMode.dark
          : raw == 'light'
          ? ThemeMode.light
          : ThemeMode.system,
    );
  }

  Future<void> _toggleTheme() async {
    final next = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() => mode = next);
    await (await SharedPreferences.getInstance()).setString(
      'currency_theme',
      next.name,
    );
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
  bool perLakh = false;
  ExchangeQuote? original;
  CalcLine({String label = '', ExchangeQuote? quote})
    : name = TextEditingController(text: quote?.label ?? label),
      rate = TextEditingController(
        text: quote == null ? '' : '${quote.rateMicros / rateScale}',
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
      throw FormatException(
        'ဈေး ${index + 1}: နှုန်းနှင့် နုတ်ငွေကို ပြန်စစ်ပါ',
      );
    }
    final scaled = (perLakh ? 100000 / value : value) * rateScale;
    if (!scaled.isFinite || scaled < 1 || scaled > 1000000000000) {
      throw const FormatException('နှုန်းပမာဏ မမှန်ပါ');
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
          sourceName: 'ကိုယ်တိုင်ထည့်သောဈေး',
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

class _ExchangeHomeState extends State<ExchangeHome> {
  late final repo = widget.repository ?? RatesRepository();
  final store = RecordStore();
  final amount = TextEditingController();
  final lines = <CalcLine>[CalcLine(label: 'ဈေး A')];
  List<Calculation> results = [];
  List<PersonalRecord> records = [];
  LoadedSheet? loaded;
  RateHistory? rateHistory;
  bool trendLoading = true, trendUnavailable = false;
  ExchangeDirection direction = ExchangeDirection.thbMmk;
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
    _refresh();
    _loadRecords();
    timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    repo.close();
    amount.dispose();
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
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
          for (final line in lines) {
            line.dispose();
          }
          lines
            ..clear()
            ..add(CalcLine(label: 'ဈေး A'));
          results = [];
          calcError =
              'ထုတ်ပြထားသောနှုန်း ပြောင်းသွားပါသည်။ နှုန်းအသစ်ကို ပြန်ရွေးပါ။';
        }
        loaded = next;
        loading = false;
        loadError = null;
      });
      try {
        final history = await repo.loadHistory();
        if (!mounted || id != requestId) return;
        setState(() {
          rateHistory = history;
          trendLoading = false;
          trendUnavailable = false;
        });
      } catch (_) {
        if (!mounted || id != requestId) return;
        setState(() {
          trendLoading = false;
          trendUnavailable = rateHistory == null;
          if (rateHistory != null) {
            rateHistory = RateHistory(rateHistory!.points, cached: true);
          }
        });
      }
    } catch (_) {
      if (!mounted || id != requestId) return;
      setState(() {
        loading = false;
        loadError = 'နှုန်းကို ရယူမရပါ။ ကိုယ့်ဈေးဖြင့်တွက်နိုင်ပါသည်။';
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
          () => recordError = 'မှတ်တမ်း ဖတ်မရပါ။ မူလဒေတာကို မပြောင်းထားပါ။',
        );
      }
    }
  }

  void invalidate([CalcLine? line]) {
    setState(() {
      line?.original = null;
      results = [];
      calcError = null;
    });
  }

  void changeDirection(ExchangeDirection next) {
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
        ..add(CalcLine(label: 'ဈေး A'));
    });
  }

  void calculate() {
    FocusScope.of(context).unfocus();
    try {
      final value = parseMoney(amount.text);
      if (value == null) {
        throw const FormatException(
          'ပမာဏသည် 0 ထက်ကြီးပြီး ဒသမ ၂ နေရာအထိသာ ဖြစ်ရပါမည်။',
        );
      }
      final now = DateTime.now();
      final calculated = <Calculation>[];
      for (var i = 0; i < lines.length; i++) {
        final q = lines[i].quote(direction, i);
        if (q.sourceChecked && !q.activeAt(now)) {
          throw const FormatException(
            'ရွေးထားသောနှုန်း သက်တမ်းကုန်ပြီ။ နှုန်းအသစ် ရယူပါ။',
          );
        }
        final budget = targetMode ? q.requiredBudget(value) : value;
        if (budget == null) {
          throw const FormatException(
            'လိုအပ်သောပမာဏသည် တွက်နိုင်သည့်အတိုင်းအတာထက် ကြီးနေပါသည်။',
          );
        }
        final received = q.payout(budget);
        if (received <= 0) {
          throw const FormatException('သီးသန့်နုတ်ငွေထက် ပေးငွေ နည်းနေပါသည်။');
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
    final d = date.toLocal();
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
  Widget directionPicker() => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: ExchangeDirection.values
        .map(
          (d) => ChoiceChip(
            label: Text(d.label),
            selected: d == direction,
            onSelected: (_) => changeDirection(d),
          ),
        )
        .toList(),
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
            tooltip: 'အလင်း / အမှောင်',
            onPressed: widget.onTheme,
            icon: const Icon(Icons.contrast),
          ),
          IconButton(
            tooltip: 'ရှင်းလင်းချက်',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('အသုံးပြုနည်း'),
                content: const SingleChildScrollView(
                  child: Text(
                    'ဘတ်ပေး / ကျပ်ပေး ဈေးကို သီးခြားရွေးပါ။\n\nပေးငွေသည် Fee ပါဝင်သော စုစုပေါင်း budget ဖြစ်သည်။ Fee ကိုနုတ်ပြီး ကျန်ငွေကို လဲတွက်ပါသည်။\n\nAdmin source စစ်ထားခြင်းသည် ငွေလဲသူ သို့မဟုတ် ငွေရောက်ရှိမှုအတွက် အာမခံမဟုတ်ပါ။\n\nကိုယ့်မှတ်တမ်းများကို ဤဖုန်း/browser ထဲတွင်သာ သိမ်းပါသည်။ Browser data ဖျက်လျှင် ပျောက်နိုင်သဖြင့် export လုပ်ထားပါ။',
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
            constraints: const BoxConstraints(maxWidth: 1040),
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
        onDestinationSelected: (value) {
          FocusScope.of(context).unfocus();
          setState(() => tab = value);
        },
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
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const PageStorageKey('daily'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ဒီနေ့ ငွေလဲမလား?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'ယနေ့နှုန်းကို ကြည့်ပြီး လဲမလဲ ဆုံးဖြတ်ပါ။',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
          directionPicker(),
          const SizedBox(height: 18),
          TrendCard(
            quotes: quotes,
            history: rateHistory,
            loading: loading || trendLoading,
            unavailable: trendUnavailable,
            onCalculate: useQuote,
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'နောက်ဆုံး ထုတ်ပြထားသောနှုန်း',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'နှုန်းအသစ် ရယူမယ်',
                onPressed: loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (loading) const LinearProgressIndicator(),
          if (loadError != null) panel(Text(loadError!)),
          if (data != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  data.origin == SheetOrigin.server
                      ? Icons.cloud_done_outlined
                      : Icons.offline_bolt_outlined,
                  size: 16,
                  color: schemeColor(context),
                ),
                Text(
                  data.origin == SheetOrigin.server
                      ? 'နောက်ဆုံးနှုန်း ရယူထားပါပြီ'
                      : data.origin == SheetOrigin.cache
                      ? 'သိမ်းထားသောနှုန်း · offline ဖြစ်နိုင်သည်'
                      : 'နေ့စဉ်နှုန်း စောင့်နေပါတယ်',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (data.sheet.publishedAt != null)
              Text(
                'ထုတ်ပြချိန် ${when(data.sheet.publishedAt!)} · ဖုန်းအချိန်',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (data.sheet.notice.isNotEmpty) panel(Text(data.sheet.notice)),
          ],
          if (!loading && quotes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: FilledButton.icon(
                onPressed: () => setState(() => tab = 1),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('ကိုယ်ရထားတဲ့ဈေးနဲ့ တွက်မယ်'),
              ),
            ),
          ...quotes.map((q) {
            final active = q.activeAt(now);
            return Card(
              child: ExpansionTile(
                key: PageStorageKey('quote_details_${q.direction.key}_${q.id}'),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                title: Text(
                  quotes.length == 1
                      ? 'နှုန်းရင်းမြစ်နှင့် အချိန်အသေးစိတ်'
                      : q.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  quotes.length == 1
                      ? q.sourceName
                      : '၁ ဘတ် = ${rateText(q.rateMicros)} ကျပ်',
                ),
                children: [
                  if (!active)
                    const Text('ဤနှုန်းသည် သက်တမ်းကုန် / မစတင်ရသေးပါ။'),
                  Text('နှုန်းရင်းမြစ်: ${q.sourceName}'),
                  if (q.payoutMethod.isNotEmpty &&
                      q.payoutMethod != 'မဖော်ပြထားပါ')
                    Text('လက်ခံနည်း: ${q.payoutMethod}'),
                  if (q.flatFeeMinor > 0 || q.feeBps > 0)
                    Text(
                      'သီးသန့်နုတ်ငွေ ${money(q.flatFeeMinor)} ${q.direction.from} + ${q.feeBps / 100}% ပါရှိသည်။',
                    ),
                  Text('စစ်ထားချိန် ${when(q.observedAt)}'),
                  Text('ပြသမည့်နောက်ဆုံးအချိန် ${when(q.validUntil)}'),
                  if (q.note.isNotEmpty) Text(q.note),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: active ? () => useQuote(q) : null,
                        child: const Text('ဒီနှုန်းနဲ့ တွက်မယ်'),
                      ),
                      if (q.sourceUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => openSource(q.sourceUrl),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Source ကြည့်မယ်'),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'ငွေလဲမည့်အချိန်တွင် ငွေလဲသူနှင့် နှုန်းကို ပြန်အတည်ပြုပါ။',
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
      Text(
        'ငွေလဲတွက်မယ်',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'ပေးမယ့်ငွေနဲ့ ရထားတဲ့နှုန်းကို ဖြည့်ပါ။ ရမယ့်ငွေကို တွက်ပေးမယ်။',
      ),
      const SizedBox(height: 14),
      directionPicker(),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              targetMode ? '၁။ ဘယ်လောက် ရချင်လဲ?' : '၁။ ဘယ်လောက် ပေးမလဲ?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('amount'),
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => invalidate(),
              decoration: InputDecoration(
                labelText: targetMode
                    ? 'ရချင်သည့်ပမာဏ (${direction.to})'
                    : 'ပေးမယ့်စုစုပေါင်းငွေ (${direction.from})',
                hintText: targetMode || direction == ExchangeDirection.mmkThb
                    ? 'ဥပမာ 100000'
                    : 'ဥပမာ 10000',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children:
                  (targetMode || direction == ExchangeDirection.mmkThb
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
      OutlinedButton.icon(
        onPressed: pasteQuote,
        icon: const Icon(Icons.content_paste),
        label: const Text('Chat စာသားမှ နှုန်းထည့်'),
      ),
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
                ? 'အနည်းဆုံးနှင့် အများဆုံး ကွာခြားချက် ${money(results.last.budget - results.first.budget)} ${direction.from}'
                : 'အများဆုံးနှင့် အနည်းဆုံး ကွာခြားချက် ${money(results.first.received - results.last.received)} ${direction.to}',
          ),
        ),
      for (var i = 0; i < results.length; i++) resultCard(results[i], i),
      const SizedBox(height: 10),
      ExpansionTile(
        key: const PageStorageKey('calculator_options'),
        title: const Text(
          'နှုန်းနှိုင်းယှဉ်ခြင်း / ပြန်တွက်ခြင်း',
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
            label: const Text('နှိုင်းရန် နှုန်းတစ်ခု ထပ်ထည့်'),
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
              Expanded(
                child: Text(
                  lines.length == 1
                      ? '၂။ ရထားတဲ့ ငွေလဲနှုန်း'
                      : 'နှိုင်းမည့်နှုန်း ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (lines.length > 1)
                IconButton(
                  tooltip: 'ဤဈေးဖယ်မယ်',
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
            decoration: const InputDecoration(
              labelText: 'ရထားတဲ့ဈေးရဲ့ ရေးပုံ',
            ),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => invalidate(line),
            decoration: InputDecoration(
              labelText: line.perLakh ? 'ရမည့် ဘတ်ပမာဏ' : 'ရမည့် ကျပ်ပမာဏ',
              hintText: line.perLakh ? 'ဥပမာ 800' : 'ဥပမာ 125',
              helperText: 'ရေးပုံဥပမာသာ ဖြစ်သည်။ ရထားတဲ့နှုန်းအစစ်ကို ဖြည့်ပါ။',
              helperMaxLines: 2,
            ),
          ),
          if (line.original != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'နှုန်းရင်းမြစ်: ${line.original!.sourceName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 10),
          ExpansionTile(
            key: PageStorageKey('deduction_${identityHashCode(line)}'),
            initiallyExpanded: hasDeduction,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              hasDeduction
                  ? 'သီးသန့်နုတ်မည့်ငွေ ပါရှိသည်'
                  : 'သီးသန့်နုတ်ငွေ ရှိမှ ဖြည့်ရန်',
              style: TextStyle(
                fontSize: 13,
                color: hasDeduction
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            children: [
              const Text(
                'နှုန်းအတိုင်း တိုက်ရိုက်လဲလျှင် မဖြည့်ပါနှင့်။ ငွေလဲသူက သီးသန့် ထပ်နုတ်မည်ဟု ပြောထားမှသာ ဖြည့်ပါ။',
              ),
              const SizedBox(height: 12),
              TextField(
                key: ValueKey('deduction_$index'),
                controller: line.fee,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => invalidate(line),
                decoration: InputDecoration(
                  labelText: 'သီးသန့်နုတ်မည့်ငွေ (${direction.from})',
                  hintText: 'ဥပမာ 20',
                  helperText: 'ပေးမယ့်ငွေထဲမှ နုတ်သည်။ မနုတ်လျှင် 0 ထားပါ။',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: ValueKey('deduction_percent_$index'),
                controller: line.percent,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => invalidate(line),
                decoration: const InputDecoration(
                  labelText: 'ရာခိုင်နှုန်းနဲ့ နုတ်မှသာ (%)',
                  hintText: 'ဥပမာ 1',
                  helperText: '၁% နုတ်လျှင် 1။ မနုတ်လျှင် 0 ထားပါ။',
                  helperMaxLines: 2,
                ),
              ),
            ],
          ),
          if (lines.length > 1)
            ExpansionTile(
              key: PageStorageKey('quote_name_${identityHashCode(line)}'),
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'နှုန်းကို အမည်ပေးမှတ်ရန် (ရှိမှ)',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                TextField(
                  controller: line.name,
                  maxLength: 100,
                  onChanged: (_) => invalidate(line),
                  decoration: const InputDecoration(
                    labelText: 'မှတ်ထားမည့်အမည်',
                    hintText: 'ဥပမာ အသိတစ်ယောက်ပေးသောဈေး',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget resultCard(Calculation result, int index) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          results.length > 1
              ? '${index + 1}. ${result.quote.label}'
              : 'တွက်ချက်ရလဒ်',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (results.length > 1 && index == 0)
          const Text('ထည့်ထားသောဈေးများထဲမှ တွက်ချက်ရလဒ် အသာဆုံး'),
        const SizedBox(height: 12),
        Text('ပေးငွေ ${money(result.budget)} ${result.quote.direction.from}'),
        Text(
          'ရငွေ ${money(result.received)} ${result.quote.direction.to}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (result.quote.feeFor(result.budget) > 0)
          Text(
            'သီးသန့်နုတ်ငွေ ${money(result.quote.feeFor(result.budget))} ${result.quote.direction.from} ကို နုတ်ပြီးသောရငွေ ဖြစ်သည်။',
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
      toast('Share မရ၍ စာသား copy လုပ်ထားပါသည်');
    }
  }

  void shareResult(Calculation result) {
    final q = result.quote;
    shareText(
      'ဘတ်ဈေး · ${q.direction.label}\n${q.label}\nပေးငွေ ${money(result.budget)} ${q.direction.from}\nရငွေ ${money(result.received)} ${q.direction.to}\nFee ${money(q.feeFor(result.budget))} ${q.direction.from} ပါဝင်သည်\n၁ ဘတ် = ${q.rateMicros / rateScale} ကျပ်\n${q.sourceChecked ? 'Source: ${q.sourceName} · ${when(q.observedAt)}' : 'ကိုယ်တိုင်ထည့်သောနှုန်းဖြင့် တွက်ထားခြင်း'}\nတွက်ချိန် ${when(DateTime.now())}\nငွေမလဲမီ နှုန်းနှင့် Fee ကို ပြန်အတည်ပြုပါ။',
    );
  }

  Future<void> pasteQuote() async {
    final pasted = TextEditingController();
    ParsedRate? parsed;
    String? error;
    var selected = lines.indexWhere((line) => line.rate.text.trim().isEmpty);
    if (selected < 0) selected = lines.length < 3 ? lines.length : 0;
    final accepted = await showDialog<ParsedRate>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Chat စာသားမှ နှုန်းဖတ်မယ်'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ရွေးထားသည့်ဦးတည်ချက်: ${direction.label}'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('paste_target'),
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'ဘယ်ဈေးထဲ ထည့်မလဲ?',
                    ),
                    items: [
                      for (var i = 0; i < lines.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            'ဈေး ${i + 1} ကို အစားထိုးမယ်',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (lines.length < 3)
                        DropdownMenuItem(
                          value: lines.length,
                          child: const Text('ဈေးအသစ်အဖြစ် ထပ်ထည့်မယ်'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) update(() => selected = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ဥပမာ: “၁ ဘတ် = ၁၂၅ ကျပ်” သို့မဟုတ် “၁ သိန်း = ၈၀၀ ဘတ်”\nဤကိန်းဂဏန်းများသည် ရေးပုံဥပမာသာ ဖြစ်သည်။',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('pasted_quote'),
                    controller: pasted,
                    maxLines: 5,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Copy လုပ်ထားသောစာကို paste လုပ်ပါ',
                    ),
                    onChanged: (_) => update(() {
                      parsed = null;
                      error = null;
                    }),
                  ),
                  OutlinedButton(
                    onPressed: () => update(() {
                      parsed = parseChatRate(pasted.text);
                      error = parsed == null
                          ? 'နှုန်းတစ်ခုတည်း ရှင်းရှင်းမတွေ့ပါ။ နှုန်းစာသားတစ်ကြောင်းသာ ထည့်ပါ သို့မဟုတ် ကိုယ်တိုင်ရိုက်ပါ။'
                          : null;
                    }),
                    child: const Text('နှုန်းဖတ်မယ်'),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  if (parsed != null) ...[
                    const SizedBox(height: 12),
                    Text(parsed!.interpretation),
                    const Text(
                      'ဦးတည်ချက်နှင့် Fee ကို ကိုယ်တိုင်စစ်ပါ။ စာသားမှ Fee ကို အလိုအလျောက် မယူပါ။',
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ပိတ်မယ်'),
            ),
            FilledButton(
              onPressed: parsed == null
                  ? null
                  : () => Navigator.pop(ctx, parsed),
              child: const Text('စစ်ပြီး ဒီနှုန်းသုံးမယ်'),
            ),
          ],
        ),
      ),
    );
    // Dialog fields may still be animating out; dispose after the route transition.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    pasted.dispose();
    if (!mounted || accepted == null) return;
    setState(() {
      if (selected == lines.length) {
        lines.add(CalcLine(label: 'ဈေး ${lines.length + 1}'));
      }
      final line = lines[selected];
      line.original = null;
      line.perLakh = false;
      line.rate.text = '${accepted.rateMicros / rateScale}';
      line.fee.text = '0';
      line.percent.text = '0';
      results = [];
      calcError = null;
    });
    toast('နှုန်းထည့်ပြီးပါပြီ။ ပေးငွေနှင့် Fee ကို စစ်ပြီး တွက်ပါ။');
  }

  Future<void> saveResult(Calculation result) async {
    if (writingRecord || !recordsReady) return;
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('တွက်ထားသောမှတ်တမ်း သိမ်းမယ်'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ဤသည် တွက်ချက်ထားသောမှတ်တမ်း ဖြစ်သည်။ ငွေတကယ်လဲပြီးလျှင် မှတ်တမ်းထဲတွင် ကိုယ်တိုင်အမှန်ခြစ်ပါ။',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 250,
              decoration: const InputDecoration(
                labelText: 'မှတ်ချက် (ရှိလျှင်)',
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
        'မှတ်တမ်း သိမ်းမရပါ။ မှတ်တမ်း ၅၀၀ ပြည့်ခြင်း / storage ကို စစ်ပါ။ မူလမှတ်တမ်းများ မပြောင်းပါ။',
      );
    } finally {
      if (mounted) setState(() => writingRecord = false);
    }
  }

  Widget history() {
    final now = DateTime.now();
    final month = records.where(
      (r) =>
          r.completed &&
          r.savedAt.year == now.year &&
          r.savedAt.month == now.month &&
          r.quote.direction == ExchangeDirection.thbMmk,
    );
    final sent = month.fold<int>(0, (a, r) => a + r.budgetMinor);
    final received = month.fold<int>(0, (a, r) => a + r.receivedMinor);
    return ListView(
      key: const PageStorageKey('records'),
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'ကိုယ့်ငွေလဲမှတ်တမ်း',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'ဤဖုန်း / browser ထဲမှာသာ သိမ်းထားသည်။ ကိုယ်တိုင်ပြီးစီးကြောင်း မှတ်ထားသောစာရင်းသာဖြစ်ပြီး ငွေရောက်ကြောင်း App က အတည်မပြုပါ။',
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
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ယခုလ · ဘတ်ပေး → ကျပ်ယူ · ပြီးစီးကြောင်းမှတ်ထားသော ${month.length} ကြိမ်',
              ),
              Text('စုစုပေါင်းပေးငွေ ${money(sent)} ဘတ်'),
              Text('စုစုပေါင်းရငွေ ${money(received)} ကျပ်'),
              const Text('တွက်မှတ်တမ်းသိမ်းသောလအလိုက် တွက်ထားသည်။'),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: records.isEmpty
                  ? null
                  : () => shareText(store.export(records)),
              icon: const Icon(Icons.ios_share),
              label: const Text('မှတ်တမ်း Export / Share'),
            ),
            TextButton(
              onPressed: records.isEmpty || writingRecord ? null : clearRecords,
              child: const Text('အားလုံးရှင်းမယ်'),
            ),
          ],
        ),
        if (recordsReady && records.isEmpty)
          panel(
            const Text(
              'မှတ်တမ်းမရှိသေးပါ။ ငွေတွက်ပြီး ရလဒ်မှ “မှတ်တမ်းသိမ်း” နှိပ်နိုင်ပါသည်။',
            ),
          ),
        ...records.map(
          (r) => panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: Theme.of(context).textTheme.titleMedium),
                Text('${r.quote.direction.label} · ${when(r.savedAt)}'),
                Text(
                  '${money(r.budgetMinor)} ${r.quote.direction.from} → ${money(r.receivedMinor)} ${r.quote.direction.to}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '၁ ဘတ် = ${rateText(r.quote.rateMicros)} ကျပ် · Fee ${money(r.quote.feeFor(r.budgetMinor))} ${r.quote.direction.from}',
                ),
                if (r.note.isNotEmpty) Text(r.note),
                TextButton.icon(
                  onPressed:
                      r.quote.sourceChecked && !r.quote.activeAt(DateTime.now())
                      ? null
                      : () {
                          useQuote(r.quote);
                          toast(
                            'ယခင်သိမ်းထားသောဈေးဖြစ်သည်။ လက်ရှိဈေးကို ပြန်စစ်ပါ။',
                          );
                        },
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('ဒီဈေးနဲ့ ပြန်တွက်မယ်'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    r.completed
                        ? 'ကိုယ်တိုင်ပြီးစီးကြောင်း မှတ်ထားသည်'
                        : 'တွက်ထားဆဲ',
                  ),
                  value: r.completed,
                  onChanged: writingRecord
                      ? null
                      : (v) => writeRecords(
                          records
                              .map(
                                (x) => x.id == r.id
                                    ? x.withCompleted(v ?? false)
                                    : x,
                              )
                              .toList(),
                        ),
                ),
                TextButton.icon(
                  onPressed: writingRecord ? null : () => deleteRecord(r),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ဤမှတ်တမ်း ဖျက်မယ်'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Future<bool> confirmDelete(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ဖျက်ရန် အတည်ပြုပါ'),
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
          'Export လုပ်ထားပါသလား? ဤဖုန်းထဲက မှတ်တမ်းအားလုံး ဖျက်မလား?',
        ) &&
        mounted) {
      await writeRecords([]);
    }
  }
}
