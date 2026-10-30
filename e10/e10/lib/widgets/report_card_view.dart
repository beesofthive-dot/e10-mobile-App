import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import 'school_letterhead.dart';

/// Clean, read-only report card shown to parents (and to teachers/admins once
/// a report has been finalized) — mirrors the office website's own report
/// card page rather than the editable GES assessment sheet used for input.
class ReportCardView extends StatelessWidget {
  const ReportCardView({
    super.key,
    required this.report,
    required this.line,
  });

  final AcademicReport report;
  final ReportLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppSurface.line(context)),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SchoolLetterhead(),
          const SizedBox(height: 14),
          _title(context),
          const SizedBox(height: 16),
          _summaryRow(context),
          const SizedBox(height: 16),
          if (line.remark.isNotEmpty || line.headteacherRemark.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (line.remark.isNotEmpty) _remarkBlock(context, 'TEACHER REMARK', line.remark),
            if (line.headteacherRemark.isNotEmpty) ...[
              const SizedBox(height: 10),
              _remarkBlock(context, 'HEADTEACHER REMARK', line.headteacherRemark),
            ],
          ],
          const SizedBox(height: 16),
          _scoreTable(context),
          const SizedBox(height: 16),
          _resultsSummary(context),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) {
    return Text(
      'Report card — ${line.student} · ${report.term}',
      style: AppText.display(
        size: 21,
        weight: FontWeight.w700,
        color: AppSurface.text(context),
      ).copyWith(fontFamily: 'serif'),
    );
  }

  String _issuedLabel(String raw) {
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.split('T').first;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  Widget _summaryRow(BuildContext context) {
    final made = int.tryParse(line.attendanceMade);
    final outOf = int.tryParse(line.attendanceOutOf);
    final attendance = (made != null && outOf != null && outOf > 0)
        ? '$made/$outOf (${(made * 100 / outOf).round()}%)'
        : '—';
    final promotion = line.promotedTo.isNotEmpty
        ? line.promotedTo
        : line.promote == true
            ? 'Promoted'
            : '—';
    return Wrap(
      spacing: 32,
      runSpacing: 14,
      children: [
        _summaryItem(context, 'CLASS', report.klass.isEmpty ? '—' : report.klass),
        _summaryItem(context, 'ACADEMIC YEAR', report.year.isEmpty ? '—' : report.year),
        _summaryItem(context, 'ISSUED', _issuedLabel(report.submittedAt)),
        _summaryItem(context, 'ATTENDANCE', attendance),
        _summaryItem(context, 'PROMOTION', promotion),
      ],
    );
  }

  /// GES letter grade for an average score, matching the same bands
  /// ReportLine.retakeGrade() already uses when the API hasn't computed
  /// (or hasn't yet returned) its own overall grade for this report.
  String _bandGrade(int average) {
    if (average >= 80) return 'A';
    if (average >= 70) return 'B';
    if (average >= 60) return 'C';
    if (average >= 50) return 'D';
    return 'F';
  }

  Widget _resultsSummary(BuildContext context) {
    if (line.subjects.isEmpty) return const SizedBox.shrink();
    final totalMarks = line.subjects.fold<int>(0, (sum, m) => sum + m.total);
    final average = line.overall;
    final overallGrade = line.grade.isNotEmpty && line.grade != '—' ? line.grade : _bandGrade(average);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppSurface.cardSoft(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SUMMARY', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppSurface.muted(context), letterSpacing: 0.3)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _summaryItem(context, 'TOTAL SUBJECTS', '${line.subjects.length}'),
              _summaryItem(context, 'TOTAL MARKS', '$totalMarks'),
              _summaryItem(context, 'AVERAGE', '$average'),
              _summaryItem(context, 'OVERALL GRADE', overallGrade),
              _summaryItem(context, 'POSITION', line.position.isEmpty ? '—' : line.position),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: AppSurface.muted(context), letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value, style: AppText.display(size: 15, weight: FontWeight.w700, color: AppSurface.text(context))),
      ],
    );
  }

  // Below this width the six-column table can't fit without horizontal
  // scrolling, so phones get a single stacked results list instead — still
  // ONE bordered section for every subject (divided by rules, not separate
  // per-subject cards), so it still reads as one unified report rather than
  // a grid of independent subject report cards.
  static const _tableMinWidth = 560.0;

  Widget _scoreTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _tableMinWidth) {
          return _subjectList(context);
        }
        return _subjectTable(context);
      },
    );
  }

  Widget _subjectList(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppSurface.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppSurface.cardSoft(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              'SUBJECT RESULTS',
              style: AppText.body(size: 11, weight: FontWeight.w700, color: AppSurface.muted(context), letterSpacing: 0.3),
            ),
          ),
          for (final mark in line.subjects) _subjectRow(context, mark),
        ],
      ),
    );
  }

  Widget _subjectRow(BuildContext context, ReportSubjectMark mark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppSurface.line(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mark.subject, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.text(context))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _miniStat(context, 'CLASS', mark.classScore == 0 ? '—' : '${mark.classScore}'),
              _miniStat(context, 'EXAM', mark.examScore == 0 ? '—' : '${mark.examScore}'),
              _miniStat(context, 'TOTAL', '${mark.total}'),
              _miniStat(context, 'GRADE', mark.grade == '—' || mark.grade.isEmpty ? '—' : mark.grade),
            ],
          ),
          if (mark.remark.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(mark.remark, style: AppText.body(size: 12, color: AppSurface.muted(context))),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(size: 10, weight: FontWeight.w700, color: AppSurface.muted(context), letterSpacing: 0.3)),
        Text(value, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.text(context))),
      ],
    );
  }

  Widget _subjectTable(BuildContext context) {
    const headers = ['SUBJECT', 'CLASS SCORE', 'EXAM SCORE', 'TOTAL', 'GRADE', 'REMARK'];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppSurface.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.6),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(0.8),
          4: FlexColumnWidth(0.8),
          5: FlexColumnWidth(1.6),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: AppSurface.cardSoft(context)),
            children: [
              for (final h in headers)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Text(
                    h,
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: AppSurface.muted(context), letterSpacing: 0.2),
                  ),
                ),
            ],
          ),
          for (final mark in line.subjects)
            TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppSurface.line(context))),
              ),
              children: [
                _cell(context, mark.subject, weight: FontWeight.w600),
                _cell(context, mark.classScore == 0 ? '—' : '${mark.classScore}'),
                _cell(context, mark.examScore == 0 ? '—' : '${mark.examScore}'),
                _cell(context, '${mark.total}', weight: FontWeight.w700),
                _cell(context, mark.grade == '—' || mark.grade.isEmpty ? '—' : mark.grade, weight: FontWeight.w700),
                _cell(context, mark.remark.isEmpty ? '—' : mark.remark),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String value, {FontWeight weight = FontWeight.w400}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(value, style: AppText.body(size: 13, weight: weight, color: AppSurface.text(context)), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _remarkBlock(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: AppSurface.muted(context), letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value, style: AppText.body(size: 13, color: AppSurface.text(context))),
      ],
    );
  }
}
