import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import 'user_language.dart'
    show Text, uiText, uiRateLabel, uiPerBahtLabel, uiFormat;
import 'models.dart';
import 'rate_history.dart';

class TrendCard extends StatefulWidget {
  final List<ExchangeQuote> quotes;
  final RateHistory? history;
  final bool loading, unavailable, cached;
  final void Function(ExchangeQuote) onCalculate;
  const TrendCard({
    super.key,
    required this.quotes,
    required this.history,
    required this.loading,
    required this.unavailable,
    this.cached = false,
    required this.onCalculate,
  });
  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  String? selected;
  int days = 7;
  int? hovered;
  @override
  void didUpdateWidget(covariant TrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quotes.firstOrNull?.direction !=
        widget.quotes.firstOrNull?.direction) {
      selected = null;
      hovered = null;
    }
  }

  String identity(ExchangeQuote q) => '${q.direction.key}:${q.id}';
  static const pale = Color(0xffbbebe0);
  String formatted(double n) => rateValueText(n, ExchangeDirection.mmkThb);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final q =
          widget.quotes.where((q) => identity(q) == selected).firstOrNull ??
          widget.quotes.where((q) => q.activeAt(DateTime.now())).firstOrNull ??
          widget.quotes.firstOrNull;
      final history = widget.history ?? const RateHistory([]);
      final points = q == null
          ? <RatePoint>[]
          : history.referenceSeries(q, days);
      final values = points
          .map((p) => referenceRateValue(p.rateMicros))
          .toList();
      final low = values.isEmpty ? null : values.reduce(math.min);
      final high = values.isEmpty ? null : values.reduce(math.max);
      final change = values.length < 2
          ? null
          : (values.last - values.first) / values.first * 100;
      final active = q?.activeAt(DateTime.now()) ?? false;
      final focus = hovered != null && hovered! < points.length
          ? points[hovered!]
          : null;
      final colors = Theme.of(context).colorScheme;
      return Column(
        key: const ValueKey('rate_trend_card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 12 : 20),
            decoration: BoxDecoration(color: const Color(0xff075d4d), borderRadius: BorderRadius.circular(20)),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 10,
                runSpacing: compact ? 4 : 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(
                    Icons.currency_exchange_rounded,
                    color: pale,
                    size: 19,
                  ),
                  const Text(
                    'နောက်ဆုံးဈေး',
                    style: TextStyle(color: pale, fontWeight: FontWeight.w600),
                  ),
                  if (q != null)
                    tag(
                      widget.cached
                          ? 'သိမ်းထားတဲ့ဈေး'
                          : active
                          ? 'စစ်ထားပြီး'
                          : 'ပြန်စစ်ဖို့လိုနေပြီ',
                    ),
                ],
              ),
              SizedBox(height: compact ? 6 : 16),
              Text(
                q == null ? 'ဒီဘက်ဈေး မတင်ရသေးဘူး' : uiRateLabel(context, q),
                style: TextStyle(
                  fontSize: compact ? 24 : 31,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                  letterSpacing: -.3,
                ),
              ),
              if (q != null) ...[
                SizedBox(height: compact ? 4 : 8),
                Text(
                  uiPerBahtLabel(context, q),
                  key: const ValueKey('per_baht_equivalent'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    q.direction.label,
                    style: const TextStyle(color: pale, fontSize: 13),
                  ),
                ],
                SizedBox(height: compact ? 4 : 6),
                Text(
                  '${compact ? '' : 'နောက်ဆုံးစစ်ချိန် '}${bangkokLabel(q.observedAt)}',
                  style: const TextStyle(color: pale, fontSize: 12),
                ),
                if (!active)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'ဈေးအသစ် မတင်ရသေးပါ။ နောက်ဆုံးတင်ထားတဲ့ဈေးနဲ့ တွက်ကြည့်နိုင်ပါတယ်။',
                      style: TextStyle(color: pale, height: 1.8),
                    ),
                  ),
              ],
              if (q != null)
                Padding(
                  padding: EdgeInsets.only(top: compact ? 8 : 18),
                  child: FilledButton.icon(
                    onPressed: () => widget.onCalculate(q),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff075d4d),
                      minimumSize: compact
                          ? const Size(double.infinity, 44)
                          : null,
                      padding: compact
                          ? const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            )
                          : null,
                    ),
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(
                      active
                          ? 'ဒီနှုန်းနဲ့ တွက်မယ်'
                          : 'နောက်ဆုံးဈေးနဲ့ တွက်မယ်',
                    ),
                  ),
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
                      labelText: uiText(context, 'ကြည့်ချင်တဲ့ဈေး'),
                      labelStyle: const TextStyle(color: pale),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .08),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: .2),
                        ),
                      ),
                    ),
                    items: widget.quotes
                        .map(
                          (e) => DropdownMenuItem(
                            value: identity(e),
                            child: Text(
                              e.label,
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
              ]),
            ),
          ),
          SizedBox(height: compact ? 8 : 14),
          Container(
            padding: EdgeInsets.all(compact ? 10 : 18),
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant)),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: colors.onSurface),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              if (!compact) ...[
                const Text(
                  'ဈေးဘယ်လို ပြောင်းသွားလဲ?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in [1, 7, 30])
                    Semantics(
                      selected: days == n,
                      child: TextButton(
                        onPressed: () => setState(() {
                          days = n;
                          hovered = null;
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: days == n ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                          backgroundColor: days == n ? colors.primaryContainer : Colors.transparent,
                          minimumSize: Size(
                            compact ? 48 : 60,
                            compact ? 36 : 40,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 14,
                            vertical: compact ? 6 : 8,
                          ),
                        ),
                        child: Text(
                          n == 1
                              ? 'ဒီနေ့'
                              : uiFormat(context, 'days', {'count': n}),
                        ),
                      ),
                    ),
                  if (change != null)
                    chartTag(
                      '${change >= 0 ? '+' : '-'} ${change.abs().toStringAsFixed(2)}%${compact ? '' : ' · မှတ်တမ်းကာလ'}',
                    ),
                ],
              ),
              if (!compact || focus != null) ...[
                SizedBox(height: compact ? 6 : 14),
                Text(
                  focus != null
                      ? '${bangkokLabel(focus.timestamp, includeTime: focus.observedAt != null)} · ${formatted(referenceRateValue(focus.rateMicros))} ဘတ်'
                      : points.length == 1
                      ? 'ဈေးတစ်ကြိမ်ပဲ တင်ထားသေးတယ်။ အမှတ်လေးကို ထိကြည့်ပါ။'
                      : points.isEmpty
                      ? (widget.loading
                            ? 'အရင်တင်ထားတဲ့ဈေးတွေ ယူနေပါတယ်'
                            : 'ဒီရက်တွေအတွက် ဈေးမှတ်တမ်း မရှိသေးဘူး။')
                      : 'အမှတ်လေးကို ထိပြီး ဈေးနဲ့အချိန် ကြည့်လို့ရပါတယ်',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.8,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) => Semantics(
                  label: points.isEmpty
                      ? uiText(context, 'ဈေးမှတ်တမ်း မရှိသေးဘူး')
                      : uiFormat(context, 'graphSummary', {
                          'count': points.length,
                          'low': formatted(low!),
                          'high': formatted(high!),
                        }),
                  child: MouseRegion(
                    onHover: (event) =>
                        selectPoint(event.localPosition.dx, c.maxWidth, points),
                    onExit: (_) => setState(() => hovered = null),
                    child: GestureDetector(
                      onTapDown: (event) => selectPoint(
                        event.localPosition.dx,
                        c.maxWidth,
                        points,
                      ),
                      onHorizontalDragUpdate: (event) => selectPoint(
                        event.localPosition.dx,
                        c.maxWidth,
                        points,
                      ),
                      child: SizedBox(
                        height: compact ? 108 : 158,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                key: const ValueKey('reference_rate_graph'),
                                painter: RateTrendPainter(
                                  points,
                                  hovered,
                                  ink: colors.primary,
                                  direction:
                                      q?.direction ?? ExchangeDirection.thbMmk,
                                ),
                              ),
                            ),
                            if (points.length == 1)
                              Align(
                                alignment: const Alignment(0, -.62),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${formatted(values.first)} ဘတ်',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (points.isEmpty)
                              Center(
                                child: Text(
                                  widget.loading
                                      ? 'ရယူနေပါတယ်…'
                                      : 'ဈေးအသစ်တင်ရင် ဒီနေရာမှာ ပြပေးမယ်။',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (points.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pointLabel(points.first),
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                    ),
                    if (points.length > 1)
                      Text(
                        pointLabel(points.last),
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 16),
                Text('ကျပ် ၁ သိန်းအတွက် ဘတ် အနိမ့် / အမြင့်', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: compact ? 12 : 22,
                  runSpacing: 10,
                  children: [
                    compact
                        ? Text(
                            'အနိမ့် ${formatted(low!)}',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          )
                        : metric('အနိမ့်', formatted(low!)),
                    compact
                        ? Text(
                            'အမြင့် ${formatted(high!)}',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          )
                        : metric('အမြင့်', formatted(high!)),
                    if (compact)
                      Text(
                        uiFormat(context, days == 1 ? 'updates' : 'days', {
                          'count': points.length,
                        }),
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                      )
                    else
                      metric(
                        days == 1 ? 'ဈေးတင်ထားတာ' : 'ဈေးတင်ထားတဲ့ရက်',
                        uiFormat(context, days == 1 ? 'updates' : 'days', {
                          'count': points.length,
                        }),
                      ),
                  ],
                ),
              ],
              SizedBox(height: compact ? 8 : 12),
              Text(
                '${history.cached ? 'သိမ်းထားတဲ့မှတ်တမ်း · ' : ''}${q?.direction == ExchangeDirection.thbMmk ? '၁ သိန်းရဖို့ ပေးရမယ့်ဘတ်' : '၁ သိန်းပေးရင် ရမယ့်ဘတ်'}${compact ? '' : ' · ထိုင်းအချိန်'}',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: compact ? 10 : 11,
                  height: 1.6,
                ),
              ),
              if (widget.unavailable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'အရင်ဈေးတွေ ယူမရသေးဘူး။ နောက်ဆုံးရထားတဲ့ဈေးကိုတော့ ပြထားပါတယ်။',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ),
        ],
      );
    },
  );

  Widget chartTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 11)),
  );

  Widget tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
  Widget metric(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
  String pointLabel(RatePoint p) => days == 1 && p.observedAt != null
      ? timeLabel(p.timestamp)
      : dateLabel(p.day);
  void selectPoint(double dx, double width, List<RatePoint> points) {
    if (points.isEmpty || width <= 0) return;
    final span = points.last.timestamp
        .difference(points.first.timestamp)
        .inMilliseconds;
    final at = span * ((dx - 8) / math.max(width - 16, 1)).clamp(0.0, 1.0);
    var best = 0;
    for (var i = 1; i < points.length; i++) {
      if ((points[i].timestamp
                      .difference(points.first.timestamp)
                      .inMilliseconds -
                  at)
              .abs() <
          (points[best].timestamp
                      .difference(points.first.timestamp)
                      .inMilliseconds -
                  at)
              .abs()) {
        best = i;
      }
    }
    if (hovered != best) setState(() => hovered = best);
  }
}

