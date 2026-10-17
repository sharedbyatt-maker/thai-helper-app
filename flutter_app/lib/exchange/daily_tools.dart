import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'rate_history.dart';
import 'rates_repository.dart';
import 'platform_files.dart';
import 'trend_card.dart' show bangkokLabel;

const publicAppUrl = 'https://sharedbyatt-maker.github.io/thai-helper-app/';

RatePoint? priorDailyPoint(
  ExchangeQuote quote,
  RateHistory? history, {
  DateTime? now,
}) {
  final local = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  final today = DateTime.utc(local.year, local.month, local.day);
  final items =
      (history?.points ?? <RatePoint>[])
          .where(
            (p) =>
                p.quoteId == quote.id &&
                p.direction == quote.direction &&
                p.day.isBefore(today),
          )
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items.firstOrNull;
}

String comparisonDay(RatePoint p, {DateTime? now}) {
  final local = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  final today = DateTime.utc(local.year, local.month, local.day);
  return today.difference(p.day).inDays == 1
      ? 'မနေ့က'
      : '${p.day.day}/${p.day.month} ရက်က';
}

String dailyRateBrief(ExchangeQuote quote, RatePoint p) {
  final delta =
      referenceRateValue(quote.rateMicros) - referenceRateValue(p.rateMicros);
  final date = comparisonDay(p);
  if (delta.abs() < .005) return '$dateနဲ့ ဈေးတူတယ်';
  final value = rateValueText(delta.abs(), ExchangeDirection.mmkThb);
  final verb = quote.direction == ExchangeDirection.thbMmk
      ? (delta > 0 ? 'ပိုပေးရတယ်' : 'လျော့ပေးရတယ်')
      : (delta > 0 ? 'ပိုရတယ်' : 'လျော့ရတယ်');
  return '$dateထက် ကျပ် ၁ သိန်းအတွက် $value ဘတ် $verb';
}

class DailyTools extends StatefulWidget {
  final ExchangeQuote? quote;
  final RateHistory? history;
  final List<ExchangeQuote> quotes;
  final ExchangeDirection direction;
  const DailyTools({
    super.key,
    required this.quote,
    required this.history,
    required this.quotes,
    required this.direction,
  });
  @override
  State<DailyTools> createState() => _DailyToolsState();
}

class _DailyToolsState extends State<DailyTools> {
  final amount = TextEditingController();
  Timer? saveTimer;
  bool ready = false;
  int amountMinor = 0, opens = 0;
  String? plannedDay;
  @override
  void initState() {
    super.initState();
    restore();
  }

  @override
  void didUpdateWidget(covariant DailyTools old) {
    super.didUpdateWidget(old);
    if (old.direction != widget.direction) {
      flushAmount(old.direction);
      saveTimer?.cancel();
      amount.clear();
      amountMinor = 0;
      ready = false;
      restore();
    }
  }

