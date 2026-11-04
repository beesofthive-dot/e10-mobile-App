import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/mark_sheet.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({
    super.key,
    required this.user,
    this.onBack,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  bool _create = false;

  /// Class teacher only: review every subject's work in their class.
  bool _classView = false;
  String _klass = '';
  String _subject = '';
  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _deadline = TextEditingController();
  final _maxScore = TextEditingController(text: '100');
  bool _saving = false;

  /// homework | assignment | exercise | class_test
  String _type = 'homework';
  static const _typeLabels = {
    'homework': 'Homework',
    'assignment': 'Assignment',
    'exercise': 'Exercise',
    'class_test': 'Class test',
  };

  String? _editingId;

  bool get _canCreate => widget.user.role == Role.teacher;

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _deadline.dispose();
    _maxScore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Homework',
            subtitle: _canCreate
                ? 'Homework, assignments, exercises and class tests for your subjects.'
                : widget.user.role == Role.parent
                    ? 'Work for ${SchoolScope.of(context).focusedChild(Role.parent)?.name ?? 'your child'}.'
                    : 'Assigned work.',
            onBack: _create ? () => setState(() {
              _create = false;
              _editingId = null;
            }) : widget.onBack,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (_canCreate) ...[
                  HoneyPills(
                    items: const ['My Homework', 'Create Assignment'],
                    value: _create ? 'Create Assignment' : 'My Homework',
                    onChanged: (v) => setState(() {
                      _create = v == 'Create Assignment';
                      if (!_create) {
                        _editingId = null;
                      } else if (_editingId == null) {
                        _klass = _resolvedKlass(SchoolScope.of(context));
                      }
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (!_create && SchoolScope.of(context).homeroomClassesFor(widget.user).isNotEmpty) ...[
                    HoneyPills(
                      items: const ['Mine', 'My class (all subjects)'],
                      value: _classView ? 'My class (all subjects)' : 'Mine',
                      onChanged: (v) => setState(() => _classView = v != 'Mine'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (!_create || !_canCreate) ..._list() else ..._form(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _list() {
    final store = SchoolScope.of(context);
    var rows = [
      ...store.tableRows('assignments'),
      // Class tests are exams of kind `class_test`; teachers mark them here too.
      if (widget.user.role == Role.teacher)
        for (final exam in store.tableRows('exams'))
          if ('${exam['kind']}' == 'class_test') {...exam, '_classTest': true},
    ];
    Student? child;
    if (widget.user.role == Role.parent) {
      child = store.focusedChild(Role.parent);
      if (child != null) {
        final focused = child;
        rows = [for (final row in rows) if (store.rowMatchesStudent(row, focused)) row];
      }
    } else if (widget.user.role == Role.teacher) {
      if (_classView) {
        // Class teacher reviewing their own class: every subject's work.
        final mine = store.homeroomClassesFor(widget.user);
        rows = [for (final row in rows) if (mine.any((c) => store.rowMatchesClass(row, c))) row];
      } else {
        // Only work this teacher set — never another teacher's homework.
        rows = [for (final row in rows) if (store.isMyClassWork(row)) row];
      }
    }
    if (rows.isEmpty) {
      return [
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.user.role == Role.parent
                ? 'No homework for ${child?.name ?? 'this child'} yet.'
                : _classView
                    ? 'No work set in your class yet.'
                    : 'You have not set any work yet.',
            style: AppText.body(size: 13, color: AppSurface.muted(context)),
          ),
        ),
      ];
    }
    final studentId = child?.id ?? store.focusedChild(widget.user.role)?.id ?? store.students.firstOrNull?.id;
    return [
      for (final row in rows)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppSurface.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppSurface.line(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [_subjectName(row), _typeOf(row)].where((p) => p.isNotEmpty).join(' · ').toUpperCase(),
                          style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.blue, letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${row['title'] ?? row['name'] ?? 'Assignment'}',
                          style: AppText.body(size: 15, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (row['_classTest'] != true) StatusDot(label: _hwStatus(row, studentId).$1, color: _hwStatus(row, studentId).$2),
                  if (_canCreate && store.isMyClassWork(row))
                    ActionMenuButton(
                      actions: [
                        if (_canMark(store, row))
                          SheetAction(
                            label: 'Mark',
                            icon: Icons.fact_check_outlined,
                            onTap: () => _mark(store, row),
                          ),
                        if (row['_classTest'] != true) SheetAction(
                          label: 'Edit',
                          icon: Icons.edit_outlined,
                          onTap: () => _editHomework(row),
                        ),
                        if (row['_classTest'] != true)
                          SheetAction(
                            label: 'Delete',
                            icon: Icons.delete_outline_rounded,
                            destructive: true,
                            onTap: () => _deleteHomework(row),
                          ),
                      ],
                    ),
                ],
              ),
              if ('${row['instructions'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${row['instructions']}'.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 13, color: AppSurface.muted(context)),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                row['_classTest'] == true
                    ? [
                        if ('${row['max_score'] ?? ''}'.isNotEmpty && '${row['max_score']}' != 'null') 'Out of ${row['max_score']}',
                        if ('${row['exam_date'] ?? ''}'.isNotEmpty && '${row['exam_date']}' != 'null') formatStamp('${row['exam_date']}'),
                      ].join(' · ')
                    : _dueLabel('${row['deadline'] ?? row['published_date'] ?? ''}'),
                style: AppText.body(size: 12, color: AppColors.slate500),
              ),
            ],
          ),
        ),
    ];
  }

  String _subjectName(Map<String, dynamic> row) {
    if (row['subject'] is Map) return '${(row['subject'] as Map)['name'] ?? ''}';
    return '${row['subject'] ?? ''}';
  }

  String _typeOf(Map<String, dynamic> row) {
    if (row['_classTest'] == true) return 'Class test';
    return _typeLabels['${row['type'] ?? 'homework'}'] ?? 'Homework';
  }

  String _classIdOf(Map<String, dynamic> row) =>
      '${row['class_id'] ?? (row['class'] is Map ? (row['class'] as Map)['id'] : '') ?? ''}';

  String _subjectIdOf(Map<String, dynamic> row) =>
      '${row['subject_id'] ?? (row['subject'] is Map ? (row['subject'] as Map)['id'] : '') ?? ''}';

  /// Only the teacher of that subject in that class marks it (the server
  /// enforces the same). Before assignments load, let the server decide.
  bool _canMark(SchoolStore store, Map<String, dynamic> row) {
    final mine = store.mySubjectAssignments;
    if (mine.isEmpty) return true;
    return mine.any((a) => a.classId == _classIdOf(row) && a.subjectId == _subjectIdOf(row));
  }

  Future<void> _mark(SchoolStore store, Map<String, dynamic> row) async {
    final id = '${row['id'] ?? ''}';
    final classId = _classIdOf(row);
    final students = store.studentsInClass(classId);
    final title = '${row['title'] ?? row['name'] ?? 'Class work'}';
    final subtitle = [_subjectName(row), store.classDisplayName(classId), _typeOf(row)].where((p) => p.isNotEmpty).join(' · ');
    if (row['_classTest'] == true) {
      final max = double.tryParse('${row['max_score'] ?? ''}');
      await showMarkSheet(
        context: context,
        title: title,
        subtitle: subtitle,
        students: students,
        maxScore: max,
        maxEditable: false,
        load: () => store.fetchExamResults(id),
        save: (m, scores, existing) => store.saveExamResults(examId: id, maxScore: max ?? 0, scores: scores, existing: existing),
      );
    } else {
      await showMarkSheet(
        context: context,
        title: title,
        subtitle: subtitle,
        students: students,
        load: () => store.fetchSubmissions(id),
        save: (m, scores, existing) => store.saveSubmissionMarks(assignmentId: id, maxScore: m, scores: scores, existing: existing),
      );
    }
    if (mounted) setState(() {});
  }

  (String, Color) _hwStatus(Map<String, dynamic> row, String? studentId) {
    String raw = '${row['status'] ?? ''}';
    final submissions = row['submissions'];
    if (submissions is List) {
      for (final item in submissions) {
        if (item is! Map) continue;
        if (studentId != null && '${item['student_id']}' != studentId) continue;
        raw = '${item['status'] ?? raw}';
        break;
      }
    }
    final s = raw.toLowerCase();
    if (s == 'marked') return ('Marked', AppColors.emerald);
    if (s == 'submitted' || s == 'late') return ('Submitted', AppColors.blue);
    if (s == 'not_submitted' || s == 'not submitted') return ('Not submitted', const Color(0xFFC2410C));
    return ('Assigned', AppColors.slate500);
  }

  String _dueLabel(String raw) {
    if (raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return 'Due $raw';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Due ${d.day} ${months[d.month - 1]}';
  }

  List<NamedRecord> _classChoices(SchoolStore store) {
    if (widget.user.role != Role.teacher) return store.classes;
    // Classes where they teach a subject (from their real assignments).
    final mine = store.mySubjectClasses;
    return mine.isNotEmpty ? mine : store.teacherFocusClasses(widget.user);
  }

  List<NamedRecord> _subjectChoices(SchoolStore store, String className) {
    if (widget.user.role == Role.teacher && store.mySubjectAssignments.isNotEmpty) {
      final classId = _classChoices(store).where((c) => c.name == className).firstOrNull?.id ?? '';
      return store.subjectsTaughtIn(classId);
    }
    return store.subjectRecords;
  }

  String _resolvedKlass(SchoolStore store) {
    final classes = _classChoices(store);
    if (classes.any((c) => c.name == _klass)) return _klass;
    if (widget.user.role == Role.teacher) {
      final focus = store.focusedClassRecord();
      if (focus != null && classes.any((c) => c.id == focus.id || c.name == focus.name)) {
        return focus.name;
      }
    }
    return classes.firstOrNull?.name ?? _klass;
  }

  List<Widget> _form() {
    final store = SchoolScope.of(context);
    final classes = _classChoices(store);
    final klass = _resolvedKlass(store);
    final subjects = _subjectChoices(store, klass);
    final isTest = _type == 'class_test';
    final subject = subjects.any((s) => s.name == _subject)
        ? _subject
        : (subjects.firstOrNull?.name ?? _subject);
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.slate50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.slate200),
          ),
        );
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t.toUpperCase(), style: AppText.label()),
        );
    return [
      AdminDropdown(
        label: 'Type',
        value: _typeLabels[_type]!,
        items: [
          for (final e in _typeLabels.entries)
            if (_editingId == null || e.key != 'class_test') e.value,
        ],
        onChanged: (v) => setState(() => _type = _typeLabels.entries.firstWhere((e) => e.value == v).key),
      ),
      AdminDropdown(
        label: 'Class',
        value: klass,
        items: classes.isEmpty ? [klass] : [for (final c in classes) c.name],
        onChanged: (v) => setState(() => _klass = v),
      ),
      AdminDropdown(
        label: 'Subject',
        value: subject,
        items: subjects.isEmpty ? [subject] : [for (final s in subjects) s.name],
        onChanged: (v) => setState(() => _subject = v),
      ),
      label(isTest ? 'Test name' : 'Title'),
      TextField(controller: _title, decoration: deco(isTest ? 'e.g. Class test 1: Fractions' : 'e.g. Chapter 5: Fractions Practice')),
      const SizedBox(height: 14),
      if (isTest) ...[
        label('Marked out of'),
        TextField(controller: _maxScore, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: deco('e.g. 100')),
        const SizedBox(height: 14),
        label('Test date'),
        TextField(controller: _deadline, decoration: deco('YYYY-MM-DD')),
      ] else ...[
        label('Instructions'),
        TextField(controller: _instructions, maxLines: 3, decoration: deco('Describe the work...')),
        const SizedBox(height: 14),
        label('Due Date'),
        TextField(controller: _deadline, decoration: deco('YYYY-MM-DD')),
      ],
      const SizedBox(height: 16),
      HoneyButton(
        label: _saving
            ? (_editingId == null ? 'Publishing...' : 'Saving...')
            : (_editingId == null ? (isTest ? 'Create class test' : 'Publish ${_typeLabels[_type]}') : 'Save ${_typeLabels[_type]}'),
        loading: _saving,
        onPressed: _saving ? null : _publish,
      ),
    ];
  }

  Future<void> _publish() async {
    final store = SchoolScope.of(context);
    final klassName = _resolvedKlass(store);
    final subjectChoices = _subjectChoices(store, klassName);
    final subjectName = subjectChoices.any((s) => s.name == _subject) ? _subject : subjectChoices.firstOrNull?.name;
    final classId = store.resolveClassUuid(
          store.classes.where((c) => c.name == klassName).firstOrNull?.id ?? klassName,
        ) ??
        store.classes.where((c) => c.name == klassName).firstOrNull?.id;
    final subjectId = store.resolveSubjectUuid(
          subjectChoices.where((s) => s.name == subjectName).firstOrNull?.id ?? subjectName ?? '',
        ) ??
        subjectChoices.where((s) => s.name == subjectName).firstOrNull?.id;
    if (classId == null || subjectId == null) {
      showSnack(context, 'Choose a class and subject from the school records.');
      return;
    }
    setState(() => _saving = true);
    if (_type == 'class_test') {
      final result = await store.createClassTest(
        classId: classId,
        subjectId: subjectId,
        name: _title.text.trim(),
        maxScore: double.tryParse(_maxScore.text.trim()) ?? 0,
        date: _deadline.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (result.error.isNotEmpty) {
        showSnack(context, result.error);
        return;
      }
      _title.clear();
      _deadline.clear();
      setState(() => _create = false);
      showSnack(context, 'Class test created. Open it from the list to enter marks.');
      return;
    }
    final error = _editingId == null
        ? await store.createAssignment(
            classId: classId,
            subjectId: subjectId,
            title: _title.text.trim(),
            instructions: _instructions.text.trim(),
            deadline: _deadline.text.trim(),
            type: _type,
          )
        : await store.updateAssignment(
            id: _editingId!,
            classId: classId,
            subjectId: subjectId,
            title: _title.text.trim(),
            instructions: _instructions.text.trim(),
            deadline: _deadline.text.trim(),
            type: _type,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error.isNotEmpty) {
      showSnack(context, error);
      return;
    }
    final wasEdit = _editingId != null;
    _title.clear();
    _instructions.clear();
    _deadline.clear();
    setState(() {
      _create = false;
      _editingId = null;
    });
    showSnack(context, wasEdit ? '${_typeLabels[_type]} updated.' : '${_typeLabels[_type]} published to the class.');
  }

  void _editHomework(Map<String, dynamic> row) {
    final store = SchoolScope.of(context);
    final className = row['class'] is Map ? '${(row['class'] as Map)['name'] ?? ''}' : '${row['class'] ?? ''}';
    final subjectName = _subjectName(row);
    _title.text = '${row['title'] ?? ''}';
    _instructions.text = '${row['instructions'] ?? ''}';
    _deadline.text = '${row['deadline'] ?? ''}'.split('T').first;
    setState(() {
      _editingId = '${row['id'] ?? ''}';
      _type = _typeLabels.containsKey('${row['type']}') && '${row['type']}' != 'class_test' ? '${row['type']}' : 'homework';
      _klass = store.classes.where((c) => c.name == className || c.id == '${row['class_id']}').firstOrNull?.name ?? _klass;
      _subject = store.subjectRecords.where((s) => s.name == subjectName || s.id == '${row['subject_id']}').firstOrNull?.name ?? _subject;
      _create = true;
    });
  }

  Future<void> _deleteHomework(Map<String, dynamic> row) async {
    final id = '${row['id'] ?? ''}';
    if (id.isEmpty) return;
    final store = SchoolScope.of(context);
    final ok = await confirmDelete(context, 'assignment');
    if (!ok || !mounted) return;
    final error = await store.deleteAssignment(id);
    if (!mounted) return;
    if (error.isNotEmpty) {
      showSnack(context, error);
      return;
    }
    showSnack(context, 'Assignment deleted.');
    setState(() {});
  }
}