String dateLabel(DateTime d) => '${d.day}/${d.month}';
String timeLabel(DateTime raw) {
  final d = raw.toUtc().add(const Duration(hours: 7));
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String bangkokLabel(DateTime raw, {bool includeTime = true}) {
  final d = raw.toUtc().add(const Duration(hours: 7));
  return '${dateLabel(d)}${includeTime ? ' ${timeLabel(raw)}' : ''} (ထိုင်း)';
}

class RateTrendPainter extends CustomPainter {
  final List<RatePoint> points;
  final int? selected;
  final ExchangeDirection direction;
  final Color ink;
  RateTrendPainter(
    this.points,
    this.selected, {
    this.direction = ExchangeDirection.thbMmk,
    this.ink = Colors.white,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final grid = Paint()
      ..color = ink.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (final y in [.15, .5, .85]) {
      for (double x = 0; x < size.width; x += 9) {
        canvas.drawLine(
          Offset(x, size.height * y),
          Offset(math.min(x + 4, size.width), size.height * y),
          grid,
        );
      }
    }
    if (points.isEmpty) return;
    final values = points.map((p) => referenceRateValue(p.rateMicros)).toList();
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final range = math.max(high - low, math.max(high * .002, .000001)),
        mid = (high + low) / 2;
    final span = points.last.timestamp
        .difference(points.first.timestamp)
        .inMilliseconds;
    final positions = [
      for (var i = 0; i < points.length; i++)
        Offset(
          points.length == 1 || span == 0
              ? size.width / 2
              : 8 +
                    (size.width - 16) *
                        points[i].timestamp
                            .difference(points.first.timestamp)
                            .inMilliseconds /
                        span,
          size.height * .5 - (values[i] - mid) / range * size.height * .68,
        ),
    ];
    if (points.length > 1) {
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
              ink.withValues(alpha: .25),
              ink.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = ink
          ..strokeWidth = 2.8
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
    final p =
        positions[(selected ?? positions.length - 1).clamp(
          0,
          positions.length - 1,
        )];
    if (selected != null) {
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        grid..color = ink.withValues(alpha: .4),
      );
    }
    for (final position in positions) {
      canvas.drawCircle(
        position,
        2.3,
        Paint()..color = ink.withValues(alpha: .65),
      );
    }
    canvas.drawCircle(
      p,
      9,
      Paint()..color = ink.withValues(alpha: .17),
    );
    canvas.drawCircle(p, 4.5, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(covariant RateTrendPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.direction != direction || old.ink != ink;
}