  Future<void> restore() async {
    final direction = widget.direction;
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted || widget.direction != direction) return;
      final n =
          p.getInt('watch_amount_${direction.key}') ??
          (direction == ExchangeDirection.thbMmk ? 1000000 : 10000000);
      final count = p.getInt('app_open_count') ?? 0;
      setState(() {
        amountMinor = n;
        amount.text = money(n).replaceAll(',', '');
        plannedDay = p.getString('planned_day_${direction.key}');
        opens = count;
        ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => ready = true);
    }
  }

  @override
  void dispose() {
    flushAmount(widget.direction);
    saveTimer?.cancel();
    amount.dispose();
    super.dispose();
  }

  void flushAmount(ExchangeDirection side) {
    if (saveTimer?.isActive != true || amountMinor <= 0) return;
    final value = amountMinor;
    SharedPreferences.getInstance()
        .then((p) => p.setInt('watch_amount_${side.key}', value))
        .catchError((_) => false);
  }

  void setAmount(String raw) {
    final value = parseMoney(raw);
    setState(() => amountMinor = value ?? 0);
    saveTimer?.cancel();
    if (value != null) {
      final side = widget.direction;
      saveTimer = Timer(const Duration(milliseconds: 350), () async {
        try {
          await (await SharedPreferences.getInstance()).setInt(
            'watch_amount_${side.key}',
            value,
          );
        } catch (_) {}
      });
    }
  }

  Future<void> plan() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(plannedDay ?? '')?.isBefore(now) == false
          ? DateTime.parse(plannedDay!)
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 366)),
      helpText: 'ငွေလဲဖို့ စဉ်းစားထားတဲ့ရက်',
    );
    if (selected == null || !mounted) return;
    final value =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    try {
      await (await SharedPreferences.getInstance()).setString(
        'planned_day_${widget.direction.key}',
        value,
      );
      if (mounted) setState(() => plannedDay = value);
    } catch (_) {
      message('ဖုန်းထဲ သိမ်းမရသေးဘူး။ ပြန်စမ်းပေးပါ။');
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote, colors = Theme.of(context).colorScheme;
    final active = q?.activeAt(DateTime.now()) ?? false;
    final previous = q == null ? null : priorDailyPoint(q, widget.history);
    final hasFees = q != null && (q.flatFeeMinor != 0 || q.feeBps != 0);
    final priorQuote = q == null || previous == null
        ? null
        : ExchangeQuote.fromJson({
            ...q.toJson(),
            'rate_micros': previous.rateMicros,
          });
    final received = active && amountMinor > 0 ? q!.payout(amountMinor) : null;
    final difference = received == null || priorQuote == null || hasFees
        ? null
        : received - priorQuote.payout(amountMinor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'ကိုယ့်ငွေနဲ့ဆို',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('watch_amount'),
                  enabled: ready,
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: setAmount,
                  decoration: InputDecoration(
                    labelText: 'ပေးမယ့်ငွေ (${widget.direction.from})',
                    hintText: widget.direction == ExchangeDirection.thbMmk
                        ? 'ဥပမာ 10000'
                        : 'ဥပမာ 100000',
                    suffixText: widget.direction.from,
                  ),
                ),
                const SizedBox(height: 14),
                if (received != null) ...[
                  Text(
                    'ဒီနေ့ရမယ့်ငွေ',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${money(received)} ${widget.direction.to}',
                    key: const ValueKey('watch_payout'),
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                      height: 1.7,
                    ),
                  ),
                  if (difference != null)
                    Text(
                      difference == 0
                          ? '${comparisonDay(previous!)}နဲ့ ရမယ့်ငွေတူတယ်'
                          : '${comparisonDay(previous!)}ထက် ${money(difference.abs())} ${widget.direction.to} ${difference > 0 ? 'ပိုရမယ်' : 'လျော့ရမယ်'}',
                      key: const ValueKey('watch_difference'),
                      style: const TextStyle(height: 1.8),
                    ),
                ] else
                  Text(
                    q == null
                        ? 'ဒီဘက်ဈေး တင်လာရင် တွက်ပြပေးမယ်။'
                        : !active
                        ? 'ဒီဈေးကို ပြန်မစစ်ရသေးလို့ ရငွေ မတွက်ပြသေးဘူး။'
                        : 'ပေးမယ့်ပမာဏကို ဖြည့်ပေးပါ။',
                  ),
                if (active && previous != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dailyRateBrief(q!, previous),
                      key: const ValueKey('daily_rate_brief'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        height: 1.8,
                      ),
                    ),
                  ),
                if (active && previous == null)
                  const Text(
                    'နှိုင်းဖို့ အရင်ရက်ဈေး မရှိသေးဘူး။',
                    style: TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 6),
                const Text(
                  'ပမာဏကို ဒီဖုန်းထဲမှာပဲ မှတ်ထားပေးမယ်။',
                  style: TextStyle(fontSize: 11),
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          showRateAlerts(context, widget.direction),
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 19,
                      ),
                      label: const Text('ဈေးအသိပေးမယ်'),
                    ),
                    TextButton.icon(
                      onPressed: widget.quotes.isEmpty
                          ? null
                          : () => showRateShare(context, widget.quotes),
                      icon: const Icon(Icons.ios_share, size: 19),
                      label: const Text('ဒီနေ့ဈေး မျှဝေမယ်'),
                    ),
                    TextButton.icon(
                      onPressed: plan,
                      icon: const Icon(Icons.event_outlined, size: 19),
                      label: Text(
                        plannedDay == null
                            ? 'လဲဖို့ရက် မှတ်ထားမယ်'
                            : 'စဉ်းစားထားတဲ့ရက် · $plannedDay',
                      ),
                    ),
                    if (plannedDay != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            await (await SharedPreferences.getInstance())
                                .remove('planned_day_${widget.direction.key}');
                            if (mounted) setState(() => plannedDay = null);
                          } catch (_) {
                            message('ဖျက်မရသေးဘူး။ ပြန်စမ်းပေးပါ။');
                          }
                        },
                        child: const Text('ရက်မှတ်ထားတာ ဖယ်မယ်'),
                      ),
                  ],
                ),
                if (plannedDay != null &&
                    DateTime.parse(plannedDay!)
                            .difference(
                              DateTime(
                                DateTime.now().year,
                                DateTime.now().month,
                                DateTime.now().day,
                              ),
                            )
                            .inDays <=
                        1)
                  const Text(
                    'စဉ်းစားထားတဲ့ရက် နီးလာပြီ။ ငွေမလဲခင် နောက်ဆုံးဈေး ပြန်စစ်ပေးပါ။',
                    style: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        if (opens >= 2)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: OutlinedButton.icon(
              onPressed: () async {
                final installed = await installApp();
                if (!context.mounted || installed) return;
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('ဖုန်းမျက်နှာပြင်ပေါ် ထည့်ထားမယ်'),
                    content: const Text(
                      'iPhone မှာ Safari ရဲ့ Share ကိုနှိပ်ပြီး “Add to Home Screen” ကို ရွေးပါ။\n\nAndroid မှာ browser menu ထဲက “Install app” သို့မဟုတ် “Add to Home screen” ကို ရွေးနိုင်တယ်။\n\nနောက်တစ်ခါ icon ကိုနှိပ်ရုံနဲ့ ဖွင့်လို့ရမယ်။',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('နားလည်ပြီ'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.add_to_home_screen),
              label: const Text('ဖုန်းမျက်နှာပြင်ပေါ် ထည့်ထားမယ်'),
            ),
          ),
      ],
    );
  }
}

