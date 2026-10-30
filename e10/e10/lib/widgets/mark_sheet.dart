import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/admin_forms.dart';
import '../theme.dart';
import 'common.dart';
import 'popups.dart';

/// Loads the marks already on the school server for one piece of work.
typedef MarkLoader = Future<({List<Map<String, dynamic>> rows, String error})> Function();

/// Saves the entered marks; returns '' or the reason it failed.
typedef MarkSaver = Future<String> Function(
  double maxScore,
  Map<String, double?> scores,
  List<Map<String, dynamic>> existing,
);

/// Marking sheet for one piece of class work (homework, assignment,
/// exercise or class test): every student in the class with a score box,
/// pre-filled with marks already saved on the school server. Marks go to the
/// server — and from there into the class report's class-work score.
Future<void> showMarkSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<Student> students,
  required MarkLoader load,
  required MarkSaver save,
  double? maxScore,
  bool maxEditable = true,
}) async {
  final maxCtl = TextEditingController(text: maxScore == null ? '10' : _num(maxScore));
  final boxes = {for (final s in students) s.id: TextEditingController()};
  var existing = <Map<String, dynamic>>[];
  var loading = true;
  var loadError = '';
  var started = false;

  await showAppSheet<void>(
    context: context,
    title: title,
    subtitle: subtitle,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        if (!started) {
          started = true;
          load().then((result) {
            existing = result.rows;
            loadError = result.error;
            for (final row in existing) {
              final box = boxes['${row['student_id']}'];
              final score = double.tryParse('${row['score'] ?? ''}');
              if (box != null && score != null) box.text = _num(score);
              final max = double.tryParse('${row['max_score'] ?? ''}');
              if (maxEditable && max != null && max > 0) maxCtl.text = _num(max);
            }
            if (ctx.mounted) setLocal(() => loading = false);
          });
        }

        Future<void> submit() async {
          final max = double.tryParse(maxCtl.text.trim()) ?? 0;
          final scores = <String, double?>{};
          for (final entry in boxes.entries) {
            final raw = entry.value.text.trim();
            if (raw.isEmpty) continue;
            final value = double.tryParse(raw);
            if (value == null) {
              showSnack(ctx, 'Marks must be numbers.');
              return;
            }
            scores[entry.key] = value;
          }
          final error = await save(max, scores, existing);
          if (!ctx.mounted) return;
          if (error.isNotEmpty) {
            showSnack(ctx, error);
            return;
          }
          closeRoute(ctx);
          showSnack(context, 'Marks saved. They count towards the class report.');
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppFieldLabel('Marked out of', required: true),
            TextField(
              controller: maxCtl,
              enabled: maxEditable,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppText.body(size: 13.5),
              decoration: appFieldDecoration(ctx),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
              )
            else ...[
              if (loadError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(loadError, style: AppText.body(size: 12.5, color: AppColors.rose)),
                ),
              if (students.isEmpty)
                Text('No students in this class yet.', style: AppText.body(size: 13, color: AppSurface.muted(context)))
              else
                for (final s in students)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13.5, weight: FontWeight.w600))),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 86,
                          child: TextField(
                            controller: boxes[s.id],
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: AppText.body(size: 13.5, weight: FontWeight.w700),
                            decoration: appFieldDecoration(ctx, hint: '—'),
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 12),
              HoneyButton(label: 'Save marks', onPressed: students.isEmpty ? null : submit),
            ],
          ],
        );
      },
    ),
  );
  disposeAfterClose([maxCtl, ...boxes.values]);
}

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
