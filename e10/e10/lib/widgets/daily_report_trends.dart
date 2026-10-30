import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// The parent "Trends" tab of a KG/crèche daily report: the last week of
/// sent reports summarised the same way the live website does it.
class DailyReportTrends extends StatelessWidget {
  const DailyReportTrends({super.key, required this.days, required this.byDay, required this.firstName});

  /// yyyy-mm-dd keys, oldest first.
  final List<String> days;
  final Map<String, Map<String, dynamic>> byDay;
  final String firstName;

  static const moodScores = {'fussy': 1, 'tired': 2, 'calm': 3, 'happy': 4};
  static const moodEmoji = {'happy': '😊', 'calm': '😌', 'fussy': '😣', 'tired': '😴'};
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  String _dayLabel(String key) {
    final d = DateTime.tryParse(key);
    return d == null ? key : _weekdays[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final labels = [for (final d in days) _dayLabel(d)];
    final reports = [for (final d in days) byDay[d]];

    final moods = [for (final r in reports) moodScores['${r?['mood'] ?? ''}'.toLowerCase()]];
    final scored = moods.whereType<int>().toList();
    final avgMood = scored.isEmpty ? null : scored.reduce((a, b) => a + b) / scored.length;

    final naps = [for (final r in reports) r == null || r['nap_minutes'] == null || '${r['nap_minutes']}' == 'null' ? null : _int(r['nap_minutes'])];
    final napValues = naps.whereType<int>().toList();
    final avgNap = napValues.isEmpty ? null : (napValues.reduce((a, b) => a + b) / napValues.length).round();

    final ate = <int>[];
    final skipped = <int>[];
    for (final r in reports) {
      var a = 0, s = 0;
      for (final key in const ['breakfast_status', 'lunch_status', 'snack_status']) {
        final v = '${r?[key] ?? ''}'.toLowerCase();
        if (v.isEmpty || v == 'null') continue;
        if (v == 'none' || v == 'skipped') {
          s++;
        } else {
          a++;
        }
      }
      ate.add(a);
      skipped.add(s);
    }
    final mealsEaten = ate.fold<int>(0, (x, y) => x + y);
    final mealsTotal = mealsEaten + skipped.fold<int>(0, (x, y) => x + y);

    var wet = 0, soiled = 0, total = 0;
    final activityCounts = <String, int>{};
    // Newest first, like the website, so ties go to the most recent activity.
    for (final r in reports.reversed.whereType<Map<String, dynamic>>()) {
      total += _int(r['diaper_count']);
      wet += _int(r['diaper_wet_count']);
      soiled += _int(r['diaper_soiled_count']);
      if (r['activities'] is List) {
        for (final a in r['activities'] as List) {
          final name = '$a'.trim();
          if (name.isNotEmpty) activityCounts[name] = (activityCounts[name] ?? 0) + 1;
        }
      }
    }
    String? favourite;
    var best = 0;
    activityCounts.forEach((name, count) {
      if (count > best) {
        favourite = name;
        best = count;
      }
    });
    var streak = 0, run = 0;
    for (final m in moods) {
      if (m != null && m >= 3) {
        run++;
        if (run > streak) streak = run;
      } else {
        run = 0;
      }
    }

    if (reports.every((r) => r == null)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('No daily reports were sent for $firstName in the last 7 days.', style: AppText.body(size: 13, color: AppSurface.muted(context))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(width: w, child: _Stat(label: 'Avg mood', value: avgMood == null ? '—' : avgMood.toStringAsFixed(1), color: AppColors.blue)),
                SizedBox(width: w, child: _Stat(label: 'Avg nap', value: avgNap == null ? '—' : '${avgNap}m')),
                SizedBox(width: w, child: _Stat(label: 'Meals eaten', value: '$mealsEaten/$mealsTotal', color: AppColors.emerald)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _ChartBlock(
          title: 'Mood this week',
          labels: labels,
          footer: Row(
            children: [
              for (final r in reports)
                Expanded(
                  child: Text(
                    moodEmoji['${r?['mood'] ?? ''}'.toLowerCase()] ?? '·',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
          painter: _MoodLinePainter(scores: moods, line: AppColors.blue, grid: AppSurface.line(context)),
        ),
        const SizedBox(height: 12),
        _ChartBlock(
          title: 'Nap duration (minutes)',
          labels: labels,
          painter: _BarsPainter(
            series: [[for (final n in naps) n ?? 0]],
            colors: const [AppColors.blue],
            grid: AppSurface.line(context),
            tick: AppSurface.muted(context),
          ),
        ),
        const SizedBox(height: 12),
        _ChartBlock(
          title: 'Meals eaten vs skipped',
          labels: labels,
          footer: Row(
            children: [
              _legend(context, AppColors.emerald, 'Ate'),
              const SizedBox(width: 14),
              _legend(context, AppColors.rose, 'Skipped'),
            ],
          ),
          painter: _BarsPainter(
            series: [ate, skipped],
            colors: const [AppColors.emerald, AppColors.rose],
            grid: AppSurface.line(context),
            tick: AppSurface.muted(context),
          ),
        ),
        if (streak >= 2 || favourite != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF7E0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF5D98B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("THIS WEEK'S HIGHLIGHT", style: AppText.body(size: 11, weight: FontWeight.w800, color: _amber, letterSpacing: 0.6)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: AppText.body(size: 13, color: const Color(0xFF1F2937)),
                    children: [
                      if (streak >= 2) ...[
                        TextSpan(text: '$firstName is on a '),
                        TextSpan(text: '$streak-day streak', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const TextSpan(text: ' of good moods. '),
                      ],
                      if (favourite != null) ...[
                        const TextSpan(text: 'Favourite activity this week: '),
                        TextSpan(text: favourite, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const TextSpan(text: '.'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Diaper changes this week', style: AppText.display(size: 17, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              _diaperRow(context, 'Wet', wet, total, AppColors.blue),
              _diaperRow(context, 'Soiled', soiled, total, _amber),
              _diaperRow(context, 'Total', total, total, AppColors.navy),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: AppText.body(size: 12, color: AppSurface.muted(context))),
        ],
      );

  Widget _diaperRow(BuildContext context, String label, int value, int max, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label, style: AppText.body(size: 13, weight: FontWeight.w600))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: AppSurface.line(context),
                color: color,
              ),
            ),
          ),
          SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.right, style: AppText.body(size: 13, weight: FontWeight.w800, color: color))),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.body(size: 11, weight: FontWeight.w800, color: AppSurface.muted(context), letterSpacing: 0.4)),
          const SizedBox(height: 6),
          Text(value, style: AppText.display(size: 26, weight: FontWeight.w700, color: color ?? AppSurface.text(context))),
        ],
      ),
    );
  }
}

class _ChartBlock extends StatelessWidget {
  const _ChartBlock({required this.title, required this.labels, required this.painter, this.footer});

  final String title;
  final List<String> labels;
  final CustomPainter painter;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.display(size: 17, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(height: 140, width: double.infinity, child: CustomPaint(painter: painter)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: _chartLeftInset),
            child: Row(
              children: [
                for (final l in labels)
                  Expanded(child: Text(l, textAlign: TextAlign.center, style: AppText.body(size: 11, color: AppSurface.muted(context)))),
              ],
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Padding(padding: const EdgeInsets.only(left: _chartLeftInset), child: footer!),
          ],
        ],
      ),
    );
  }
}

