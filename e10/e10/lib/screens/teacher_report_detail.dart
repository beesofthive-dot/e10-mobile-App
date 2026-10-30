import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/popups.dart';

Future<void> showTeacherReportDetail(
  BuildContext context,
  TeacherReport report, {
  bool admin = false,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (ctx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            report.typeLabel,
            style: AppText.display(size: 18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.klass} · Sec ${report.section} · ${report.subject}',
            style: AppText.body(size: 13, color: AppColors.slate500),
          ),
          Text(
            '${report.teacher} · ${report.year} · ${report.term}',
            style: AppText.body(size: 13, color: AppColors.slate500),
          ),
          Text('Submitted ${report.submittedAt}', style: AppText.body(size: 12, color: AppColors.slate400)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => closeRoute(ctx), child: const Text('Close')),
          ),
        ],
      );
    },
  );
}
