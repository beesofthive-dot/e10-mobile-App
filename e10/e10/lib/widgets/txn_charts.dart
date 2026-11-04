import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// One point of a Transactions chart: the server's `period` (a date or week)
/// or `method`, its amount and how many payments made it up.
class ChartPoint {
  const ChartPoint(this.label, this.amount, [this.count = 0]);

  final String label;
  final double amount;
  final int count;
}

/// The website's two Transactions charts — "Volume over time" (green area
/// line) and "By method" (blue bars) — with dashed grid lines, amount axis,
/// labels under the points, and the amount shown when a point or bar is
/// touched, so the phone shows the same picture as the main dashboard.
class TxnChartCard extends StatefulWidget {
  const TxnChartCard({
    super.key,
    required this.title,
    required this.empty,
    required this.points,
    required this.format,
    this.bars = false,
  });

  final String title;
  final String empty;
  final List<ChartPoint> points;
  final String Function(double) format;
  final bool bars;

  @override
  State<TxnChartCard> createState() => _TxnChartCardState();
}

class _TxnChartCardState extends State<TxnChartCard> {
  int? _selected;

  static const _green = Color(0xFF1A9E6E);
  static const _blue = Color(0xFF2B6CB0);

  int? _hit(Offset local, Size size) {
    final n = widget.points.length;
    if (n == 0) return null;
    final plot = _ChartGeometry(size, n, widget.bars);
    final x = local.dx.clamp(plot.left, plot.right);
    if (widget.bars) {
      final i = ((x - plot.left) / plot.slot).floor();
      return i.clamp(0, n - 1);
    }
    if (n == 1) return 0;
    return ((x - plot.left) / (plot.width / (n - 1))).round().clamp(0, n - 1);
  }

  @override
  void didUpdateWidget(TxnChartCard old) {
    super.didUpdateWidget(old);
    if (_selected != null && _selected! >= widget.points.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final selected = _selected == null || points.isEmpty ? null : points[_selected!];
    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppText.display(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          // What the touched point is, like the website's hover box.
          SizedBox(
            height: 34,
            child: selected == null
                ? (points.isEmpty
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Touch the chart to see each amount', style: AppText.body(size: 11, color: AppColors.slate400)),
                      ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected.label, style: AppText.body(size: 12, weight: FontWeight.w700)),
                      Text(
                        'amount : ${widget.format(selected.amount)}${selected.count > 0 ? ' · ${selected.count} payment${selected.count == 1 ? '' : 's'}' : ''}',
                        style: AppText.body(size: 12, color: widget.bars ? _blue : _green),
                      ),
                    ],
                  ),
          ),
          if (points.isEmpty)
            SizedBox(
              height: 90,
              child: Center(child: Text(widget.empty, style: AppText.body(size: 13, color: AppColors.slate500))),
            )
          else
            SizedBox(
              height: 220,
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = Size(box.maxWidth, 220);
                  void pick(Offset p) => setState(() => _selected = _hit(p, size));
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => pick(d.localPosition),
                    onHorizontalDragUpdate: (d) => pick(d.localPosition),
                    child: CustomPaint(
                      size: size,
                      painter: _TxnChartPainter(
                        points: points,
                        bars: widget.bars,
                        selected: _selected,
                        color: widget.bars ? _blue : _green,
                        grid: AppSurface.line(context),
                        text: AppSurface.muted(context),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the plot sits inside the chart: room on the left for the amount
/// axis and at the bottom for the labels.
class _ChartGeometry {
  _ChartGeometry(Size size, this.count, this.bars)
      : left = 44,
        right = size.width - 8,
        top = 8,
        bottom = size.height - 26;

  final int count;
  final bool bars;
  final double left;
  final double right;
  final double top;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get slot => width / math.max(count, 1);
}

class _TxnChartPainter extends CustomPainter {
  _TxnChartPainter({
    required this.points,
    required this.bars,
    required this.selected,
    required this.color,
    required this.grid,
    required this.text,
  });

  final List<ChartPoint> points;
  final bool bars;
  final int? selected;
  final Color color;
  final Color grid;
  final Color text;

  /// A round top for the amount axis (700 → 2800 like the website's axis).
  static double _niceTop(double max) {
    if (max <= 0) return 4;
    final raw = max / 4;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in const [1, 2, 2.5, 5, 7, 10]) {
      if (m * mag >= raw) return m * mag * 4;
    }
    return 10 * mag * 4;
  }

  static String _axis(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  void _label(Canvas canvas, String s, Offset at, {TextAlign align = TextAlign.center, double maxWidth = 80}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: 10, color: text)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.left => at.dx,
      _ => at.dx - tp.width / 2,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = _ChartGeometry(size, points.length, bars);
    final top = _niceTop(points.map((p) => p.amount).fold<double>(0, math.max));
    double y(double v) => g.bottom - (v / top) * g.height;

    // Dashed grid and amount axis (5 lines: 0 … top).
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = top * i / 4;
      final yy = y(v);
      for (var x = g.left; x < g.right; x += 6) {
        canvas.drawLine(Offset(x, yy), Offset(math.min(x + 3, g.right), yy), gridPaint);
      }
      _label(canvas, _axis(v), Offset(g.left - 6, yy), align: TextAlign.right, maxWidth: 40);
    }

    final n = points.length;
    if (bars) {
      final barW = math.min(g.slot * 0.6, 56.0);
      for (var i = 0; i < n; i++) {
        final cx = g.left + g.slot * (i + 0.5);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - barW / 2, y(points[i].amount), cx + barW / 2, g.bottom),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = selected == null || selected == i ? color : color.withValues(alpha: 0.45));
        _label(canvas, points[i].label, Offset(cx, g.bottom + 13), maxWidth: g.slot);
      }
      return;
    }

    double x(int i) => n == 1 ? (g.left + g.right) / 2 : g.left + g.width * i / (n - 1);
    final line = Path();
    for (var i = 0; i < n; i++) {
      final p = Offset(x(i), y(points[i].amount));
      // Gentle curve between points, like the website's "monotone" line.
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        final prev = Offset(x(i - 1), y(points[i - 1].amount));
        final mid = (prev.dx + p.dx) / 2;
        line.cubicTo(mid, prev.dy, mid, p.dy, p.dx, p.dy);
      }
    }
    final area = Path.from(line)
      ..lineTo(x(n - 1), g.bottom)
      ..lineTo(x(0), g.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Labels under the line: first, last and a few in between that fit.
    final step = math.max(1, (n / math.max(1, g.width ~/ 72)).ceil());
    for (var i = 0; i < n; i++) {
      if (i % step == 0 || i == n - 1) {
        final align = i == 0 && n > 1 ? TextAlign.left : (i == n - 1 && n > 1 ? TextAlign.right : TextAlign.center);
        _label(canvas, points[i].label, Offset(x(i), g.bottom + 13), align: align);
      }
    }

    if (selected != null) {
      final i = selected!;
      final p = Offset(x(i), y(points[i].amount));
      canvas.drawLine(Offset(p.dx, g.top), Offset(p.dx, g.bottom), Paint()..color = color.withValues(alpha: 0.35));
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.5, Paint()..color = color);
    } else if (n == 1) {
      canvas.drawCircle(Offset(x(0), y(points[0].amount)), 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_TxnChartPainter old) =>
      old.points != points || old.selected != selected || old.color != color || old.grid != grid;
}
