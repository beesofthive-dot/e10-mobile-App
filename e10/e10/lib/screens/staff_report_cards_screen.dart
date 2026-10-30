import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../api/api_session.dart';
import '../core/config/api_config.dart';
import '../core/receipt_file.dart';
import '../feeding.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/feeding_widgets.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart' show showSnack;
import 'parent_report_cards_screen.dart' show ReportCardDetail;

/// Report cards for staff, copied from the website's Report cards page:
/// a class teacher fills in cards for their own class (current term) and
/// submits them for review; an admin publishes them (one card or a whole
/// class), grants edit access and deletes. Parents see published cards.
class StaffReportCardsScreen extends StatefulWidget {
  const StaffReportCardsScreen({super.key, required this.user, this.onBack, required this.onLogout});

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<StaffReportCardsScreen> createState() => _StaffReportCardsScreenState();
}

/// Everything the page and its form need, loaded once per refresh.
class _Lookups {
  List<Map<String, dynamic>> students = const [];
  List<Map<String, dynamic>> terms = const [];
  List<Map<String, dynamic>> subjects = const [];
  List<Map<String, dynamic>> classes = const [];
  List<Map<String, dynamic>> assignments = const [];
  Map<String, String> classOfStudent = const {};
  List<Map<String, dynamic>> editRequests = const [];
}

String _className(Map<String, dynamic> c) => [textOf(c['name']), textOf(c['stream'])].whereType<String>().join(' ');

class _StaffReportCardsScreenState extends State<StaffReportCardsScreen> {
  final _api = ApiClient.instance;
  final _search = TextEditingController();
  final _lk = _Lookups();
  List<Map<String, dynamic>> _cards = [];
  String _classFilter = '';
  String _termFilter = '';
  bool _loading = true;
  String? _error;
  final Set<String> _selected = {};
  String? _busy;
  Timer? _debounce;

  bool _can(String p) => widget.user.permissions.contains(p);
  bool get _create => _can('report-cards.create');
  bool get _update => _can('report-cards.update');
  bool get _delete => _can('report-cards.delete');
  bool get _publish => _can('report-cards.publish');

  String? get _staffId {
    final staff = ApiSession.instance.user?['staff'];
    return staff is Map ? textOf(staff['id']) : null;
  }

  /// A teacher with no office role only works on their own class, current
  /// term — as on the website.
  bool get _classTeacherMode {
    if (_staffId == null) return false;
    const office = {'school_admin', 'deputy_admin', 'registrar', 'bursar', 'attendance_officer'};
    return !widget.user.roleSlugs.any(office.contains);
  }

  bool _teaches(Map<String, dynamic> c) {
    final id = _staffId;
    if (id == null) return false;
    final ids = c['teacher_ids'];
    if (ids is List && ids.map((e) => '$e').contains(id)) return true;
    final teachers = c['teachers'];
    return teachers is List && teachers.any((t) => t is Map && '${t['id']}' == id);
  }

  List<Map<String, dynamic>> get _myClasses => [for (final c in _lk.classes) if (_teaches(c)) c];

  Map<String, dynamic>? get _currentTerm => _lk.terms.where((t) => t['status'] == 'current').firstOrNull;

  /// Students a class teacher may write cards for (enrolled in their class).
  List<Map<String, dynamic>> get _myStudents {
    final mine = {for (final c in _myClasses) '${c['id']}'};
    return [for (final s in _lk.students) if (mine.contains(_lk.classOfStudent['${s['id']}'])) s];
  }

  List<Map<String, dynamic>> get _formStudents => _classTeacherMode ? _myStudents : _lk.students;
  List<Map<String, dynamic>> get _formTerms => _classTeacherMode ? [if (_currentTerm != null) _currentTerm!] : _lk.terms;
  bool get _mayCreateHere => !_classTeacherMode || _myClasses.isNotEmpty;

  bool _published(Map<String, dynamic> c) => c['published'] == true || textOf(c['published_at']) != null;

  /// Whether this card is in the user's reach (class teachers: own class,
  /// current term).
  bool _inReach(Map<String, dynamic> c) {
    if (!_classTeacherMode) return true;
    if (!_myStudents.any((s) => '${s['id']}' == '${c['student_id']}')) return false;
    final term = c['academic_term'];
    return '${c['academic_term_id']}' == '${_currentTerm?['id']}' || (term is Map && term['status'] == 'current');
  }

  bool _canEdit(Map<String, dynamic> c) =>
      _update && _inReach(c) && (!_published(c) || _publish || c['has_active_edit_unlock'] == true);

