import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// Shared presentational pieces of the admin "Transactions" page
/// ([FinanceScreen]) so the parent-facing transactions view can match the
/// same look without duplicating this boilerplate.

InputDecoration financeBoxDecoration() {
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border));
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border,
    enabledBorder: border,
  );
}

class FilterDrop extends StatelessWidget {
  const FilterDrop({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(size: 12, color: AppColors.slate500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: financeBoxDecoration(),
          items: [for (final item in items) DropdownMenuItem(value: item, child: Text(item, style: AppText.body(size: 13)))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class DateFilterField extends StatelessWidget {
  const DateFilterField({super.key, required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(size: 12, color: AppColors.slate500)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(child: Text(value, style: AppText.body(size: 13, color: AppColors.slate600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 12, color: AppColors.slate500)),
          const SizedBox(height: 6),
          Text(value, style: AppText.display(size: 22, weight: FontWeight.w800, color: AppColors.navy), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(hint, style: AppText.body(size: 11, color: AppColors.slate400), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class TabChip extends StatelessWidget {
  const TabChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.honey : AppColors.border.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppText.body(
            size: 13,
            weight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.slate500,
          ),
        ),
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, required this.empty, required this.points, this.line = false});

  final String title;
  final String empty;
  final Map<String, double> points;
  final bool line;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.display(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (points.isEmpty)
            SizedBox(
              height: 90,
              child: Center(child: Text(empty, style: AppText.body(size: 13, color: AppColors.slate500))),
            )
          else
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: line ? _LinePainter(points: points) : _BarPainter(points: points),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.points});

  final Map<String, double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.values.toList();
    final max = values.fold<double>(0, (a, b) => a > b ? a : b);
    final top = max <= 0 ? 1.0 : max;
    final paint = Paint()
      ..color = AppColors.navy
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final path = Path();
    final area = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = size.height - (values[i] / top) * (size.height - 16) - 8;
      if (i == 0) {
        path.moveTo(x, y);
        area.moveTo(x, size.height);
        area.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        area.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = AppColors.navy);
    }
    area.lineTo(size.width, size.height);
    area.close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => oldDelegate.points != points;
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.points});

  final Map<String, double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final entries = points.entries.toList();
    final max = entries.fold<double>(0, (a, e) => a > e.value ? a : e.value);
    final top = max <= 0 ? 1.0 : max;
    final gap = 12.0;
    final barW = (size.width - gap * (entries.length + 1)) / entries.length;
    for (var i = 0; i < entries.length; i++) {
      final h = (entries[i].value / top) * (size.height - 22);
      final x = gap + i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h - 16, barW.clamp(12, 64), h),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = AppColors.navy);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) => oldDelegate.points != points;
}

/// Two-per-row grid on phones, more columns as the screen widens — the same
/// responsive filter/tile layout the admin Transactions page uses.
Widget financeGrid(BuildContext context, List<Widget> children) {
  return LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth >= 900 ? 4 : (box.maxWidth >= 520 ? 3 : 2);
      final w = (box.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

Color financeStatusColor(String status) {
  final key = status.toLowerCase();
  if (key.contains('success') || key == 'paid' || key == 'issued') return AppColors.emerald;
  if (key.contains('pend') || key.contains('process')) return AppColors.honeyDark;
  if (key.contains('fail') || key.contains('void') || key.contains('cancel')) return AppColors.rose;
  if (key.contains('refund')) return AppColors.violet;
  return AppColors.slate600;
}

Widget financeEmptyRow(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
    child: Center(child: Text(text, style: AppText.body(size: 13, color: AppColors.slate500))),
  );
}