Future<void> showRateAlerts(
  BuildContext context,
  ExchangeDirection direction,
) async {
  final target = TextEditingController();
  String? error;
  bool busy = false, news = true;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: const Text('ကိုယ်လိုချင်တဲ့ဈေးကို စောင့်မယ်'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  direction.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ဈေးအသစ်တင်တိုင်း အသိပေးမယ်'),
                  value: news,
                  onChanged: busy ? null : (v) => update(() => news = v),
                ),
                if (!news) ...[
                  Text(
                    direction == ExchangeDirection.thbMmk
                        ? 'ကျပ် ၁ သိန်းရဖို့ ဒီဘတ်ပမာဏ သို့မဟုတ် အောက် ပေးရတဲ့ဈေး ရောက်ရင်'
                        : 'ကျပ် ၁ သိန်းပေးရင် ဒီဘတ်ပမာဏ သို့မဟုတ် အထက် ရတဲ့ဈေး ရောက်ရင်',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('alert_target'),
                    controller: target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'ကျပ် ၁ သိန်းအတွက် ဘတ်',
                      hintText: 'ဥပမာ 730',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Telegram မှာ Start နှိပ်မှ အသိပေးမှု ဖွင့်မယ်။ စောင့်ထားတဲ့ဈေးကိုတော့ ရောက်လာရင် တစ်ခါပဲ ပြောပေးမယ်။ /stop နဲ့ ပြန်ရပ်နိုင်တယ်။',
                  style: TextStyle(fontSize: 12, height: 1.8),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('ပိတ်မယ်'),
          ),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final threshold = parseMoney(target.text);
                    if (!news && (threshold == null || threshold > 10000000)) {
                      update(() => error = 'ဘတ်ပမာဏကို ပြန်စစ်ပေးပါ။');
                      return;
                    }
                    update(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final api = RatesRepository.apiBase.isEmpty
                          ? Uri.base.resolve('/api/v2/alerts')
                          : Uri.parse(
                              '${RatesRepository.apiBase}/api/v2/alerts',
                            );
                      final response = await http
                          .get(api)
                          .timeout(const Duration(seconds: 8));
                      final data =
                          jsonDecode(response.body) as Map<String, dynamic>;
                      if (response.statusCode != 200 ||
                          data['available'] != true ||
                          !RegExp(
                            r'^\w{5,32}$',
                          ).hasMatch(data['username'] as String? ?? '')) {
                        throw const FormatException(
                          'ဈေးအသိပေးမှု ခဏမရသေးဘူး။ နောက်မှ ပြန်စမ်းပေးပါ။',
                        );
                      }
                      final command = news
                          ? 'news_${direction.key}'
                          : 'watch_${direction.key}_$threshold';
                      final opened = await launchUrl(
                        Uri.parse(
                          'https://t.me/${data['username']}?start=$command',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened) {
                        throw const FormatException(
                          'Telegram ဖွင့်မရသေးဘူး။ ပြန်စမ်းပေးပါ။',
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        update(
                          () => error = e is FormatException
                              ? e.message
                              : 'လိုင်းမရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။',
                        );
                      }
                    } finally {
                      if (ctx.mounted) update(() => busy = false);
                    }
                  },
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new, size: 18),
            label: const Text('Telegram မှာ ဆက်ဖွင့်မယ်'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  target.dispose();
}

Future<void> showRateShare(
  BuildContext context,
  List<ExchangeQuote> quotes,
) async {
  final key = GlobalKey();
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: key,
              child: RateShareCard(quotes: quotes),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('ပိတ်မယ်'),
          ),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    update(() => busy = true);
                    try {
                      await WidgetsBinding.instance.endOfFrame;
                      final boundary =
                          key.currentContext!.findRenderObject()!
                              as RenderRepaintBoundary;
                      final image = await boundary.toImage(pixelRatio: 2);
                      final data = await image.toByteData(
                        format: ui.ImageByteFormat.png,
                      );
                      image.dispose();
                      if (data == null) {
                        throw const FormatException('ပုံထုတ်မရပါ');
                      }
                      if (!ctx.mounted) return;
                      final bytes = Uint8List.view(data.buffer);
                      try {
                        final box = ctx.findRenderObject() as RenderBox?;
                        final result = await Share.shareXFiles(
                          [
                            XFile.fromData(
                              bytes,
                              mimeType: 'image/png',
                              name: 'bahtzay-rates.png',
                            ),
                          ],
                          text: publicAppUrl,
                          sharePositionOrigin: box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        );
                        if (result.status == ShareResultStatus.unavailable) {
                          downloadBytes(
                            bytes,
                            'bahtzay-rates.png',
                            'image/png',
                          );
                        }
                      } catch (_) {
                        downloadBytes(bytes, 'bahtzay-rates.png', 'image/png');
                      }
                    } catch (_) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('ပုံမျှဝေမရသေးဘူး။ ပြန်စမ်းပေးပါ။'),
                          ),
                        );
                      }
                    } finally {
                      if (ctx.mounted) update(() => busy = false);
                    }
                  },
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(busy ? 'ပုံပြင်ဆင်နေပါတယ်' : 'ပုံအဖြစ် မျှဝေမယ်'),
          ),
        ],
      ),
    ),
  );
}