  bool _submittable(Map<String, dynamic> c) =>
      _update && !_publish && _inReach(c) && !_published(c) && c['submitted'] != true;

  String _student(Map<String, dynamic> c) =>
      textOf(c['student'] is Map ? (c['student'] as Map)['full_name'] : null) ?? textOf(c['student_id']) ?? 'Student';

  String _term(Map<String, dynamic> c) =>
      textOf(c['academic_term'] is Map ? (c['academic_term'] as Map)['name'] : null) ?? textOf(c['academic_term_id']) ?? 'Term';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic body) => FeedingApi.rows(body is Map ? body['data'] : body);

  /// Every page of a list (the website pages through these too).
  Future<List<Map<String, dynamic>>> _all(String path, [Map<String, String> query = const {}]) async {
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= 10; page++) {
      final body = await _api.get(path, query: {...query, 'per_page': '100', 'page': '$page'});
      out.addAll(_rows(body));
      final meta = body is Map && body['meta'] is Map ? body['meta'] as Map : const {};
      if (page >= intOf(meta['last_page'])) break;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _safe(Future<List<Map<String, dynamic>>> f) => f.catchError((_) => <Map<String, dynamic>>[]);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = {
        'per_page': '50',
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        if (_classFilter.isNotEmpty) 'class_id': _classFilter,
        if (_termFilter.isNotEmpty) 'academic_term_id': _termFilter,
      };
      final results = await Future.wait([
        _api.get(ApiConfig.reportCardsPath, query: query).then(_rows),
        _safe(_all('students')),
        _safe(_all('academic-terms')),
        _safe(_all('subjects')),
        _safe(_all('school-classes')),
        _safe(_all('teacher-subject-assignments')),
        _safe(_all('enrollments', {'status': 'active'})),
        _publish ? _safe(_all('report-card-edit-requests', {'status': 'pending'})) : Future.value(<Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _cards = results[0];
        _lk.students = [...results[1]]..sort((a, b) => '${a['full_name']}'.compareTo('${b['full_name']}'));
        _lk.terms = results[2];
        _lk.subjects = [...results[3]]..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
        _lk.classes = results[4];
        _lk.assignments = results[5];
        _lk.classOfStudent = {for (final e in results[6]) '${e['student_id']}': '${e['class_id']}'};
        _lk.editRequests = results[7];
        _selected.removeWhere((id) => !_cards.any((c) => '${c['id']}' == id));
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load report cards. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(String key, Future<void> Function() run, String done) async {
    setState(() => _busy = key);
    try {
      await run();
      if (mounted) showSnack(context, done);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _pdf(Map<String, dynamic> c) async {
    setState(() => _busy = 'pdf-${c['id']}');
    try {
      final bytes = await _api.getBytes(ApiConfig.url('report-cards/${c['id']}/pdf'), accept: 'application/pdf');
      await openPdfBytes(bytes, 'report-card-${_student(c)}-${_term(c)}');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the report card PDF. $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _view(Map<String, dynamic> c) => showAppSheet<void>(
        context: context,
        title: 'Report card',
        subtitle: '${_student(c)} · ${_term(c)}',
        builder: (_) => ReportCardDetail(id: '${c['id']}', onPdf: () => _pdf(c)),
      );

  Future<void> _openForm([Map<String, dynamic>? card]) async {
    Map<String, dynamic>? full;
    if (card != null) {
      try {
        final body = await _api.get('${ApiConfig.reportCardsPath}/${card['id']}');
        full = body is Map && body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : null;
      } catch (e) {
        if (mounted) showSnack(context, 'Could not load the report card. $e');
        return;
      }
    }
    if (!mounted) return;
    final saved = await showAppSheet<bool>(
      context: context,
      title: card == null ? 'Create report card' : 'Edit report card',
      builder: (_) => _ReportCardForm(
        card: full,
        students: _formStudents,
        terms: _formTerms,
        classes: _lk.classes,
        subjects: _lk.subjects,
        assignments: _lk.assignments,
        classOfStudent: _lk.classOfStudent,
        classTeacherMode: _classTeacherMode,
        myClassNames: _myClasses.map(_className).join(', '),
        hasCurrentTerm: _currentTerm != null,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _requestEdit(Map<String, dynamic> c) async {
    final reason = TextEditingController();
    final ok = await showAppSheet<bool>(
      context: context,
      title: 'Request edit access',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_student(c)}’s report card is already published. Explain what needs fixing — an admin will review and, if they agree, grant you one edit.',
              style: AppText.body(size: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 12),
            const AppFieldLabel("What's wrong?", required: true),
            TextField(
              controller: reason,
              maxLines: 3,
              decoration: appFieldDecoration(ctx, hint: 'e.g. Wrong grade entered for Math — should be B, not C.'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            AppModalButton(label: 'Send request', onPressed: reason.text.trim().isEmpty ? null : () => closeRoute(ctx, true)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _act(
      'req-${c['id']}',
      () => _api.post('${ApiConfig.reportCardsPath}/${c['id']}/edit-requests', {'reason': reason.text.trim()}),
      'Edit request sent — you can make one change once it’s approved.',
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final ok = await showAppConfirm(
      context: context,
      title: 'Delete report card?',
      message: 'Delete the report card for ${_student(c)} (${_term(c)})? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok) await _act('del-${c['id']}', () => _api.delete('${ApiConfig.reportCardsPath}/${c['id']}'), 'Report card deleted');
  }

  Future<void> _publishClass() async {
    final term = _termFilter.isNotEmpty ? _termFilter : '${_currentTerm?['id'] ?? ''}';
    if (_classFilter.isEmpty || term.isEmpty) {
      showSnack(context, 'Select a class and term before publishing the class');
      return;
    }
    final klass = _lk.classes.where((c) => '${c['id']}' == _classFilter).firstOrNull;
    final termName = _lk.terms.where((t) => '${t['id']}' == term).firstOrNull?['name'] ?? 'the selected term';
    final ok = await showAppConfirm(
      context: context,
      title: 'Publish class report cards?',
      message: 'Publish all draft report cards for ${klass == null ? 'this class' : _className(klass)} in $termName? Already published cards are skipped.',
      confirmLabel: 'Publish class',
    );
    if (!ok) return;
    await _act('class', () => _api.post('${ApiConfig.reportCardsPath}/publish-class', {'class_id': _classFilter, 'academic_term_id': term}),
        'Class report cards published');
  }

  /// Website's "Fill class from assessments": draft cards are created where
  /// missing; typed scores and published cards are left alone.
  Future<void> _fillClass() async {
    final term = _termFilter.isNotEmpty ? _termFilter : '${_currentTerm?['id'] ?? ''}';
    if (_classFilter.isEmpty || term.isEmpty) {
      showSnack(context, 'Select a class and term first');
      return;
    }
    final klass = _lk.classes.where((c) => '${c['id']}' == _classFilter).firstOrNull;
    final ok = await showAppConfirm(
      context: context,
      title: 'Fill the class from assessments?',
      message:
          "Fill every student's report card for ${klass == null ? 'this class' : _className(klass)} from their recorded assessments. Draft cards are created where missing; scores typed by hand and published cards are left as they are.",
      confirmLabel: 'Fill class',
    );
    if (!ok) return;
    await _act('fill', () => _api.post('${ApiConfig.reportCardsPath}/fill-class', {'class_id': _classFilter, 'academic_term_id': term}),
        'Class filled from assessments');
  }

  Future<void> _submitSelected() async {
    final ids = _selected.toList();
    await _act('bulk', () async {
      var failed = 0;
      for (final id in ids) {
        try {
          await _api.post('${ApiConfig.reportCardsPath}/$id/submit');
        } catch (_) {
          failed++;
        }
      }
      _selected.clear();
      if (failed > 0) throw Exception('$failed report card${failed == 1 ? '' : 's'} could not be submitted');
    }, '${ids.length} report card${ids.length == 1 ? '' : 's'} marked ready for review');
  }

  Widget _picker(String label, String value, List<(String, String)> options, ValueChanged<String> onChanged) => SizedBox(
        width: 170,
        child: AppSelect(
          label: label,
          value: options.firstWhere((o) => o.$1 == value, orElse: () => options.first).$2,
          items: [for (final o in options) o.$2],
          onChanged: (picked) {
            onChanged(options.firstWhere((o) => o.$2 == picked).$1);
            _load();
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final filterClasses = _classTeacherMode ? _myClasses : _lk.classes;
    final filterTerms = _classTeacherMode ? [if (_currentTerm != null) _currentTerm!] : _lk.terms;
    final submittable = _cards.where(_submittable).toList();
    return Column(
      children: [
        AdminPageHeader(
          title: 'Report cards',
          subtitle: _classTeacherMode ? 'Fill in your class’s report cards' : 'Review, publish and send to parents',
          onBack: widget.onBack,
          trailing: SchoolMarkButton(user: widget.user, onLogout: widget.onLogout, light: true),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppLayout.page(context),
              children: [
                if (_error != null) ...[MutedText(_error!), const SizedBox(height: 12)],
                if (_publish && _lk.editRequests.isNotEmpty) ...[_editRequestsCard(), const SizedBox(height: 14)],
                CounterSection(
                  title: 'Report cards',
                  action: SmallAction(label: 'Refresh', icon: Icons.refresh_rounded, onTap: _load),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_create && _mayCreateHere) ...[
                        FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Create report card')),
                        const SizedBox(height: 10),
                      ],
                      if (_classTeacherMode && !_mayCreateHere)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: MutedText('Only class teachers can create report cards. Ask an admin to assign you as class teacher for a class.', size: 12.5),
                        ),
                      TextField(
                        controller: _search,
                        onChanged: (_) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 300), _load);
                        },
                        decoration: appFieldDecoration(context, hint: 'Search by student…').copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 18)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          _picker('Class', _classFilter, [('', 'All classes'), for (final c in filterClasses) ('${c['id']}', _className(c))], (v) => _classFilter = v),
                          _picker('Term', _termFilter, [
                            ('', 'All terms'),
                            for (final t in filterTerms) ('${t['id']}', '${t['name'] ?? ''}${t['status'] == 'current' ? ' (current)' : ''}'),
                          ], (v) => _termFilter = v),
                        ],
                      ),
                      if (_create && _classFilter.isNotEmpty && (!_classTeacherMode || _myClasses.any((c) => '${c['id']}' == _classFilter)))
                        OutlinedButton.icon(
                          onPressed: _busy == 'fill' ? null : _fillClass,
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                          label: Text(_busy == 'fill' ? 'Filling…' : 'Fill class from assessments'),
                        ),
                      if (_publish && _classFilter.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: _busy == 'class' ? null : _publishClass,
                          icon: const Icon(Icons.campaign_outlined, size: 16),
                          label: Text(_busy == 'class' ? 'Publishing…' : 'Publish class'),
                        ),
                      if (submittable.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                          decoration: BoxDecoration(color: AppSurface.cardSoft(context), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Checkbox(
                                value: submittable.every((c) => _selected.contains('${c['id']}')),
                                onChanged: (on) => setState(() {
                                  if (on == true) {
                                    _selected.addAll(submittable.map((c) => '${c['id']}'));
                                  } else {
                                    _selected.clear();
                                  }
                                }),
                              ),
                              Expanded(
                                child: MutedText(_selected.isNotEmpty
                                    ? '${_selected.length} selected'
                                    : '${submittable.length} draft${submittable.length == 1 ? '' : 's'} ready to submit'),
                              ),
                              FilledButton(
                                onPressed: _selected.isEmpty || _busy == 'bulk' ? null : _submitSelected,
                                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: Text(_busy == 'bulk' ? 'Submitting…' : 'Submit ${_selected.isEmpty ? '' : _selected.length} for review'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (_loading && _cards.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
                        )
                      else if (_cards.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: MutedText(_search.text.trim().isNotEmpty ? 'No matching report cards' : 'No report cards')),
                        ),
                      for (final c in _cards) _row(c, submittable.contains(c)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _editRequestsCard() => CounterSection(
        title: 'Pending edit requests (${_lk.editRequests.length})',
        child: Column(
          children: [
            for (final r in _lk.editRequests)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: AppSurface.line(context)), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      () {
                        final rc = r['report_card'] is Map ? r['report_card'] as Map<String, dynamic> : const <String, dynamic>{};
                        return '${_student(rc)} · ${_term(rc)}';
                      }(),
                      style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context)),
                    ),
                    MutedText(
                      'Requested by ${textOf(r['requested_by'] is Map ? (r['requested_by'] as Map)['full_name'] : null) ?? 'a teacher'}: “${r['reason'] ?? ''}”',
                      size: 12.5,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _busy == 'er-${r['id']}'
                              ? null
                              : () => _act('er-${r['id']}', () => _api.post('report-card-edit-requests/${r['id']}/deny'), 'Request denied'),
                          child: const Text('Deny'),
                        ),
                        FilledButton(
                          onPressed: _busy == 'er-${r['id']}'
                              ? null
                              : () => _act('er-${r['id']}', () => _api.post('report-card-edit-requests/${r['id']}/approve'),
                                  'Edit access granted to ${textOf(r['requested_by'] is Map ? (r['requested_by'] as Map)['full_name'] : null) ?? 'the teacher'}'),
                          child: Text(_busy == 'er-${r['id']}' ? 'Working…' : 'Approve'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _row(Map<String, dynamic> c, bool submittable) {
    final published = _published(c);
    final id = '${c['id']}';
    final pendingRequest = _lk.editRequests.any((r) => '${r['report_card_id']}' == id && '${r['requested_by'] is Map ? (r['requested_by'] as Map)['id'] : ''}' == _staffId);
    final small = OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSurface.cardSoft(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (submittable)
                Checkbox(
                  value: _selected.contains(id),
                  visualDensity: VisualDensity.compact,
                  onChanged: (on) => setState(() => on == true ? _selected.add(id) : _selected.remove(id)),
                ),
              Expanded(child: Text(_student(c), style: AppText.body(size: 14.5, weight: FontWeight.w700, color: AppSurface.ink(context)))),
              published
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF1A9E6E)),
                      const SizedBox(width: 4),
                      Text('Published', style: AppText.body(size: 12, weight: FontWeight.w700, color: const Color(0xFF1A9E6E))),
                    ])
                  : c['submitted'] == true
                      ? const FeedBadge('Ready for review', tone: 'blue')
                      : const FeedBadge('Draft'),
            ],
          ),
          MutedText(_term(c), size: 12.5),
          if (published && c['has_active_edit_unlock'] == true)
            Text('Edit access granted', style: AppText.body(size: 12, color: const Color(0xFFB45309))),
          if (textOf(c['teacher_remark']) != null) ...[
            const SizedBox(height: 4),
            Text('“${textOf(c['teacher_remark'])}”', style: AppText.body(size: 12.5, color: AppSurface.ink(context)).copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(onPressed: () => _view(c), style: small, icon: const Icon(Icons.visibility_outlined, size: 15), label: const Text('View')),
              OutlinedButton.icon(
                onPressed: _busy == 'pdf-$id' ? null : () => _pdf(c),
                style: small,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                label: Text(_busy == 'pdf-$id' ? 'Opening…' : 'PDF'),
              ),
              if (_canEdit(c)) OutlinedButton.icon(onPressed: () => _openForm(c), style: small, icon: const Icon(Icons.edit_outlined, size: 15), label: const Text('Edit')),
              if (submittable)
                OutlinedButton(
                  onPressed: _busy == 'sub-$id'
                      ? null
                      : () => _act('sub-$id', () => _api.post('${ApiConfig.reportCardsPath}/$id/submit'), 'Marked ready for review'),
                  style: small,
                  child: const Text('Submit for review'),
                ),
              if (_publish && _inReach(c) && !published)
                FilledButton(
                  onPressed: _busy == 'pub-$id'
                      ? null
                      : () => _act('pub-$id', () => _api.post('${ApiConfig.reportCardsPath}/$id/publish'), 'Report card published'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Publish'),
                ),
              if (!_publish && _update && _inReach(c) && published && c['has_active_edit_unlock'] != true)
                pendingRequest
                    ? const Padding(padding: EdgeInsets.all(6), child: MutedText('Edit request pending', size: 12))
                    : OutlinedButton(onPressed: () => _requestEdit(c), style: small, child: const Text('Request edit access')),
              if (_delete && _inReach(c))
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(c),
                  style: small,
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line {
  _Line(this.subjectId, this.subjectName, {String classScore = '', String examScore = '', String grade = '', String remark = ''})
      : classScore = TextEditingController(text: classScore),
        examScore = TextEditingController(text: examScore),
        grade = TextEditingController(text: grade),
        remark = TextEditingController(text: remark);

  final String subjectId;
  final String subjectName;
  final TextEditingController classScore;
  final TextEditingController examScore;
  final TextEditingController grade;
  final TextEditingController remark;

  void dispose() {
    classScore.dispose();
    examScore.dispose();
    grade.dispose();
    remark.dispose();
  }
}

/// Create or edit one report card — the website's form: student, term,
/// issued date, promotion, remarks and a line per subject.
class _ReportCardForm extends StatefulWidget {
  const _ReportCardForm({
    this.card,
    required this.students,
    required this.terms,
    required this.classes,
    required this.subjects,
    required this.assignments,
    required this.classOfStudent,
    required this.classTeacherMode,
    required this.myClassNames,
    required this.hasCurrentTerm,
  });

  final Map<String, dynamic>? card;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> terms;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> assignments;
  final Map<String, String> classOfStudent;
  final bool classTeacherMode;
  final String myClassNames;
  final bool hasCurrentTerm;

  @override
  State<_ReportCardForm> createState() => _ReportCardFormState();
}

class _ReportCardFormState extends State<_ReportCardForm> {
  static String _score(dynamic v) {
    if (v == null || '$v'.trim().isEmpty) return '';
    final n = num.tryParse('$v');
    return n == null ? '$v' : (n == n.roundToDouble() ? '${n.toInt()}' : '$n');
  }

  late final Map<String, dynamic> _c = widget.card ?? const {};
  late String _studentId = '${_c['student_id'] ?? ''}';
  late String _termId = '${_c['academic_term_id'] ?? (widget.terms.where((t) => t['status'] == 'current').firstOrNull?['id'] ?? '')}';
  late DateTime _issued = DateTime.tryParse('${_c['issued_date'] ?? ''}') ?? DateTime.now();
  late final _teacherRemark = TextEditingController(text: textOf(_c['teacher_remark']) ?? '');
  late final _headRemark = TextEditingController(text: textOf(_c['headteacher_remark']) ?? '');
  String _promotion = '';
  String _promotedTo = '';
  List<_Line> _lines = [];
  bool _saving = false;
  bool _filling = false;

  bool get _editing => widget.card != null;

  /// Fills the lines from the student's recorded assessments for the term;
  /// a remark already written is kept, as on the website.
  Future<void> _fillFromAssessments() async {
    setState(() => _filling = true);
    try {
      final hit = await ApiClient.instance.post('${ApiConfig.reportCardsPath}/fill-preview', {
        'student_id': _studentId,
        'academic_term_id': _termId,
      });
      final data = hit is Map && hit['data'] is Map ? hit['data'] as Map : const {};
      final filled = FeedingApi.rows(data['lines']);
      if (!mounted) return;
      setState(() {
        for (final row in filled) {
          final id = '${row['subject_id']}';
          var line = _lines.where((l) => l.subjectId == id).firstOrNull;
          if (line == null) {
            line = _Line(id, textOf(row['subject_name']) ?? _subjectName(id));
            _lines.add(line);
          }
          line.classScore.text = _score(row['class_score']);
          line.examScore.text = _score(row['exam_score']);
          line.grade.text = textOf(row['grade']) ?? '';
          if (line.remark.text.trim().isEmpty) line.remark.text = textOf(row['remark']) ?? '';
        }
        _sortLines();
      });
      final weight = data['class_score_weight'];
      showSnack(
        context,
        filled.isEmpty
            ? 'No assessments recorded for this student this term yet.'
            : 'Filled ${plural(filled.length, 'subject')} from assessments${weight is num ? ' (class $weight / exam ${100 - weight})' : ''}.',
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Could not fill from assessments. $e');
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final status = (textOf(_c['promotion_status']) ?? '').toLowerCase();
    if (status == 'repeated') {
      _promotion = 'repeated';
    } else if (status == 'graduated') {
      _promotion = 'graduated';
    } else if (status.startsWith('promoted')) {
      _promotion = 'promoted';
      final to = RegExp(r'to\s+(.+)$', caseSensitive: false).firstMatch(status)?.group(1)?.trim();
      _promotedTo = '${widget.classes.where((k) => _className(k).toLowerCase() == to).firstOrNull?['id'] ?? ''}';
    }
    final existing = FeedingApi.rows(_c['lines']);
    _lines = existing.isNotEmpty
        ? [
            for (final l in existing)
              _Line(
                '${l['subject_id']}',
                textOf(l['subject'] is Map ? (l['subject'] as Map)['name'] : null) ?? _subjectName('${l['subject_id']}'),
                classScore: _score(l['class_score']),
                examScore: _score(l['exam_score']),
                grade: textOf(l['grade']) ?? '',
                remark: textOf(l['remark']) ?? '',
              ),
          ]
        : (_studentId.isEmpty ? [] : _defaultLines(_studentId));
    _sortLines();
  }

  @override
  void dispose() {
    _teacherRemark.dispose();
    _headRemark.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  String _subjectName(String id) => '${widget.subjects.where((s) => '${s['id']}' == id).firstOrNull?['name'] ?? id}';

  void _sortLines() => _lines.sort((a, b) => a.subjectName.compareTo(b.subjectName));

  /// The subjects taught in the student's class, else every subject.
  List<_Line> _defaultLines(String studentId) {
    final klass = widget.classOfStudent[studentId];
    final seen = <String, _Line>{};
    if (klass != null) {
      for (final a in widget.assignments) {
        if ('${a['class_id']}' != klass) continue;
        final id = '${a['subject_id']}';
        seen.putIfAbsent(id, () => _Line(id, textOf(a['subject'] is Map ? (a['subject'] as Map)['name'] : null) ?? _subjectName(id)));
      }
    }
    if (seen.isEmpty) {
      for (final s in widget.subjects) {
        seen['${s['id']}'] = _Line('${s['id']}', '${s['name'] ?? ''}');
      }
    }
    return seen.values.toList();
  }

  String? get _promotionStatus => switch (_promotion) {
        'repeated' => 'Repeated',
        'graduated' => 'Graduated',
        'promoted' => () {
            final k = widget.classes.where((c) => '${c['id']}' == _promotedTo).firstOrNull;
            return k == null ? 'Promoted' : 'Promoted to ${_className(k)}';
          }(),
        _ => null,
      };

  double? _num(String v) => v.trim().isEmpty ? null : double.tryParse(v.replaceAll('%', '').trim());

  bool get _valid => _studentId.isNotEmpty && _termId.isNotEmpty && _lines.isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final body = {
      'student_id': _studentId,
      'academic_term_id': _termId,
      'teacher_remark': _teacherRemark.text.trim().isEmpty ? null : _teacherRemark.text.trim(),
      'headteacher_remark': _headRemark.text.trim().isEmpty ? null : _headRemark.text.trim(),
      'promotion_status': _promotionStatus,
      'issued_date': dateKey(_issued),
      'lines': [
        for (final l in _lines)
          {
            'subject_id': l.subjectId,
            'class_score': _num(l.classScore.text),
            'exam_score': _num(l.examScore.text),
            'grade': l.grade.text.trim().isEmpty ? null : l.grade.text.trim(),
            'remark': l.remark.text.trim().isEmpty ? null : l.remark.text.trim(),
          },
      ],
    };
    try {
      if (_editing) {
        await ApiClient.instance.put('${ApiConfig.reportCardsPath}/${_c['id']}', body);
      } else {
        await ApiClient.instance.post(ApiConfig.reportCardsPath, body);
      }
      if (!mounted) return;
      showSnack(context, _editing ? 'Report card updated' : 'Report card created');
      closeRoute(context, true);
    } catch (e) {
      if (mounted) showSnack(context, '${_editing ? 'Could not update' : 'Could not create'} the report card. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _cell(String hint) => appFieldDecoration(context, hint: hint).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    final studentOptions = [for (final s in widget.students) ('${s['id']}', '${s['full_name'] ?? ''}')];
    final termOptions = [for (final t in widget.terms) ('${t['id']}', '${t['name'] ?? ''}${t['status'] == 'current' ? ' (current)' : ''}')];
    final addable = [for (final s in widget.subjects) if (!_lines.any((l) => l.subjectId == '${s['id']}')) s];
    String label(List<(String, String)> options, String id, String fallback) =>
        options.where((o) => o.$1 == id).firstOrNull?.$2 ?? fallback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.classTeacherMode) ...[
          Text(
            'As class teacher${widget.myClassNames.isEmpty ? '' : ' for ${widget.myClassNames}'}, you can ${_editing ? 'edit' : 'create'} cards for your class students in the current term only.',
            style: AppText.body(size: 12.5, color: AppColors.slate500),
          ),
          if (!widget.hasCurrentTerm)
            Text('No current academic term is set. Ask an admin to mark a term current before creating report cards.',
                style: AppText.body(size: 12.5, color: const Color(0xFFB91C1C))),
          if (widget.students.isEmpty && widget.hasCurrentTerm)
            Text('No active students enrolled in your class yet.', style: AppText.body(size: 12.5, color: AppColors.slate500)),
          const SizedBox(height: 10),
        ],
        IgnorePointer(
          ignoring: _editing,
          child: Opacity(
            opacity: _editing ? 0.6 : 1,
            child: AppSelect(
              label: 'Student *',
              value: label(studentOptions, _studentId, textOf(_c['student'] is Map ? (_c['student'] as Map)['full_name'] : null) ?? 'Select…'),
              items: ['Select…', for (final o in studentOptions) o.$2],
              onChanged: (name) {
                final id = studentOptions.where((o) => o.$2 == name).firstOrNull?.$1 ?? '';
                setState(() {
                  _studentId = id;
                  for (final l in _lines) {
                    l.dispose();
                  }
                  _lines = id.isEmpty ? [] : _defaultLines(id);
                  _sortLines();
                });
              },
            ),
          ),
        ),
        IgnorePointer(
          ignoring: _editing || widget.classTeacherMode,
          child: Opacity(
            opacity: _editing || widget.classTeacherMode ? 0.6 : 1,
            child: AppSelect(
              label: 'Term *',
              value: label(termOptions, _termId, textOf(_c['academic_term'] is Map ? (_c['academic_term'] as Map)['name'] : null) ?? 'Select…'),
              items: ['Select…', for (final o in termOptions) o.$2],
              onChanged: (name) => setState(() => _termId = termOptions.where((o) => o.$2 == name).firstOrNull?.$1 ?? ''),
            ),
          ),
        ),
        const AppFieldLabel('Issued date'),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: _issued, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (picked != null) setState(() => _issued = picked);
          },
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(dayLabel(dateKey(_issued))),
        ),
        const SizedBox(height: 12),
        AppSelect(
          label: 'Promotion',
          value: const {'': 'Not set', 'promoted': 'Promoted', 'repeated': 'Repeated', 'graduated': 'Graduated'}[_promotion]!,
          items: const ['Not set', 'Promoted', 'Repeated', 'Graduated'],
          onChanged: (v) => setState(() {
            _promotion = const {'Not set': '', 'Promoted': 'promoted', 'Repeated': 'repeated', 'Graduated': 'graduated'}[v]!;
            _promotedTo = '';
          }),
        ),
        if (_promotion == 'promoted')
          AppSelect(
            label: 'Promoted to class',
            value: widget.classes.where((c) => '${c['id']}' == _promotedTo).map(_className).firstOrNull ?? 'Select class…',
            items: ['Select class…', for (final c in widget.classes) _className(c)],
            onChanged: (name) => setState(() => _promotedTo = '${widget.classes.where((c) => _className(c) == name).firstOrNull?['id'] ?? ''}'),
          ),
        const AppFieldLabel('Teacher remark'),
        TextField(controller: _teacherRemark, decoration: appFieldDecoration(context)),
        const SizedBox(height: 10),
        const AppFieldLabel('Headteacher remark'),
        TextField(controller: _headRemark, decoration: appFieldDecoration(context)),
        const SizedBox(height: 16),
        Text('Subject results *', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.slate800)),
        if (_studentId.isNotEmpty)
          Text('For each subject: class score, exam score, grade, then remarks.', style: AppText.body(size: 12, color: AppColors.slate500)),
        const SizedBox(height: 8),
        if (_studentId.isEmpty)
          Text('Select a student to load subjects.', style: AppText.body(size: 13, color: AppColors.slate500))
        else if (_lines.isEmpty)
          Text('No subjects found. Add a subject below.', style: AppText.body(size: 13, color: AppColors.slate500)),
        for (final l in _lines)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 10),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.subjectName, style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.slate800))),
                    IconButton(
                      tooltip: 'Remove ${l.subjectName}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _lines.remove(l..dispose())),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: l.classScore,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.%]'))],
                          decoration: _cell('Class score'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: l.examScore,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.%]'))],
                          decoration: _cell('Exam score'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(width: 64, child: TextField(controller: l.grade, decoration: _cell('Grade'))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextField(controller: l.remark, decoration: _cell('Remarks')),
                ),
              ],
            ),
          ),
        if (_studentId.isNotEmpty && _termId.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _filling ? null : _fillFromAssessments,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: Text(_filling ? 'Filling…' : 'Fill from assessments'),
            ),
          ),
        if (_studentId.isNotEmpty && addable.isNotEmpty)
          AppSelect(
            label: 'Add subject',
            value: 'Add subject…',
            items: ['Add subject…', for (final s in addable) '${s['name'] ?? ''}'],
            onChanged: (name) {
              final s = addable.where((x) => '${x['name']}' == name).firstOrNull;
              if (s == null) return;
              setState(() {
                _lines.add(_Line('${s['id']}', '${s['name'] ?? ''}'));
                _sortLines();
              });
            },
          ),
        const SizedBox(height: 10),
        AppModalButton(
          label: _saving ? 'Saving…' : (_editing ? 'Update' : 'Create'),
          onPressed: _saving || !_valid || (widget.classTeacherMode && !_editing && (!widget.hasCurrentTerm || widget.students.isEmpty)) ? null : _save,
        ),
      ],
    );
  }
}
