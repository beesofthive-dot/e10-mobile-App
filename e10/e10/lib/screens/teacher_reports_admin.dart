import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';
import 'teacher_report_detail.dart';

class TeacherReportsAdminScreen extends StatefulWidget {
  const TeacherReportsAdminScreen({super.key, required this.onBack, required this.onLogout});

  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  State<TeacherReportsAdminScreen> createState() => _TeacherReportsAdminScreenState();
}

class _TeacherReportsAdminScreenState extends State<TeacherReportsAdminScreen> {
  String _year = 'All';
  String _term = 'All';
  String _klass = 'All';
  String _section = 'All';
  String _subject = 'All';
  String _teacher = 'All';
  String _type = 'All';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final filtered = store.teacherReports.where((r) {
      final q = _query.toLowerCase();
      return (_year == 'All' || r.year == _year) &&
          (_term == 'All' || r.term == _term) &&
          (_klass == 'All' || r.klass == _klass) &&
          (_section == 'All' || r.section == _section) &&
          (_subject == 'All' || r.subject == _subject) &&
          (_teacher == 'All' || r.teacher == _teacher) &&
          (_type == 'All' || r.typeLabel == _type) &&
          (q.isEmpty ||
              r.teacher.toLowerCase().contains(q) ||
              r.klass.toLowerCase().contains(q) ||
              r.subject.toLowerCase().contains(q) ||
              r.examName.toLowerCase().contains(q));
    }).toList();

    return Column(
      children: [
        TopBar(
          title: 'Teacher Reports',
          subtitle: 'Every class, teacher and term',
          onBack: widget.onBack,
          onLogout: widget.onLogout,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              _SummaryRow(reports: store.teacherReports),
              const SizedBox(height: 14),
              AdminDropdown(label: 'Academic Year', value: _year, items: const ['All', '2025/26', '2026/27'], onChanged: (v) => setState(() => _year = v)),
              AdminDropdown(label: 'Term', value: _term, items: const ['All', 'Term 1', 'Term 2', 'Term 3'], onChanged: (v) => setState(() => _term = v)),
              AdminDropdown(label: 'Class', value: _klass, items: ['All', ...store.classNames], onChanged: (v) => setState(() => _klass = v)),
              AdminDropdown(label: 'Section', value: _section, items: const ['All', 'A', 'B', 'C'], onChanged: (v) => setState(() => _section = v)),
              AdminDropdown(label: 'Subject', value: _subject, items: ['All', ...store.subjectNames], onChanged: (v) => setState(() => _subject = v)),
              AdminDropdown(label: 'Teacher', value: _teacher, items: ['All', ...store.teacherNames], onChanged: (v) => setState(() => _teacher = v)),
              AdminDropdown(label: 'Report Type', value: _type, items: const ['All', 'Class Report', 'Examination Report'], onChanged: (v) => setState(() => _type = v)),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search teacher, class or subject',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.icon),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('${filtered.length} reports', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.slate400)),
              const SizedBox(height: 8),
              for (final report in filtered) ...[
                WhiteCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(report.typeLabel, style: AppText.body(weight: FontWeight.w800)),
                          ),
                          StatusBadge(text: report.statusLabel, tone: _tone(report.status)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.klass} · Sec ${report.section} · ${report.subject}',
                        style: AppText.body(size: 12, color: AppColors.slate500),
                      ),
                      Text(
                        '${report.teacher} · ${report.year} · ${report.term} · ${report.submittedAt}',
                        style: AppText.body(size: 11, color: AppColors.slate400),
                      ),
                      const SizedBox(height: 8),
                      ActionMenuButton(
                        title: report.typeLabel,
                        actions: [
                          SheetAction(
                            label: 'View Report',
                            icon: Icons.visibility_rounded,
                            onTap: () => showTeacherReportDetail(context, report, admin: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Tone _tone(TeacherReportStatus status) => switch (status) {
        TeacherReportStatus.approved => Tone.emerald,
        TeacherReportStatus.returned => Tone.rose,
        TeacherReportStatus.reviewed => Tone.sky,
        TeacherReportStatus.submitted => Tone.honey,
        TeacherReportStatus.draft => Tone.slate,
      };
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.reports});
  final List<TeacherReport> reports;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Total', '${reports.length}', AppColors.slate800),
      ('Class', '${reports.where((r) => r.type == TeacherReportType.classReport).length}', AppColors.slate800),
      ('Exams', '${reports.where((r) => r.type == TeacherReportType.examReport).length}', AppColors.slate800),
      ('Pending', '${reports.where((r) => r.status == TeacherReportStatus.submitted || r.status == TeacherReportStatus.reviewed).length}', AppColors.honeyDark),
      ('Approved', '${reports.where((r) => r.status == TeacherReportStatus.approved).length}', AppColors.emerald),
      ('Returned', '${reports.where((r) => r.status == TeacherReportStatus.returned).length}', AppColors.slate700),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in cards)
          SizedBox(
            width: 104,
            child: WhiteCard(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.$2, style: AppText.display(size: 18, weight: FontWeight.w600, color: c.$3)),
                  Text(c.$1, style: AppType.caption),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
