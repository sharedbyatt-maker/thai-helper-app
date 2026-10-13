import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rates_service.dart';

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💸 ငွေလွှဲနှုန်း နှိုင်းယှဉ်ချက်'),
        actions: [
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
            if (snap.hasError) {
              return const Center(
                  child: Text('ဒေတာ ရယူမရဘူး — ပြန်စမ်းပါ'));
            }
            return const Center(
                child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final quotes =
              RatesService().compare(data, _amount);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _amountInput(),
              const SizedBox(height: 8),
              _sourceBanner(data),
              const SizedBox(height: 8),
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
                      (e) => _quoteCard(e.value, e.key == 0),
                    ),
              const SizedBox(height: 8),
              _footer(data),
            ],
          );
        },
      ),
    );
  }

  Widget _amountInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Text('ဘတ် ',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                decoration: const InputDecoration(
                  hintText: 'ဥပမာ 10000',
                  border: OutlineInputBorder(),
                  isDense: true,
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
      ),
    );
  }

  Widget _sourceBanner(RateData data) {
    final live = RatesService().usingLiveApi;
    final updated = data.updatedAt.length >= 10
        ? data.updatedAt.substring(0, 10)
        : data.updatedAt;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: live
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            live ? Icons.cloud_done : Icons.cloud_off,
            size: 18,
            color: live ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              live
                  ? 'Live data • $updated ရက်နေ့ update'
                  : 'Offline snapshot • $updated ရက်နေ့ data (အဟောင်းဖြစ်နိုင်)',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteCard(RateQuote q, bool best) {
    final ch = q.channel;
    return Card(
      color: best ? Colors.teal.shade50 : null,
      shape: best
          ? RoundedRectangleBorder(
              side: BorderSide(
                  color: Colors.teal.shade700, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ch.nameMy,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (best)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('အကောင်းဆုံး',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12)),
                  ),
                if (!ch.verified)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text('⚠️ မစစ်ရသေး',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_fmt(q.receivedMmk)} ကျပ်',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800),
                ),
                const SizedBox(width: 8),
                Text(
                  'ရမယ်',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _row('Fee', '${_fmt(q.feeThb.toInt())} ဘတ်'),
            _row('နှုန်း',
                '1 ဘတ် = ${ch.rateThbMmk} ကျပ်'),
            _row('ကြာချိန်', ch.transferTimeMy),
            _row('ထုတ်ယူရန်', ch.payoutMy),
            if (ch.notesMy.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(ch.notesMy,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
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
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        data.disclaimerMy,
        style:
            const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );
  }
}
