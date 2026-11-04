import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../core/config/api_config.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart' show AdminDropdown, showSnack;

/// Admin view of every teacher's subject + class assignments, as on the
/// website's Staff page ("Subjects · teacher name"): read straight from
/// `/teacher-subject-assignments`, grouped by teacher, with each class's
/// class teacher shown too. Admins can add (`POST` one row per class, the
/// same payload the website sends) and remove assignments.
class SubjectAssignmentsScreen extends StatefulWidget {
  const SubjectAssignmentsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<SubjectAssignmentsScreen> createState() => _SubjectAssignmentsScreenState();
}

class _SubjectAssignmentsScreenState extends State<SubjectAssignmentsScreen> {
  bool _loading = false;
  String? _error;
  String _search = '';
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _subjects = const [];
  List<Map<String, dynamic>> _years = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Every page of a list endpoint (the server caps a page).
  static Future<List<Map<String, dynamic>>> _all(String path, [Map<String, String> query = const {}]) async {
    final rows = <Map<String, dynamic>>[];
    for (var page = 1; page <= 30; page++) {
      final body = await ApiClient.instance.get(path, query: {...query, 'per_page': '100', 'page': '$page'});
      final data = body is Map ? body['data'] : body;
      if (data is List) {
        rows.addAll([for (final r in data) if (r is Map) Map<String, dynamic>.from(r)]);
      }
      final meta = body is Map ? body['meta'] : null;
      final last = meta is Map ? int.tryParse('${meta['last_page'] ?? 1}') ?? 1 : 1;
      if (page >= last) break;
    }
    return rows;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _all(ApiConfig.teacherSubjectAssignmentsPath),
        _all('subjects').catchError((_) => <Map<String, dynamic>>[]),
        _all('academic-years').catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0];
        _subjects = results[1];
        _years = results[2];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load subject assignments. Pull down to try again.';
      });
    }
  }

  static String _name(dynamic map, [String key = 'name']) => map is Map ? '${map[key] ?? map['full_name'] ?? ''}'.trim() : '';

  String _className(Map<String, dynamic> row, SchoolStore store) {
    final klass = row['class'] ?? row['school_class'];
    if (klass is Map) {
      final name = _name(klass);
      final stream = '${klass['stream'] ?? ''}'.trim();
      if (name.isNotEmpty) return stream.isEmpty ? name : '$name · $stream';
    }
    final id = '${row['class_id'] ?? ''}';
    return store.classes.where((c) => c.id == id).firstOrNull?.name ?? 'Class';
  }

  String _subjectName(Map<String, dynamic> row) {
    final name = _name(row['subject']);
    if (name.isNotEmpty) return name;
    final id = '${row['subject_id'] ?? ''}';
    return _name(_subjects.where((s) => '${s['id']}' == id).firstOrNull);
  }

  String _staffId(Map<String, dynamic> row) =>
      '${row['staff_id'] ?? (row['staff'] is Map ? (row['staff'] as Map)['id'] : '')}';

  Future<void> _remove(Map<String, dynamic> row, String teacher) async {
    final ok = await showAppConfirm(
      context: context,
      title: 'Remove subject assignment?',
      message: 'Remove ${_subjectName(row)} (${_className(row, SchoolScope.of(context))}) from $teacher?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    try {
      await ApiClient.instance.delete('${ApiConfig.teacherSubjectAssignmentsPath}/${row['id']}');
      if (mounted) showSnack(context, 'Assignment removed');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not remove the assignment. $e');
    }
  }

  Future<void> _add(NamedRecord teacher) async {
    final saved = await showAppSheet<bool>(
      context: context,
      title: 'Subjects · ${teacher.name}',
      builder: (_) => _AssignForm(teacher: teacher, subjects: _subjects, years: _years),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final byStaff = <String, List<Map<String, dynamic>>>{};
    for (final row in _rows) {
      byStaff.putIfAbsent(_staffId(row), () => []).add(row);
    }
    // Every teacher, plus anyone the server has assignments for who isn't
    // in the teachers list (e.g. an admin who also teaches).
    final people = <NamedRecord>[...store.teachers];
    for (final entry in byStaff.entries) {
      if (people.any((t) => t.id == entry.key)) continue;
      final staff = entry.value.first['staff'];
      people.add(NamedRecord(id: entry.key, name: _name(staff).isEmpty ? 'Staff member' : _name(staff)));
    }
    people.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final q = _search.trim().toLowerCase();
    final shown = q.isEmpty
        ? people
        : people.where((t) {
            if (t.name.toLowerCase().contains(q)) return true;
            return (byStaff[t.id] ?? const []).any((r) =>
                _subjectName(r).toLowerCase().contains(q) || _className(r, store).toLowerCase().contains(q));
          }).toList();
    final homerooms = {
      for (final c in store.classes)
        if (c.link.isNotEmpty) c.link.toLowerCase(): <String>[],
    };
    for (final c in store.classes) {
      if (c.link.isNotEmpty) homerooms[c.link.toLowerCase()]!.add(c.name);
    }

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Subject assignments',
            subtitle: '${_rows.length} assignments · ${people.length} staff',
            onBack: widget.onBack,
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppLayout.page(context),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: AppText.body(size: 13, color: AppColors.rose)),
                    ),
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search teacher, subject or class',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_loading && shown.isEmpty)
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        people.isEmpty ? 'No staff records yet.' : 'No staff match your search.',
                        style: AppText.body(size: 13, color: AppColors.slate500),
                      ),
                    ),
                  for (final teacher in shown) ...[
                    _TeacherCard(
                      teacher: teacher,
                      homerooms: homerooms[teacher.name.toLowerCase()] ?? const [],
                      rows: [
                        for (final r in byStaff[teacher.id] ?? const <Map<String, dynamic>>[])
                          (subject: _subjectName(r), klass: _className(r, store), row: r),
                      ]..sort((a, b) => '${a.subject}${a.klass}'.compareTo('${b.subject}${b.klass}')),
                      onAdd: () => _add(teacher),
                      onRemove: (r) => _remove(r, teacher.name),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({
    required this.teacher,
    required this.homerooms,
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  final NamedRecord teacher;
  final List<String> homerooms;
  final List<({String subject, String klass, Map<String, dynamic> row})> rows;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onRemove;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: teacher.name, tone: Tone.sky),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacher.name, style: AppText.body(weight: FontWeight.w800)),
                    if (teacher.extra.isNotEmpty)
                      Text('${teacher.extra} Department',
                          style: AppText.body(size: 10, weight: FontWeight.w700, color: AppColors.blue)),
                    if (homerooms.isNotEmpty)
                      Text('Class teacher: ${homerooms.join(', ')}',
                          style: AppText.body(size: 11, color: AppColors.emerald, weight: FontWeight.w700)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Assign'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text('No subjects assigned', style: AppText.body(size: 12, color: AppColors.slate400))
          else
            for (final r in rows)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                decoration: BoxDecoration(
                  color: AppSurface.page(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.subject.isEmpty ? 'Subject' : r.subject,
                              style: AppText.body(size: 13, weight: FontWeight.w700)),
                          Text(r.klass, style: AppText.body(size: 11, color: AppColors.slate500)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => onRemove(r.row),
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.rose),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AssignForm extends StatefulWidget {
  const _AssignForm({required this.teacher, required this.subjects, required this.years});

  final NamedRecord teacher;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> years;

  @override
  State<_AssignForm> createState() => _AssignFormState();
}

class _AssignFormState extends State<_AssignForm> {
  String _subject = '';
  final Set<String> _classIds = {};
  bool _saving = false;

  String get _yearId {
    final current = widget.years.where((y) => y['is_current'] == true || y['is_current'] == 1).firstOrNull ??
        widget.years.firstOrNull;
    return '${current?['id'] ?? SchoolScope.of(context).academicYearId ?? ''}';
  }

  Future<void> _save() async {
    final subject = widget.subjects.where((s) => '${s['name']}' == _subject).firstOrNull;
    if (subject == null) return showSnack(context, 'Choose a subject.');
    if (_classIds.isEmpty) return showSnack(context, 'Select at least one class.');
    setState(() => _saving = true);
    var ok = 0;
    String? lastError;
    for (final classId in _classIds) {
      try {
        await ApiClient.instance.post(ApiConfig.teacherSubjectAssignmentsPath, {
          'staff_id': widget.teacher.id,
          'subject_id': '${subject['id']}',
          'class_id': classId,
          'academic_year_id': _yearId,
        });
        ok++;
      } catch (e) {
        lastError = '$e';
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == _classIds.length) {
      showSnack(context, ok == 1 ? 'Subject assigned' : 'Assigned to $ok classes');
      Navigator.of(context).pop(true);
    } else if (ok > 0) {
      showSnack(context, 'Assigned to $ok of ${_classIds.length} classes — the rest may already have this assignment');
      Navigator.of(context).pop(true);
    } else {
      showSnack(context, 'Could not assign the subject. ${lastError ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final names = [for (final s in widget.subjects) '${s['name'] ?? ''}'].where((n) => n.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (names.isEmpty)
          Text('No subjects set up for this school yet.', style: AppText.body(size: 13, color: AppColors.slate500))
        else
          AdminDropdown(
            label: 'Subject',
            value: _subject.isEmpty ? names.first : _subject,
            items: names,
            onChanged: (v) => setState(() => _subject = v),
          ),
        const SizedBox(height: 8),
        Text('Classes', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.slate500)),
        for (final c in store.classes)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _classIds.contains(c.id),
            title: Text(c.name),
            onChanged: (v) => setState(() => v == true ? _classIds.add(c.id) : _classIds.remove(c.id)),
          ),
        const SizedBox(height: 12),
        HoneyButton(
          label: 'Assign',
          loading: _saving,
          onPressed: names.isEmpty
              ? null
              : () {
                  if (_subject.isEmpty) _subject = names.first;
                  return _save();
                },
        ),
      ],
    );
  }
}
