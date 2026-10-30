import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import '../widgets/school_letterhead.dart';
import 'admin_forms.dart';
import 'teacher_report_detail.dart';
import '../widgets/assessment_report_sheet.dart';
import '../widgets/report_card_view.dart';

class AcademicReportScreen extends StatefulWidget {
  const AcademicReportScreen({
    super.key,
    required this.user,
    required this.onBack,
    required this.onLogout,
    this.staffView = false,
    this.parentView = false,
  });

  final AppUser user;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final bool staffView;
  final bool parentView;

  @override
  State<AcademicReportScreen> createState() => _AcademicReportScreenState();
}

class _AcademicReportScreenState extends State<AcademicReportScreen> {
  String _tab = 'table';
  String? _openId;
  String _child = 'Class';
  String? _openingId;

  bool get _headmaster => widget.user.role == Role.schoolAdmin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SchoolScope.of(context).refreshReportCards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final classTeacher = widget.user.role == Role.teacher && store.isClassTeacher(widget.user);
    final reports = store.academicReportsFor(
      widget.user.role,
      childName: widget.parentView ? _parentChildName(store) : null,
    );
    final open = reports.where((r) => r.id == _openId).toList();

    if (open.isNotEmpty) {
      return _ReportTablePage(
        report: open.first,
        childFilter: widget.parentView ? _parentChild(store, open.first) : (_child == 'Class' ? (open.first.lines.firstOrNull?.student ?? _child) : _child),
        parentView: widget.parentView,
        isTeacher: widget.user.role == Role.teacher,
        isClassTeacher: classTeacher,
        isHeadmaster: _headmaster,
        isAdmin: widget.user.role.isAdminPortal,
        user: widget.user,
        onBack: () => setState(() => _openId = null),
        onLogout: widget.onLogout,
        onChild: (v) => setState(() => _child = v),
        childNames: widget.parentView
            ? [
                if (store.focusedChild(Role.parent)?.name.isNotEmpty == true) store.focusedChild(Role.parent)!.name,
              ]
            : [for (final s in store.students) s.name],
      );
    }

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
      children: [
        AdminPageHeader(
          title: widget.staffView ? 'Academic reports' : 'Reports',
          subtitle: widget.parentView
              ? 'Official assessment report for ${store.focusedChild(Role.parent)?.name ?? 'your child'}'
              : widget.user.role == Role.teacher
                  ? (classTeacher
                      ? 'Input the class report. Subject teachers send you their records first.'
                      : 'Send your subject records to the class teacher to input the report.')
                  : widget.staffView
                      ? (_headmaster ? 'Review sheets and send to parents' : 'View teacher sheets and send to parents')
                      : 'Fill the assessment sheet and send it to admin',
          onBack: widget.onBack,
          user: widget.user,
          onLogout: widget.onLogout,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              const SchoolLetterhead(compact: true),
              const SizedBox(height: 14),
              if (widget.parentView) ...[
                Text(
                  _parentChildName(store).isEmpty
                      ? 'Reports for the child selected in the header'
                      : 'Reports for ${_parentChildName(store)}',
                  style: AppText.body(size: 13, color: AppSurface.muted(context)),
                ),
                const SizedBox(height: 12),
              ],
              if (!widget.staffView && !widget.parentView)
                WhiteCard(
                  padding: const EdgeInsets.all(4),
                  radius: 12,
                  child: Row(
                    children: [
                      for (final tab in const [('table', 'Academic table'), ('other', 'Other reports')])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _tab = tab.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _tab == tab.$1 ? AppColors.honey : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tab.$2,
                                textAlign: TextAlign.center,
                                style: AppText.body(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: _tab == tab.$1 ? Colors.white : AppColors.slate500,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!widget.staffView && !widget.parentView && _tab == 'other') ...[
                const SizedBox(height: 16),
                Text('Class and exam reports', style: AppText.body(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (store.teacherReports.isEmpty)
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Text('No other reports yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                  )
                else
                  for (final r in store.teacherReports) ...[
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.typeLabel, style: AppText.body(weight: FontWeight.w600)),
                                Text('${r.klass} Â· ${r.subject}', style: AppText.body(size: 12, color: AppColors.slate500)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => showTeacherReportDetail(context, r),
                            child: const Text('View'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ] else ...[
                const SizedBox(height: 16),
                if (!widget.staffView && !widget.parentView && widget.user.role == Role.teacher && classTeacher)
                  HoneyButton(
                    label: 'Input report',
                    icon: Icons.table_chart_outlined,
                    onPressed: () => _compose(store),
                  ),
                // A subject teacher does not fill the final report: their
                // marked work reaches it through the school server.
                if (!widget.staffView && !widget.parentView && widget.user.role == Role.teacher && !classTeacher)
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_graph_rounded, color: AppSurface.brand(context)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your marked homework, assignments, exercises and class tests automatically contribute to the class report. '
                            'The class teacher enters the exam scores and remarks.',
                            style: AppText.body(size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!widget.staffView && !widget.parentView && widget.user.role == Role.teacher) const SizedBox(height: 14),
                Text(
                  store.reportCardsLoading
                      ? 'Loading report cards from the office website…'
                      : (store.reportCardsError ??
                          (reports.isEmpty
                              ? (widget.parentView
                                  ? 'No reports have been sent yet.'
                                  : widget.staffView
                                      ? 'No reports from teachers yet.'
                                      : widget.user.role == Role.teacher
                                          ? 'No report cards from the office website yet.'
                                          : 'No academic reports yet.')
                              : '${reports.length} reports from the office website')),
                  style: AppText.body(size: 12, color: AppColors.slate500),
                ),
                if (store.reportCardsLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                const SizedBox(height: 8),
                if (!store.reportCardsLoading)
                for (final report in reports) ...[
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${report.klass} · ${report.term}${report.year.isEmpty ? '' : ' · ${report.year}'}', style: AppText.body(weight: FontWeight.w700)),
                        Text(
                          widget.parentView
                              ? '${_childLine(report)?.student ?? _parentChildName(store)} · ${report.klass} · ${report.term}'
                              : '${report.teacher} Â· ${report.lines.length} pupil${report.lines.length == 1 ? '' : 's'} Â· ${report.statusLabel}',
                          style: AppText.body(size: 12, color: AppColors.slate500),
                        ),
                        if (widget.parentView) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Opens the official assessment report sheet for this child.',
                            style: AppText.body(size: 12, color: AppColors.slate500),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _openingId != null
                                  ? null
                                  : () async {
                                      setState(() => _openingId = report.id);
                                      await store.hydrateWebsiteReport(report);
                                      if (!mounted) return;
                                      setState(() {
                                        _openingId = null;
                                        _openId = report.id;
                                        if (widget.parentView) {
                                          _child = _childLine(report)?.student ?? _parentChildName(store);
                                        } else {
                                          _child = report.lines.firstOrNull?.student ?? 'Class';
                                        }
                                      });
                                    },
                              child: Text(_openingId == report.id ? 'Opening from website…' : 'View report sheet'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ],
      ),
    );
  }

  String _parentChildName(SchoolStore store) {
    return store.focusedChild(Role.parent)?.name ?? '';
  }

  String _parentChild(SchoolStore store, AcademicReport report) {
    final wanted = _parentChildName(store);
    if (report.lines.any((l) => l.student == wanted)) return wanted;
    return report.lines.firstOrNull?.student ?? wanted;
  }

  ReportLine? _childLine(AcademicReport report) {
    final store = SchoolScope.of(context);
    final name = _parentChildName(store);
    return report.lines.where((l) => l.student == name).firstOrNull ?? report.lines.firstOrNull;
  }

  Future<void> _compose(SchoolStore store) async {
    final rooms = store.homeroomClassesFor(widget.user);
    final classOptions = rooms.isNotEmpty ? [for (final r in rooms) r.name] : store.classNames;
    if (classOptions.isEmpty) {
      showSnack(context, 'No classes from the school API yet. Add classes in the office web app.');
      return;
    }
    var klass = store.focusedClassRecord()?.name ?? classOptions.first;
    if (!classOptions.contains(klass)) klass = classOptions.first;
    var term = store.currentTermLabel;
    final termChoices = store.termLabels;
    if (!termChoices.contains(term)) term = termChoices.first;
    await showAppSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Input class report', style: AppText.display(size: 16, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Enter the official sheet. Use subject records sent to you by other teachers.',
                  style: AppText.body(size: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 12),
                AdminDropdown(
                  label: 'Class',
                  value: klass,
                  items: classOptions,
                  onChanged: (v) => setLocal(() => klass = v),
                ),
                AdminDropdown(
                  label: 'Term',
                  value: term,
                  items: termChoices,
                  onChanged: (v) => setLocal(() => term = v),
                ),
                Text(
                  'Class scores are filled in from the subject teachers\' marked work '
                  '(out of ${store.classScoreWeight}); you enter the exam out of ${100 - store.classScoreWeight} and remarks.',
                  style: AppText.body(size: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 10),
                HoneyButton(
                  label: 'Open report sheet',
                  onPressed: () async {
                    final lines = store.draftReportLines(klass);
                    if (lines.isEmpty) {
                      showSnack(ctx, 'No pupils enrolled in this class.');
                      return;
                    }
                    if (store.academicTermId != null &&
                        store.reportSubjectTemplates.every((s) => s.subjectId.isEmpty)) {
                      showSnack(ctx, 'No subjects from the school API. Add subjects in the office web app.');
                      return;
                    }
                    // Class work calculated on the server from subject teachers' marks.
                    final classId = store.classIdFor(klass) ?? '';
                    final work = await store.fetchClassWork(classId: classId, termId: store.termIdFor(term));
                    if (!ctx.mounted) return;
                    for (final line in lines) {
                      final bySubject = work.scores[line.studentId] ?? const <String, double>{};
                      for (final mark in line.subjects) {
                        final score = bySubject[mark.subjectId];
                        if (score != null) mark.classScore = score.round();
                      }
                    }
                    if (work.error.isNotEmpty) showSnack(ctx, 'Class scores not filled in: ${work.error}');
                    store.upsertAcademicReport(
                      AcademicReport(
                        id: '',
                        klass: klass,
                        term: term,
                        year: store.currentYearLabel,
                        teacher: widget.user.displayName,
                        status: 'draft',
                        submittedAt: 'Draft',
                        classId: store.classIdFor(klass) ?? '',
                        termId: store.termIdFor(term) ?? '',
                        yearId: store.academicYearId ?? '',
                        lines: lines,
                      ),
                      isNew: true,
                    );
                    closeRoute(ctx);
                    setState(() {
                      _openId = store.academicReports.first.id;
                      _child = store.academicReports.first.lines.firstOrNull?.student ?? klass;
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

}

class _ReportTablePage extends StatefulWidget {
  const _ReportTablePage({
    required this.report,
    required this.childFilter,
    required this.isTeacher,
    this.isClassTeacher = false,
    required this.isHeadmaster,
    required this.isAdmin,
    required this.user,
    required this.onBack,
    required this.onLogout,
    required this.onChild,
    this.parentView = false,
    this.childNames = const [],
  });

  final AcademicReport report;
  final String childFilter;
  final bool parentView;
  final bool isTeacher;
  final bool isClassTeacher;
  final bool isHeadmaster;
  final bool isAdmin;
  final AppUser user;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final ValueChanged<String> onChild;
  final List<String> childNames;

  @override
  State<_ReportTablePage> createState() => _ReportTablePageState();
}

class _ReportTablePageState extends State<_ReportTablePage> {
  AcademicReport get report => widget.report;
  bool _hydrating = false;

  bool get _canEditScores => widget.isClassTeacher && !report.sentToAdmin;
  bool get _canEditHead => widget.isHeadmaster && !report.sentToParent;
  bool get _canSendToAdmin => widget.isClassTeacher && !report.sentToAdmin;
  bool get _canSendToParents => widget.isAdmin && report.sentToAdmin && !report.sentToParent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = SchoolScope.of(context);
      final needsLines = report.lines.any((line) => line.cardId.isNotEmpty && line.subjects.isEmpty);
      if (!needsLines) return;
      setState(() => _hydrating = true);
      await store.hydrateWebsiteReport(report);
      if (!mounted) return;
      setState(() => _hydrating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.parentView
        ? [
            for (final name in widget.childNames)
              if (report.lines.any((l) => l.student == name)) name,
          ]
        : [for (final l in report.lines) l.student];
    final selected = names.contains(widget.childFilter) ? widget.childFilter : (names.firstOrNull ?? '');
    final line = report.lines.where((l) => l.student == selected).firstOrNull;
    final store = SchoolScope.of(context);
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
      children: [
        AdminPageHeader(
          title: 'Assessment report',
          subtitle: line == null
              ? '${report.klass} · from office website'
              : '${line.student} · ${report.klass} · ${report.term}',
          onBack: widget.onBack,
          user: widget.user,
          onLogout: widget.onLogout,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              if (_hydrating) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                Text(
                  'Transferring this report from the office website…',
                  style: AppText.body(size: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 12),
              ],
              if (names.length > 1) ...[
                AdminDropdown(
                  label: widget.parentView ? 'Child' : 'Pupil',
                  value: selected,
                  items: names,
                  onChanged: widget.onChild,
                ),
                const SizedBox(height: 10),
              ],
              if (line == null)
                WhiteCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No assessment sheet for this pupil yet.',
                    style: AppText.body(size: 13, color: AppColors.slate500),
                  ),
                )
              else if (_canEditScores || _canEditHead)
                AssessmentReportSheet(
                  report: report,
                  line: line,
                  canEditScores: _canEditScores,
                  canEditHead: _canEditHead,
                  onChanged: () {
                    setState(() {});
                  },
                )
              else
                ReportCardView(
                  report: report,
                  line: line,
                ),
              const SizedBox(height: 12),
              if (widget.isTeacher && report.sentToAdmin && !report.sentToParent)
                Text(
                  'Sent to admin. You can still view this sheet. Parents cannot see it yet.',
                  style: AppText.body(size: 12, color: AppColors.slate500),
                ),
              if (_canSendToAdmin) ...[
                HoneyButton(
                  label: 'Send to admin',
                  onPressed: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    await WidgetsBinding.instance.endOfFrame;
                    if (!context.mounted) return;
                    final error = await store.sendAcademicReportToAdmin(report, from: report.teacher);
                    if (!context.mounted) return;
                    setState(() {});
                    showSnack(
                      context,
                      error.isEmpty ? 'Sent to admin. You can still view this sheet.' : error,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (_canSendToParents) ...[
                HoneyButton(
                  label: 'Send to parents',
                  onPressed: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    await WidgetsBinding.instance.endOfFrame;
                    if (!context.mounted) return;
                    final error = await store.sendAcademicReportToParents(report);
                    if (!context.mounted) return;
                    setState(() {});
                    showSnack(
                      context,
                      error.isEmpty ? 'Sent to parents. They can view this same sheet on the app.' : error,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (widget.parentView)
                Text(
                  'This is the official assessment report sent by the school.',
                  style: AppText.body(size: 12, color: AppColors.slate500),
                ),
              if (report.sentToParent && !widget.parentView)
                Text(
                  'Parents can view this same assessment sheet on the app.',
                  style: AppText.body(size: 12, color: AppColors.slate500),
                ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
