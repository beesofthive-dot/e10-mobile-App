import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_forms.dart';
import 'teacher_report_detail.dart';

class TeacherMyReportsScreen extends StatefulWidget {
  const TeacherMyReportsScreen({
    super.key,
    required this.user,
    required this.onBack,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  State<TeacherMyReportsScreen> createState() => _TeacherMyReportsScreenState();
}

class _TeacherMyReportsScreenState extends State<TeacherMyReportsScreen> {
  String _tab = 'mine';

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final mine = store.teacherReports.where((r) => r.teacher == widget.user.displayName).toList();
    return Column(
      children: [
        TopBar(
          title: 'My Reports',
          subtitle: 'Submit class and examination reports',
          onBack: widget.onBack,
          onLogout: widget.onLogout,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              WhiteCard(
                padding: const EdgeInsets.all(4),
                radius: 12,
                child: Row(
                  children: [
                    for (final tab in const [
                      ('mine', 'My reports'),
                      ('class', 'Class report'),
                      ('exam', 'Exam report'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = tab.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: _tab == tab.$1 ? AppGradients.honey : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tab.$2,
                              textAlign: TextAlign.center,
                              style: AppText.body(
                                size: 11,
                                weight: FontWeight.w800,
                                color: _tab == tab.$1 ? Colors.white : AppColors.slate400,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_tab == 'mine')
                ..._list(context, store, mine)
              else
                _SubmitForm(
                  key: ValueKey(_tab),
                  store: store,
                  teacher: widget.user.displayName,
                  exam: _tab == 'exam',
                  onSaved: () => setState(() => _tab = 'mine'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _list(BuildContext context, SchoolStore store, List<TeacherReport> mine) {
    if (mine.isEmpty) {
      return [
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Text('You have not submitted a report yet.', style: AppText.body(color: AppColors.slate500)),
        ),
      ];
    }
    return [
      for (final report in mine) ...[
        WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(report.typeLabel, style: AppText.body(weight: FontWeight.w800))),
                  StatusBadge(
                    text: report.statusLabel,
                    tone: report.status == TeacherReportStatus.returned ? Tone.rose : Tone.honey,
                  ),
                ],
              ),
              Text(
                '${report.klass} · ${report.subject} · ${report.term}',
                style: AppText.body(size: 12, color: AppColors.slate500),
              ),
              if (report.adminFeedback.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Feedback: ${report.adminFeedback}', style: AppText.body(size: 12, color: Tone.rose.softText)),
                ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => showTeacherReportDetail(context, report),
                    child: const Text('View'),
                  ),
                  if (report.status == TeacherReportStatus.draft || report.status == TeacherReportStatus.returned)
                    TextButton(
                      onPressed: () {
                        store.upsertTeacherReport(
                          report
                            ..status = TeacherReportStatus.submitted
                            ..submittedAt = 'Just now',
                        );
                        showSnack(context, 'Report resubmitted');
                      },
                      child: const Text('Resubmit'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _SubmitForm extends StatefulWidget {
  const _SubmitForm({
    super.key,
    required this.store,
    required this.teacher,
    required this.exam,
    required this.onSaved,
  });

  final SchoolStore store;
  final String teacher;
  final bool exam;
  final VoidCallback onSaved;

  @override
  State<_SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends State<_SubmitForm> {
  late String _year;
  late String _term;
  late String _klass;
  late String _subject;
  final _performance = TextEditingController();
  final _progress = TextEditingController();
  final _participation = TextEditingController();
  final _attendance = TextEditingController();
  final _behaviour = TextEditingController();
  final _strengths = TextEditingController();
  final _challenges = TextEditingController();
  final _done = TextEditingController();
  final _pending = TextEditingController();
  final _recommend = TextEditingController();
  final _comments = TextEditingController();
  final _examName = TextEditingController();
  late final TextEditingController _examDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    _examDate = TextEditingController(text: '${now.day} ${months[now.month - 1]} ${now.year}');
    // The school's own current year and term from the API.
    final years = widget.store.yearLabels;
    final current = widget.store.currentYearLabel;
    _year = current.isNotEmpty ? current : (years.firstOrNull ?? '');
    _term = widget.store.currentTermLabel;
    _klass = widget.store.classNames.firstOrNull ?? '';
    _subject = widget.store.subjectNames.firstOrNull ?? '';
  }

  @override
  void dispose() {
    _performance.dispose();
    _progress.dispose();
    _participation.dispose();
    _attendance.dispose();
    _behaviour.dispose();
    _strengths.dispose();
    _challenges.dispose();
    _done.dispose();
    _pending.dispose();
    _recommend.dispose();
    _comments.dispose();
    _examName.dispose();
    _examDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.store.examStatsFor(klass: _klass, subject: _subject, term: _term);
    final count = widget.store.studentsIn(_klass);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.exam ? 'Submit Examination Report' : 'Submit Class Report',
          style: AppText.display(size: 18),
        ),
        const SizedBox(height: 12),
        AdminDropdown(label: 'Academic Year', value: _year, items: {...widget.store.yearLabels, if (_year.isNotEmpty) _year}.toList(), onChanged: (v) => setState(() => _year = v)),
        AdminDropdown(label: 'Term', value: _term, items: {...widget.store.termLabels, _term}.toList(), onChanged: (v) => setState(() => _term = v)),
        AdminDropdown(label: 'Class', value: _klass, items: widget.store.classNames, onChanged: (v) => setState(() => _klass = v)),
        AdminDropdown(label: 'Subject', value: _subject, items: widget.store.subjectNames, onChanged: (v) => setState(() => _subject = v)),
        _Locked('Teacher / class teacher', widget.teacher),
        _Locked('Section', SchoolStore.sectionOf(_klass)),
        _Locked('Number of students', '$count (from school records)'),
        if (widget.exam) ...[
          AdminField(label: 'Examination name', controller: _examName),
          AdminField(label: 'Examination date', controller: _examDate),
          if (stats.wrote > 0) ...[
            _Locked('Wrote / passed / failed', '${stats.wrote} / ${stats.passed} / ${stats.failed}'),
            _Locked('Highest / lowest / average', '${stats.highest} / ${stats.lowest} / ${stats.average.toStringAsFixed(1)}'),
            _Locked('Pass percentage', '${stats.passPercent.toStringAsFixed(0)}% (from recorded marks)'),
          ] else
            Text('No marks found yet for this class and subject. Submit the exam list in Academics first.', style: AppText.body(size: 12, color: AppColors.honeyDark)),
        ],
        AdminField(label: 'General class / student performance', controller: _performance),
        if (!widget.exam) ...[
          AdminField(label: 'Academic progress', controller: _progress),
          AdminField(label: 'Student participation', controller: _participation),
          AdminField(label: 'Attendance observations', controller: _attendance),
          AdminField(label: 'Behaviour and discipline', controller: _behaviour),
          AdminField(label: 'Strengths of the class', controller: _strengths),
          AdminField(label: 'Topics completed', controller: _done),
          AdminField(label: 'Topics not completed', controller: _pending),
        ] else ...[
          AdminField(label: 'Topics students performed well in', controller: _done),
          AdminField(label: 'Topics students struggled with', controller: _pending),
        ],
        AdminField(label: 'Challenges faced', controller: _challenges),
        AdminField(label: 'Recommendations', controller: _recommend),
        AdminField(label: "Teacher's comments", controller: _comments),
        HoneyButton(
          label: 'Submit report',
          onPressed: () async {
            FocusManager.instance.primaryFocus?.unfocus();
            await WidgetsBinding.instance.endOfFrame;
            if (!mounted) return;
            final report = TeacherReport(
              id: '',
              type: widget.exam ? TeacherReportType.examReport : TeacherReportType.classReport,
              year: _year,
              term: _term,
              klass: _klass,
              section: SchoolStore.sectionOf(_klass),
              teacher: widget.teacher,
              subject: _subject,
              status: TeacherReportStatus.submitted,
              submittedAt: 'Just now',
              studentCount: count,
              examName: _examName.text.trim(),
              examDate: _examDate.text.trim(),
              performance: _performance.text.trim(),
              progress: _progress.text.trim(),
              participation: _participation.text.trim(),
              attendanceNotes: _attendance.text.trim(),
              behaviour: _behaviour.text.trim(),
              strengths: _strengths.text.trim(),
              challenges: _challenges.text.trim(),
              topicsDone: _done.text.trim(),
              topicsPending: _pending.text.trim(),
              recommendations: _recommend.text.trim(),
              comments: _comments.text.trim(),
            );
            widget.store.upsertTeacherReport(report, isNew: true);
            if (!context.mounted) return;
            showSnack(context, 'Report submitted to admin');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onSaved();
            });
          },
        ),
      ],
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.slate500)),
          const SizedBox(height: 4),
          Text(value, style: AppText.body(weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
