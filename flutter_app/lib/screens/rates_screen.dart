import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../rates_service.dart';

const _appUrl = 'https://sharedbyatt-maker.github.io/thai-helper-app/';

const Map<String, Color> _brandColors = {
  'truemoney': Color(0xFFE31837),
  'western_union': Color(0xFFB8860B),
  'moneygram': Color(0xFFC8102E),
  'hundi': Color(0xFF757575),
};

const Map<String, String> _brandEmoji = {
  'truemoney': '🔴',
  'western_union': '🟡',
  'moneygram': '🔴',
  'hundi': '⚪',
};

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtDouble(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  return '${_fmt(int.parse(parts[0]))}.${parts[1]}';
}

// ---------------- Sparkline ----------------

class Sparkline extends StatelessWidget {
  final List<double> values;
  const Sparkline({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values),
      size: const Size(double.infinity, 64),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  _SparklinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height -
          8 -
          ((values[i] - minV) / span) * (size.height - 16);
      pts.add(Offset(x, y));
    }
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, linePaint);
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.35),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(
              Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawCircle(
        pts.last, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values;
}

// ---------------- Screen ----------------

class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  final _amountCtrl = TextEditingController(text: '10000');
  late Future<RateData> _future;
  bool _reverse = false; // false: THB->MMK, true: MMK->THB

  @override
  void initState() {
    super.initState();
    _future = RatesService().load();
    _loadPrefs();
  }

  /// Remember last amount + mode (like Better_Remit's pre-population).
  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final amt = p.getString('amount');
    final rev = p.getBool('reverse') ?? false;
    if (amt != null && amt.isNotEmpty) {
      _amountCtrl.text = amt;
    }
    if (rev != _reverse) _reverse = rev;
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('amount', _amountCtrl.text);
    await p.setBool('reverse', _reverse);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ??
      10000;

  void _setMode(bool reverse) {
    setState(() {
      _reverse = reverse;
      _amountCtrl.text = reverse ? '500000' : '10000';
    });
    _savePrefs();
  }

  void _share(RateData data) {
    final buf = StringBuffer()
      ..writeln(
          '💸 ဒီနေ့ ဘတ်ဈေး (${data.updatedAt.substring(0, 10)})');
    if (!_reverse) {
      final quotes =
          RatesService().compare(data, _amount);
      if (quotes.isEmpty) return;
      final medals = ['🥇', '🥈', '🥉', '4️⃣'];
      buf.writeln('${_fmt(_amount.toInt())} ဘတ် လွှဲရင်:');
      buf.writeln();
      for (var i = 0;
          i < quotes.length && i < medals.length;
          i++) {
        final q = quotes[i];
        buf.writeln(
            '${medals[i]} ${q.channel.nameMy} → ${_fmt(q.receivedMmk)} ကျပ်');
      }
    } else {
      final quotes =
          RatesService().compareReverse(data, _amount);
      if (quotes.isEmpty) return;
      buf.writeln(
          '${_fmt(_amount.toInt())} ကျပ် ရောက်ဖို့:');
      buf.writeln();
      final medals = ['🥇', '🥈', '🥉', '4️⃣'];
      for (var i = 0;
          i < quotes.length && i < medals.length;
          i++) {
        final q = quotes[i];
        buf.writeln(
            '${medals[i]} ${q.channel.nameMy} → ${_fmt(q.thbNeeded.toInt())} ဘတ်');
      }
    }
    buf
      ..writeln()
      ..writeln('📲 $_appUrl');
    Share.share(buf.toString());
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ℹ️ ဘယ်လိုတွက်လဲ'),
        content: const SingleChildScrollView(
          child: Text(
            '• Mid-market နှုန်း = ဘဏ်တွေကြား အရောင်းအဝယ်နှုန်း (အမှန်)\n\n'
            '• Channel နှုန်း = mid-market − margin။ Margin က ခန့်မှန်းခြေ — '
            'နေ့တိုင်း အနည်းငယ် ရွေ့တယ်။\n\n'
            '• ⚠️ မစစ်ရသေး = ဒီနှုန်း အတည်မပြုရသေး။ လွှဲခါနီး counter/app မှာ အတည်ပြုပါ။\n\n'
            '• Fee = channel က ကောက်တဲ့ ဝန်ဆောင်ခ။ ပမာဏအလိုက် ကွာတယ်။\n\n'
            '• Hundi = တရားဝင် channel မဟုတ် — လိမ်လည်မှု သတိထား။\n\n'
            'ဒီ app က သတင်းအချက်အလက်သာ ပေးတယ်။ ငွေလွှဲခြင်း မလုပ်ဘူး။',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ပိတ်မယ်'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💸 ဘတ်ဈေး'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'ရှင်းလင်းချက်',
            onPressed: _showInfo,
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeMode,
            builder: (_, mode, __) => IconButton(
              icon: Icon(mode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode),
              tooltip: 'အလင်း/အမှောင်',
              onPressed: () {
                themeMode.value =
                    mode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
              },
            ),
          ),
          FutureBuilder<RateData>(
            future: _future,
            builder: (context, snap) => IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'မျှဝေမယ်',
              onPressed:
                  snap.hasData ? () => _share(snap.data!) : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                setState(() => _future = RatesService().load()),
          ),
        ],
      ),
      body: FutureBuilder<RateData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
              child: snap.hasError
                  ? const Text('ဒေတာ ရယူမရဘူး — ပြန်စမ်းပါ')
                  : const CircularProgressIndicator(),
            );
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _future = RatesService().load()),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _marketHeader(data),
                _staleBanner(data),
                const SizedBox(height: 10),
                _timingHint(data),
                const SizedBox(height: 10),
                _modeToggle(),
                const SizedBox(height: 10),
                _amountCard(),
                const SizedBox(height: 10),
                if (!_reverse)
                  ..._forwardQuotes(data)
                else
                  ..._reverseQuotes(data),
                const SizedBox(height: 8),
                _footer(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _marketHeader(RateData data) {
    final change = data.change7dPct;
    final up = (change ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ဒီနေ့ mid-market နှုန်း',
              style:
                  TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '1 ဘတ် = ${_fmtDouble(data.midMarketRate)} ကျပ်',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${up ? '▲' : '▼'} ${change.abs().toStringAsFixed(2)}% / 7ရက်',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (data.history.length >= 2)
            Sparkline(
                values:
                    data.history.map((h) => h.mid).toList()),
          if (data.high7d != null && data.low7d != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '7 ရက်: အမြင့် ${_fmtDouble(data.high7d!)} • အနိမ့် ${_fmtDouble(data.low7d!)}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  /// Warn when the data snapshot is older than 48h (stale-data rule).
  Widget _staleBanner(RateData data) {
    try {
      final updated = DateTime.parse(data.updatedAt);
      final age = DateTime.now().difference(updated);
      if (age.inHours >= 48) {
        final days = age.inHours ~/ 24;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    Colors.red.withValues(alpha: 0.35)),
          ),
          child: Text(
            '⚠️ ဒေတာ $days ရက် ကြာပြီ — လွှဲခါနီး နှုန်း အတည်ပြုပါ',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700),
          ),
        );
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }

  Widget _timingHint(RateData data) {
    if (data.history.length < 5 ||
        data.high7d == null ||
        data.low7d == null) {
      return const SizedBox.shrink();
    }
    final span = data.high7d! - data.low7d!;
    if (span == 0) return const SizedBox.shrink();
    final pos =
        (data.midMarketRate - data.low7d!) / span;
    late String text;
    late Color color;
    if (pos >= 0.7) {
      text = '📈 7-ရက် အမြင့်နားမှာ — လွှဲဖို့ အချိန်ကောင်း';
      color = Colors.green;
    } else if (pos <= 0.3) {
      text = '📉 7-ရက် အနိမ့်နားမှာ — မလိုအပ်ရင် ခဏစောင့်ကြည့်';
      color = Colors.orange;
    } else {
      text = '➡️ 7-ရက် အလယ်အလတ် — ပုံမှန်အတိုင်း လွှဲလို့ရ';
      color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  Widget _modeToggle() {
    return Center(
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
              value: false,
              label: Text('လွှဲမယ့်ပမာဏ'),
              icon: Icon(Icons.arrow_upward, size: 16)),
          ButtonSegment(
              value: true,
              label: Text('လိုချင်တဲ့ပမာဏ'),
              icon: Icon(Icons.arrow_downward, size: 16)),
        ],
        selected: {_reverse},
        onSelectionChanged: (s) => _setMode(s.first),
      ),
    );
  }

  Widget _amountCard() {
    final chips = _reverse
        ? [100000, 300000, 500000, 1000000]
        : [5000, 10000, 20000, 50000];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                _reverse
                    ? 'အိမ်ကို ရောက်စေချင်တဲ့ ပမာဏ (ကျပ်)'
                    : 'လွှဲမယ့် ပမာဏ (ဘတ်)',
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly
                    ],
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixText:
                          _reverse ? 'ကျပ် ' : '฿ ',
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _savePrefs();
                    setState(() {});
                  },
                  child: const Text('တွက်'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: chips
                  .map((c) => ChoiceChip(
                        label: Text(_fmt(c)),
                        selected: _amount.toInt() == c,
                        onSelected: (_) {
                          _amountCtrl.text = c.toString();
                          _savePrefs();
                          setState(() {});
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _forwardQuotes(RateData data) {
    final quotes = RatesService().compare(data, _amount);
    if (quotes.isEmpty) {
      return const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'ဒီပမာဏအတွက် channel မရှိဘူး — ပမာဏ ချိန်ကြည့်'),
          ),
        )
      ];
    }
    final widgets = <Widget>[];
    final save =
        quotes.first.receivedMmk - quotes.last.receivedMmk;
    if (save > 0) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Text(
            '💰 အကောင်းဆုံးရွေးရင် ${_fmt(save)} ကျပ် ပိုရမယ်',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    widgets.addAll(quotes.asMap().entries.map(
          (e) => _forwardCard(e.value, e.key, quotes),
        ));
    return widgets;
  }

  List<Widget> _reverseQuotes(RateData data) {
    final quotes =
        RatesService().compareReverse(data, _amount);
    if (quotes.isEmpty) {
      return const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'ဒီပမာဏအတွက် channel မရှိဘူး — ပမာဏ ချိန်ကြည့်'),
          ),
        )
      ];
    }
    final widgets = <Widget>[];
    final save =
        quotes.last.thbNeeded - quotes.first.thbNeeded;
    if (save > 0) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Text(
            '💰 အကောင်းဆုံးရွေးရင် ${_fmt(save.toInt())} ဘတ် သက်သာမယ်',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    widgets.addAll(quotes.asMap().entries.map(
          (e) => _reverseCard(e.value, e.key, quotes),
        ));
    return widgets;
  }

  Widget _header(RateChannel ch, int rank) {
    final best = rank == 0;
    final brand = _brandColors[ch.id] ?? Colors.teal;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor:
              brand.withValues(alpha: 0.15),
          child: Text(
            _brandEmoji[ch.id] ?? '💱',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ch.nameMy,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(ch.name,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Text('#${rank + 1}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500)),
        if (best)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: brand,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('အကောင်းဆုံး',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _cardShell(
      {required RateChannel ch,
      required int rank,
      required Widget highlight,
      required List<Widget> details,
      String? bestNote}) {
    final best = rank == 0;
    final brand = _brandColors[ch.id] ?? Colors.teal;
    return Card(
      elevation: best ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: best
            ? BorderSide(color: brand, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(ch, rank),
            if (bestNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(bestNote,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700)),
              ),
            const SizedBox(height: 10),
            highlight,
            const SizedBox(height: 8),
            ...details,
            if (!ch.verified)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                    '⚠️ နှုန်းမစစ်ရသေး — လွှဲခါနီး အတည်ပြုပါ',
                    style: TextStyle(
                        fontSize: 11, color: Colors.orange)),
              ),
            if (ch.notesMy.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ch.notesMy,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ),
            if (ch.referralUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new,
                      size: 16),
                  label:
                      Text('${ch.name} ကနေ လွှဲမယ်'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                  ),
                  onPressed: () async {
                    RatesService().trackClick(ch.id);
                    final uri =
                        Uri.parse(ch.referralUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode
                              .externalApplication);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _highlightBox(
      {required String label,
      required String value,
      required bool best,
      required String channelId}) {
    final brand = _brandColors[channelId] ?? Colors.teal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: best
            ? brand.withValues(alpha: 0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: best
                    ? brand
                    : Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _forwardCard(
      RateQuote q, int rank, List<RateQuote> all) {
    final ch = q.channel;
    String? bestNote;
    if (rank == 0 && all.length > 1) {
      final delta = q.receivedMmk - all[1].receivedMmk;
      if (delta > 0) {
        bestNote =
            '🥇 နံပါတ် ၂ (${all[1].channel.nameMy}) ထက် ${_fmt(delta)} ကျပ် ပိုရ';
      }
    }
    final effective =
        _amount > 0 ? q.receivedMmk / _amount : 0.0;
    return _cardShell(
      ch: ch,
      rank: rank,
      bestNote: bestNote,
      highlight: _highlightBox(
        label: 'လက်ခံရမယ်',
        value: '${_fmt(q.receivedMmk)} ကျပ်',
        best: rank == 0,
        channelId: ch.id,
      ),
      details: [
        _detailRow(
            'Fee', '${_fmt(q.feeThb.toInt())} ဘတ်'),
        _detailRow('နှုန်း',
            '1 ฿ = ${_fmtDouble(ch.rateThbMmk)} ကျပ်'),
        _detailRow('အမှန်တကယ်နှုန်း',
            '1 ฿ = ${_fmtDouble(effective)} ကျပ်'),
        _detailRow('⏱ ကြာချိန်', ch.transferTimeMy),
        _detailRow('💰 ထုတ်ယူရန်', ch.payoutMy),
      ],
    );
  }

  Widget _reverseCard(
      ReverseQuote q, int rank, List<ReverseQuote> all) {
    final ch = q.channel;
    String? bestNote;
    if (rank == 0 && all.length > 1) {
      final delta = all[1].thbNeeded - q.thbNeeded;
      if (delta > 0) {
        bestNote =
            '🥇 နံပါတ် ၂ (${all[1].channel.nameMy}) ထက် ${_fmt(delta.toInt())} ဘတ် သက်သာ';
      }
    }
    final effective =
        q.thbNeeded > 0 ? _amount / q.thbNeeded : 0.0;
    return _cardShell(
      ch: ch,
      rank: rank,
      bestNote: bestNote,
      highlight: _highlightBox(
        label: 'လွှဲရမယ့် ဘတ်',
        value: '${_fmt(q.thbNeeded.toInt())} ဘတ်',
        best: rank == 0,
        channelId: ch.id,
      ),
      details: [
        _detailRow(
            'Fee', '≈ ${_fmt(q.feeThb.toInt())} ဘတ် ပါ'),
        _detailRow('နှုန်း',
            '1 ฿ = ${_fmtDouble(ch.rateThbMmk)} ကျပ်'),
        _detailRow('အမှန်တကယ်နှုန်း',
            '1 ฿ = ${_fmtDouble(effective)} ကျပ်'),
        _detailRow('⏱ ကြာချိန်', ch.transferTimeMy),
        _detailRow('💰 ထုတ်ယူရန်', ch.payoutMy),
      ],
    );
  }

  Widget _footer(RateData data) {
    final live = RatesService().usingLiveApi;
    final updated = data.updatedAt.length >= 16
        ? data.updatedAt.substring(0, 16).replaceAll('T', ' ')
        : data.updatedAt;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                live ? Icons.cloud_done : Icons.cloud_off,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                live
                    ? 'Live data • update: $updated'
                    : 'Offline snapshot • update: $updated',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            data.disclaimerMy,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            '🔗 တချို့ link တွေက referral ဖြစ်နိုင်တယ် — မင်း လွှဲတဲ့ ပမာဏ/နှုန်း မပြောင်းလဲဘူး။',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
