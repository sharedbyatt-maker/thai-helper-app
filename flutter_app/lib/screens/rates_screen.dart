import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // end dot
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

  @override
  void initState() {
    super.initState();
    _future = RatesService().load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ??
      10000;

  void _share(RateData data, List<RateQuote> quotes) {
    if (quotes.isEmpty) return;
    final medals = ['🥇', '🥈', '🥉', '4️⃣'];
    final buf = StringBuffer()
      ..writeln(
          '💸 ဒီနေ့ ဘတ်ဈေး (${data.updatedAt.substring(0, 10)})')
      ..writeln(
          '${_fmt(_amount.toInt())} ဘတ် လွှဲရင်:')
      ..writeln();
    for (var i = 0;
        i < quotes.length && i < medals.length;
        i++) {
      final q = quotes[i];
      buf.writeln(
          '${medals[i]} ${q.channel.nameMy} → ${_fmt(q.receivedMmk)} ကျပ်');
    }
    buf
      ..writeln()
      ..writeln('📲 $_appUrl');
    Share.share(buf.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💸 ဘတ်ဈေး'),
        actions: [
          FutureBuilder<RateData>(
            future: _future,
            builder: (context, snap) => IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'မျှဝေမယ်',
              onPressed: snap.hasData
                  ? () => _share(
                      snap.data!,
                      RatesService()
                          .compare(snap.data!, _amount))
                  : null,
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
          final quotes =
              RatesService().compare(data, _amount);
          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _future = RatesService().load()),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _marketHeader(data),
                const SizedBox(height: 10),
                _amountCard(),
                const SizedBox(height: 10),
                if (quotes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'ဒီပမာဏအတွက် channel မရှိဘူး — ပမာဏ ချိန်ကြည့်'),
                    ),
                  )
                else
                  ...quotes.asMap().entries.map(
                        (e) =>
                            _quoteCard(context, e.value, e.key),
                      ),
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

  Widget _amountCard() {
    const chips = [5000, 10000, 20000, 50000];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('လွှဲမယ့် ပမာဏ (ဘတ်)',
                style: TextStyle(
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixText: '฿ ',
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
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
                        selected:
                            _amount.toInt() == c,
                        onSelected: (_) {
                          _amountCtrl.text = c.toString();
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

  Widget _quoteCard(
      BuildContext context, RateQuote q, int rank) {
    final ch = q.channel;
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
            Row(
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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(ch.nameMy,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(ch.name,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey)),
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
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Text('အကောင်းဆုံး',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: best
                    ? brand.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('လက်ခံရမယ်',
                      style: TextStyle(fontSize: 13)),
                  Text(
                    '${_fmt(q.receivedMmk)} ကျပ်',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: best
                            ? brand
                            : Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _detailRow('Fee', '${_fmt(q.feeThb.toInt())} ဘတ်'),
            _detailRow('နှုန်း',
                '1 ฿ = ${_fmtDouble(ch.rateThbMmk)} ကျပ်'),
            _detailRow('⏱ ကြာချိန်', ch.transferTimeMy),
            _detailRow('💰 ထုတ်ယူရန်', ch.payoutMy),
            if (!ch.verified)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('⚠️ နှုန်းမစစ်ရသေး — လွှဲခါနီး အတည်ပြုပါ',
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
        ],
      ),
    );
  }
}