class RateShareCard extends StatelessWidget {
  final List<ExchangeQuote> quotes;
  const RateShareCard({super.key, required this.quotes});
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xfff4faf7),
    padding: const EdgeInsets.all(20),
    child: DefaultTextStyle(
      style: const TextStyle(
        fontFamily: 'Noto Sans Myanmar',
        fontFamilyFallback: ['Noto Sans Symbols 2'],
        color: Color(0xff123e35),
        fontSize: 14,
        height: 1.9,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ဘတ်ဈေး',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const Text('ဘတ် ↔ ကျပ် · နောက်ဆုံးစစ်ထားတဲ့ဈေး'),
          const SizedBox(height: 16),
          for (final side in ExchangeDirection.values) ...[
            Text(
              side.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            for (final q
                in quotes.where((q) => q.direction == side).take(1)) ...[
              Text(
                quoteRateLabel(q),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              Text(
                'ဈေးစစ်ချိန် ${bangkokLabel(q.observedAt)} · ထိုင်း',
                style: const TextStyle(fontSize: 11),
              ),
              if (!q.activeAt(DateTime.now()))
                const Text(
                  'အဟောင်းဈေး · ပြန်မစစ်ရသေးပါ',
                  style: TextStyle(
                    color: Color(0xff9c4714),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
            if (!quotes.any((q) => q.direction == side))
              const Text('ဒီဘက်ဈေး မတင်ရသေးပါ'),
            const SizedBox(height: 16),
          ],
          const Text(
            'ငွေမလဲခင် နောက်ဆုံးဈေးကို ပြန်မေးပေးပါ။',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 6),
          const Text(
            publicAppUrl,
            style: TextStyle(fontSize: 10, fontFamily: 'sans-serif'),
          ),
        ],
      ),
    ),
  );
}