const double _chartLeftInset = 22;
const Color _amber = Color(0xFFC27803);

void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
  const dash = 4.0, gap = 4.0;
  final total = (b - a).distance;
  final dir = (b - a) / total;
  var d = 0.0;
  while (d < total) {
    final end = (d + dash).clamp(0, total).toDouble();
    canvas.drawLine(a + dir * d, a + dir * end, paint);
    d += dash + gap;
  }
}

class _MoodLinePainter extends CustomPainter {
  _MoodLinePainter({required this.scores, required this.line, required this.grid});

  final List<int?> scores;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final left = _chartLeftInset;
    final w = size.width - left;
    final slot = w / scores.length;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      _dashedLine(canvas, Offset(left, y), Offset(size.width, y), gridPaint);
    }
    double yFor(int s) => size.height - (s - 1) / 3 * size.height;
    final points = <Offset>[
      for (var i = 0; i < scores.length; i++)
        if (scores[i] != null) Offset(left + slot * (i + 0.5), yFor(scores[i]!)),
    ];
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.08));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    for (final p in points) {
      canvas.drawCircle(p, 3.5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodLinePainter old) => old.scores != scores || old.line != line || old.grid != grid;
}

/// Stacked bars (one colour per series) with a small y-axis scale.
class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.series, required this.colors, required this.grid, required this.tick});

  final List<List<int>> series;
  final List<Color> colors;
  final Color grid;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final count = series.first.length;
    final totals = [for (var i = 0; i < count; i++) series.fold<int>(0, (s, row) => s + row[i])];
    final peak = totals.fold<int>(0, (a, b) => a > b ? a : b);
    final steps = 4;
    final unit = peak <= steps ? 1 : (peak / steps).ceil();
    final top = unit * steps;
    final left = _chartLeftInset;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= steps; i++) {
      final y = size.height - size.height * i / steps;
      _dashedLine(canvas, Offset(left, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${unit * i}', style: TextStyle(fontSize: 10, color: tick)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }
    final slot = (size.width - left) / count;
    final barW = (slot * 0.6).clamp(6, 40).toDouble();
    for (var i = 0; i < count; i++) {
      var base = size.height;
      for (var s = 0; s < series.length; s++) {
        final v = series[s][i];
        if (v <= 0) continue;
        final h = v / top * size.height;
        final x = left + slot * i + (slot - barW) / 2;
        final isTop = series.skip(s + 1).every((row) => row[i] <= 0);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, base - h, barW, h),
            topLeft: isTop ? const Radius.circular(4) : Radius.zero,
            topRight: isTop ? const Radius.circular(4) : Radius.zero,
          ),
          Paint()..color = colors[s],
        );
        base -= h;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => true;
}
