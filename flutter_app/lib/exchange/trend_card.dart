import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'rate_history.dart';

class TrendCard extends StatefulWidget {
  final List<ExchangeQuote> quotes;
  final RateHistory? history;
  final bool loading, unavailable;
  final void Function(ExchangeQuote) onCalculate;
  const TrendCard({
    super.key,
    required this.quotes,
    required this.history,
    required this.loading,
    required this.unavailable,
    required this.onCalculate,
  });
  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  String? selected;
  int days = 7;
  int? hovered;
  String identity(ExchangeQuote q) => '${q.direction.key}:${q.id}';
  @override
  Widget build(BuildContext context) {
    final q =
        widget.quotes.where((q) => identity(q) == selected).firstOrNull ??
        widget.quotes.where((q) => q.activeAt(DateTime.now())).firstOrNull ??
        widget.quotes.firstOrNull;
    final points = q == null
        ? <RatePoint>[]
        : widget.history?.series(q, days) ?? <RatePoint>[];
    final canChart = points.length >= 2;
    final hasHistory =
        q != null && (widget.history?.series(q, 30).length ?? 0) >= 2;
    final direction = q?.direction ?? ExchangeDirection.thbMmk;
    double value(RatePoint p) => displayRateValue(p.rateMicros, direction);
    String formatted(double value) => rateValueText(value, direction);
    final unit = direction == ExchangeDirection.mmkThb
        ? 'ကျပ် ၁ သိန်းအတွက် ဘတ်'
        : '၁ ဘတ်အတွက် ကျပ်';
    final low = points.isEmpty ? null : points.map(value).reduce(math.min);
    final high = points.isEmpty ? null : points.map(value).reduce(math.max);
    final change = canChart
        ? (value(points.last) - value(points.first)) / value(points.first) * 100
        : null;
    final active = q?.activeAt(DateTime.now()) ?? false;
    final focus = hovered != null && hovered! < points.length
        ? points[hovered!]
        : null;
    const pale = Color(0xffbbebe0);
    Widget tag(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
    return Container(
      key: const ValueKey('rate_trend_card'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff074f47), Color(0xff008f7a)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff08765f).withValues(alpha: .16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.show_chart_rounded, color: pale, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'နောက်ဆုံး ငွေလဲနှုန်း',
                        style: TextStyle(
                          color: pale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (q != null)
                  tag(
                    active
                        ? 'နောက်ဆုံး ထုတ်ပြထားသောနှုန်း'
                        : 'ပြန်မစစ်ရသေးသောနှုန်း',
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              q == null ? 'ဒီဘက်နှုန်း မတင်ရသေးပါ' : quoteRateLabel(q),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.65,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 4),
            if (q != null)
              Text(
                '${q.sourceName} · ${q.direction.label}',
                style: const TextStyle(color: pale, fontSize: 13),
              ),
            if (q != null && !active)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'နောက်ဆုံးသိမ်းထားသောနှုန်းကို ပြထားသည်။ အသစ်ပြန်မစစ်ရသေးသဖြင့် လက်ရှိနှုန်းအဖြစ် မတွက်ပေးပါ။',
                  style: TextStyle(color: pale, height: 1.8),
                ),
              ),
            if (q == null)
              const Text(
                'နေ့စဉ် စစ်ဆေးထားသောနှုန်းများကို ဒီနေရာမှာ ကြည့်နိုင်ပါမယ်။',
                style: TextStyle(color: pale, height: 1.8),
              ),
            if (widget.quotes.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(q == null ? 'empty' : identity(q)),
                  initialValue: q == null ? null : identity(q),
                  isExpanded: true,
                  dropdownColor: const Color(0xff075e52),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Noto Sans Myanmar',
                    fontSize: 13,
                  ),
                  iconEnabledColor: pale,
                  decoration: InputDecoration(
                    labelText: 'ကြည့်မည့်နှုန်း',
                    labelStyle: const TextStyle(color: pale),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .08),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: .2),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  items: widget.quotes
                      .map(
                        (e) => DropdownMenuItem(
                          value: identity(e),
                          child: Text(
                            '${e.label} · ${e.payoutMethod}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    selected = value;
                    hovered = null;
                  }),
                ),
              ),
            if (hasHistory) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final n in [7, 30])
                    Semantics(
                      selected: days == n,
                      child: TextButton(
                        onPressed: () => setState(() {
                          days = n;
                          hovered = null;
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: days == n
                              ? const Color(0xff075d4d)
                              : Colors.white,
                          backgroundColor: days == n
                              ? Colors.white
                              : Colors.white.withValues(alpha: .10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          minimumSize: const Size(64, 42),
                        ),
                        child: Text('$n ရက်'),
                      ),
                    ),
                  if (change != null)
                    tag(
                      '${change >= 0 ? '+' : '-'} ${change.abs().toStringAsFixed(2)}% · မှတ်တမ်းကာလ',
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (canChart) ...[
              Text(
                focus == null
                    ? 'မှတ်တမ်းကို ထိပြီး ကြည့်နိုင်ပါတယ်'
                    : '${dateLabel(focus.day)} · ${formatted(value(focus))} · $unit',
                style: const TextStyle(color: pale, fontSize: 12),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) => Semantics(
                  label:
                      '$days ရက်အတွင်း ${points.length} ရက်၏ နှုန်းမှတ်တမ်း။ အနိမ့် ${formatted(low!)}၊ အမြင့် ${formatted(high!)} · $unit။',
                  child: MouseRegion(
                    onHover: (event) =>
                        selectPoint(event.localPosition.dx, c.maxWidth, points),
                    onExit: (_) => setState(() => hovered = null),
                    child: GestureDetector(
                      onTapDown: (details) => selectPoint(
                        details.localPosition.dx,
                        c.maxWidth,
                        points,
                      ),
                      onHorizontalDragUpdate: (details) => selectPoint(
                        details.localPosition.dx,
                        c.maxWidth,
                        points,
                      ),
                      child: SizedBox(
                        height: 146,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: RateTrendPainter(
                            points,
                            hovered,
                            direction: direction,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateLabel(points.first.day),
                    style: const TextStyle(color: pale, fontSize: 11),
                  ),
                  Text(
                    dateLabel(points.last.day),
                    style: const TextStyle(color: pale, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  metric('အနိမ့်', formatted(low!)),
                  metric('အမြင့်', formatted(high!)),
                  metric('မှတ်တမ်းရှိသည့်ရက်', '${points.length} ရက်'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${widget.history?.cached == true ? 'သိမ်းထားသောမှတ်တမ်း · ' : ''}$unit · သီးသန့်နုတ်ငွေ မပါ · မှတ်တမ်းရှိသည့်ရက်များသာ · ထိုင်းအချိန်',
                style: const TextStyle(fontSize: 11, color: pale, height: 1.8),
              ),
            ] else if (q != null || widget.loading)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  widget.loading
                      ? 'မှတ်တမ်း ရယူနေပါတယ်'
                      : widget.unavailable
                      ? 'ယခင်ရက် မှတ်တမ်းကို ရယူမရသေးပါ။'
                      : 'ယခင်ရက် နှုန်းမှတ်တမ်း ရလာလျှင် graph ပြပေးပါမယ်။',
                  style: const TextStyle(
                    color: pale,
                    fontSize: 12,
                    height: 1.8,
                  ),
                ),
              ),
            if (q != null && active)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: FilledButton.icon(
                  onPressed: () => widget.onCalculate(q),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff075d4d),
                  ),
                  icon: const Icon(Icons.calculate_outlined, size: 18),
                  label: const Text('ဒီနှုန်းနဲ့ တွက်မယ်'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xffbbebe0), fontSize: 11),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
  void selectPoint(double dx, double width, List<RatePoint> points) {
    final span = points.last.day.difference(points.first.day).inDays;
    final day = span * (dx / width).clamp(0.0, 1.0);
    var best = 0;
    for (var i = 1; i < points.length; i++) {
      if ((points[i].day.difference(points.first.day).inDays - day).abs() <
          (points[best].day.difference(points.first.day).inDays - day).abs()) {
        best = i;
      }
    }
    if (hovered != best) setState(() => hovered = best);
  }
}

String dateLabel(DateTime d) => '${d.day}/${d.month}';

class RateTrendPainter extends CustomPainter {
  final List<RatePoint> points;
  final int? selected;
  final ExchangeDirection direction;
  RateTrendPainter(
    this.points,
    this.selected, {
    this.direction = ExchangeDirection.thbMmk,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    double value(RatePoint p) => displayRateValue(p.rateMicros, direction);
    final low = points.map(value).reduce(math.min),
        high = points.map(value).reduce(math.max);
    final range = math.max(high - low, math.max(high * .002, .000001));
    final mid = (high + low) / 2;
    final span = points.last.day.difference(points.first.day).inDays;
    final positions = points
        .map(
          (p) => Offset(
            8 +
                (size.width - 16) *
                    p.day.difference(points.first.day).inDays /
                    math.max(span, 1),
            size.height * .5 - (value(p) - mid) / range * size.height * .68,
          ),
        )
        .toList();
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (final fraction in [.15, .5, .85]) {
      for (double x = 0; x < size.width; x += 9) {
        canvas.drawLine(
          Offset(x, size.height * fraction),
          Offset(math.min(x + 4, size.width), size.height * fraction),
          grid,
        );
      }
    }
    final line = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (final p in positions.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(positions.last.dx, size.height)
      ..lineTo(positions.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .28),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.8
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    final p =
        positions[(selected ?? positions.length - 1).clamp(
          0,
          positions.length - 1,
        )];
    if (selected != null) {
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        grid..color = Colors.white.withValues(alpha: .4),
      );
    }
    canvas.drawCircle(
      p,
      8,
      Paint()..color = Colors.white.withValues(alpha: .17),
    );
    canvas.drawCircle(p, 4.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant RateTrendPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.direction != direction;
}
