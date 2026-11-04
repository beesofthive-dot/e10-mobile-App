import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_session.dart';
import '../department_head.dart';
import '../feeding.dart';
import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/feeding_widgets.dart';
import '../widgets/popups.dart';
import '../widgets/student_profile_sheet.dart';
import 'admin_forms.dart' show showSnack;

/// The department names a head's pages are about, falling back on the
/// school's department list when the login reply only carried ids.
String _departmentNames(BuildContext context, AppUser user) {
  final store = SchoolScope.maybeOf(context);
  final names = <String>[
    for (final head in user.departmentHeads)
      if (head.departmentName.isNotEmpty)
        head.departmentName
      else if (store?.departments.where((d) => d.id == head.departmentId).firstOrNull case final record?)
        record.name,
  ];
  return names.isEmpty ? 'Your department' : names.join(', ');
}

String _headRole(AppUser user) => user.isMainDepartmentHead ? 'Main head' : 'Assistant head';

const _sections = [
  (screen: AppScreen.departmentStudents, label: 'Students', icon: Icons.school_rounded),
  (screen: AppScreen.departmentStaff, label: 'Staff', icon: Icons.badge_rounded),
  (screen: AppScreen.departmentClasses, label: 'Classes', icon: Icons.groups_rounded),
  (screen: AppScreen.departmentAttendance, label: 'Attendance', icon: Icons.how_to_reg_rounded),
  (screen: AppScreen.departmentHeads, label: 'Department heads', icon: Icons.manage_accounts_rounded),
];

bool _offered(AppUser user, AppScreen screen) => user.canOpen(screen) && PlanAccess.allows(screen);

/// The teacher/staff dashboard's way into "My department".
class DepartmentHeadCard extends StatelessWidget {
  const DepartmentHeadCard({super.key, required this.user, required this.onNav});

  final AppUser user;
  final ValueChanged<AppScreen> onNav;

  @override
  Widget build(BuildContext context) {
    return NavListRow(
      title: 'My department',
      subtitle: '${_departmentNames(context, user)} · ${_headRole(user)}',
      icon: Icons.apartment_rounded,
      onTap: () => onNav(AppScreen.departmentHome),
    );
  }
}

/// "My department": what the head leads at a glance, then each list. Only asks
/// the server for totals (one row each), so it opens quickly on mobile data.
class DepartmentHomeScreen extends StatefulWidget {
  const DepartmentHomeScreen({super.key, required this.user, required this.onNav, this.onBack});

  final AppUser user;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback? onBack;

  @override
  State<DepartmentHomeScreen> createState() => _DepartmentHomeScreenState();
}

class _DepartmentHomeScreenState extends State<DepartmentHomeScreen> {
  int? _students;
  int? _staff;
  int? _classes;
  Map<String, dynamic>? _today;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// New permissions can arrive while this page is open; their rows need counts.
  @override
  void didUpdateWidget(DepartmentHomeScreen old) {
    super.didUpdateWidget(old);
    if (old.user.permissions.join() != widget.user.permissions.join()) _load();
  }

  Future<int?> _count(Future<DepartmentPage> Function() read) async {
    try {
      return (await read()).total;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final user = widget.user;
    final scope = DepartmentScope(user.departmentHeads);
    final results = await Future.wait<Object?>([
      user.canOpen(AppScreen.departmentStudents) ? _count(() => DepartmentApi.students(perPage: 1)) : Future.value(),
      user.canOpen(AppScreen.departmentStaff) ? _count(() => DepartmentApi.staff(perPage: 1)) : Future.value(),
      user.canOpen(AppScreen.departmentClasses)
          ? DepartmentApi.classes().then<int?>((p) => p.rows.where(scope.hasClass).length).catchError((_) => null)
          : Future.value(),
      _offered(user, AppScreen.departmentAttendance)
          ? DepartmentApi.attendance(date: dateKey(DateTime.now()), personType: 'student', perPage: 1)
              .then<Map<String, dynamic>?>((p) => p.summary)
              .catchError((_) => null)
          : Future.value(),
    ]);
    if (!mounted) return;
    setState(() {
      _students = results[0] as int?;
      _staff = results[1] as int?;
      _classes = results[2] as int?;
      _today = results[3] as Map<String, dynamic>?;
    });
  }

  String? _countOf(AppScreen screen) {
    int? count;
    var word = '';
    switch (screen) {
      case AppScreen.departmentStudents:
        (count, word) = (_students, 'student');
      case AppScreen.departmentStaff:
        (count, word) = (_staff, 'staff member');
      case AppScreen.departmentClasses:
        (count, word) = (_classes, 'class');
      case AppScreen.departmentAttendance:
        final today = _today;
        if (today == null) return "Today's record";
        final inToday = intOf(today['present']) + intOf(today['late']);
        return '$inToday in · ${intOf(today['absent'])} absent today';
      case AppScreen.departmentHeads:
        return 'Choose who helps run the department';
      default:
        return null;
    }
    if (count == null) return null;
    return count == 1 ? '1 $word' : '$count ${word == 'class' ? 'classes' : word == 'staff member' ? 'staff' : '${word}s'}';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(title: 'My department', subtitle: _departmentNames(context, user), onBack: widget.onBack),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppLayout.page(context),
                children: [
                  WhiteCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      '${_headRole(user)}. You see only this department’s staff, classes, students and attendance.',
                      style: AppText.body(size: 13, color: AppSurface.ink(context)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final section in _sections)
                    if (_offered(user, section.screen))
                      NavListRow(
                        title: section.label,
                        subtitle: _countOf(section.screen),
                        icon: section.icon,
                        onTap: () => widget.onNav(section.screen),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A searchable list that loads a page at a time, for Students and Staff.
class _PagedList extends StatefulWidget {
  const _PagedList({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.empty,
    required this.load,
    required this.keep,
    required this.tile,
    this.onBack,
    this.search = true,
  });

  final String title;
  final String subtitle;
  final String hint;
  final String empty;
  final bool search;
  final VoidCallback? onBack;
  final Future<DepartmentPage> Function(String search, int page) load;
  final bool Function(Map<String, dynamic> row) keep;
  final Widget Function(BuildContext context, Map<String, dynamic> row) tile;

  @override
  State<_PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<_PagedList> {
  final _rows = <Map<String, dynamic>>[];
  var _page = 0;
  var _lastPage = 1;
  var _total = 0;
  var _loading = true;
  var _more = false;
  String? _error;
  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search = text;
      _reload();
    });
  }

  Future<void> _reload() async {
    final search = _search;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.load(search, 1);
      if (!mounted || search != _search) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(page.rows.where(widget.keep));
        _page = 1;
        _lastPage = page.lastPage;
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || search != _search) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _more = true);
    try {
      final page = await widget.load(_search, _page + 1);
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.rows.where(widget.keep));
        _page++;
        _lastPage = page.lastPage;
      });
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(title: widget.title, subtitle: _loading ? widget.subtitle : '${_page < _lastPage ? _total : _rows.length} · ${widget.subtitle}', onBack: widget.onBack),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppLayout.page(context),
                children: [
                  if (widget.search) ...[
                    TextField(
                      onChanged: _onSearch,
                      textInputAction: TextInputAction.search,
                      decoration: appFieldDecoration(context, hint: widget.hint).copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 20)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    _Problem(message: _error!, onRetry: _reload)
                  else if (_rows.isEmpty)
                    WhiteCard(padding: const EdgeInsets.all(14), child: MutedText(_search.trim().isEmpty ? widget.empty : 'Nothing matches your search.'))
                  else ...[
                    for (final row in _rows) widget.tile(context, row),
                    if (_page < _lastPage)
                      Center(
                        child: OutlinedButton(
                          onPressed: _more ? null : _loadMore,
                          child: Text(_more ? 'Loading…' : 'Load more'),
                        ),
                      ),
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

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MutedText(message),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.name, this.lines = const [], this.badge, this.onTap});

  final String name;
  final List<String> lines;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: WhiteCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                InitialsAvatar(name: name, size: AvatarSize.sm),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.ink(context))),
                      for (final line in lines)
                        if (line.isNotEmpty) MutedText(line, size: 12),
                    ],
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge!],
                if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.slate300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _studentTile(BuildContext context, Map<String, dynamic> row) {
  final store = SchoolScope.of(context);
  final student = store.studentFromRosterRow({'student': row});
  return _PersonTile(
    name: textOf(row['full_name']) ?? student.name,
    lines: [
      [if (student.klass.isNotEmpty) student.klass, if (store.studentDisplayId(student).isNotEmpty) 'ID ${store.studentDisplayId(student)}'].join(' · '),
    ],
    onTap: () => showStudentProfileSheet(context, student),
  );
}

/// The head's students, from the server; those known to be in a class outside
/// the department are dropped.
class DepartmentStudentsScreen extends StatefulWidget {
  const DepartmentStudentsScreen({super.key, required this.user, this.onBack});

  final AppUser user;
  final VoidCallback? onBack;

  @override
  State<DepartmentStudentsScreen> createState() => _DepartmentStudentsScreenState();
}

class _DepartmentStudentsScreenState extends State<DepartmentStudentsScreen> {
  /// Ids of classes known to be outside the department.
  Set<String> _outside = const {};

  Future<DepartmentPage> _load(String search, int page) async {
    if (page == 1 && widget.user.permissions.contains('classes.view')) {
      final scope = DepartmentScope(widget.user.departmentHeads);
      try {
        final classes = await DepartmentApi.classes();
        _outside = {for (final c in classes.rows) if (!scope.hasClass(c)) '${c['id']}'};
      } catch (_) {
        // Leave it to the server's own limits.
      }
    }
    return DepartmentApi.students(search: search, page: page);
  }

  @override
  Widget build(BuildContext context) {
    return _PagedList(
      title: 'Students',
      subtitle: 'in your department',
      hint: 'Search students',
      empty: 'No students in your department yet.',
      onBack: widget.onBack,
      load: _load,
      keep: (row) => !_outside.contains(departmentStudentClassId(row)),
      tile: _studentTile,
    );
  }
}

/// The department's teachers and other staff.
class DepartmentStaffScreen extends StatelessWidget {
  const DepartmentStaffScreen({super.key, required this.user, this.onBack});

  final AppUser user;
  final VoidCallback? onBack;

  static List<String> _departmentsOf(Map<String, dynamic> row) => [
        for (final d in FeedingApi.rows(row['departments'])) textOf(d['name']) ?? '',
        if (row['departments'] is! List && row['department'] is Map) textOf((row['department'] as Map)['name']) ?? '',
      ].where((name) => name.isNotEmpty).toList();

  void _details(BuildContext context, Map<String, dynamic> row) {
    final facts = <(String, String?)>[
      ('Position', textOf(row['position'])),
      ('Category', textOf(row['category'])),
      ('Department', _departmentsOf(row).join(', ')),
      ('Phone', textOf(row['phone'])),
      ('Email', textOf(row['email'])),
      ('Status', textOf(row['status'])),
    ];
    showAppSheet<void>(
      context: context,
      title: textOf(row['full_name']) ?? 'Staff member',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in facts)
            if (value != null && value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.body(size: 12, color: AppColors.slate500)),
                    Text(value, style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.slate800)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = DepartmentScope(user.departmentHeads);
    return _PagedList(
      title: 'Staff',
      subtitle: 'in your department',
      hint: 'Search staff',
      empty: 'No staff in your department yet.',
      onBack: onBack,
      load: (search, page) => DepartmentApi.staff(search: search, page: page),
      keep: scope.hasStaff,
      tile: (context, row) => _PersonTile(
        name: textOf(row['full_name']) ?? 'Staff member',
        lines: [textOf(row['position']) ?? textOf(row['category']) ?? '', textOf(row['phone']) ?? ''],
        onTap: () => _details(context, row),
      ),
    );
  }
}

/// The department's classes; opening one lists its students.
class DepartmentClassesScreen extends StatefulWidget {
  const DepartmentClassesScreen({super.key, required this.user, this.onBack});

  final AppUser user;
  final VoidCallback? onBack;

  @override
  State<DepartmentClassesScreen> createState() => _DepartmentClassesScreenState();
}

class _DepartmentClassesScreenState extends State<DepartmentClassesScreen> {
  Map<String, dynamic>? _open;

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open != null) {
      return _PagedList(
        key: ValueKey('class-${open['id']}'),
        title: departmentClassName(open),
        subtitle: 'students',
        hint: 'Search this class',
        empty: 'No students in this class yet.',
        onBack: () => setState(() => _open = null),
        load: (search, page) => DepartmentApi.students(search: search, classId: '${open['id']}', page: page),
        keep: (_) => true,
        tile: _studentTile,
      );
    }
    final scope = DepartmentScope(widget.user.departmentHeads);
    return _PagedList(
      title: 'Classes',
      subtitle: 'in your department',
      hint: '',
      search: false,
      empty: 'No classes in your department yet.',
      onBack: widget.onBack,
      load: (_, __) => DepartmentApi.classes(),
      keep: scope.hasClass,
      tile: (context, row) {
        final teachers = [for (final t in FeedingApi.rows(row['teachers'])) textOf(t['full_name']) ?? ''].where((n) => n.isNotEmpty).join(', ');
        return NavListRow(
          title: departmentClassName(row),
          subtitle: teachers.isEmpty ? 'No class teacher yet' : 'Class teacher: $teachers',
          onTap: () => setState(() => _open = row),
        );
      },
    );
  }
}

/// A day's attendance for the department, students or staff, like the
/// website's Attendance page for a head (view only).
class DepartmentAttendanceScreen extends StatefulWidget {
  const DepartmentAttendanceScreen({super.key, required this.user, this.onBack});

  final AppUser user;
  final VoidCallback? onBack;

  @override
  State<DepartmentAttendanceScreen> createState() => _DepartmentAttendanceScreenState();
}

class _DepartmentAttendanceScreenState extends State<DepartmentAttendanceScreen> {
  static const _statuses = [
    ('all', 'Total', 'total'),
    ('present', 'Present', 'present'),
    ('absent', 'Absent', 'absent'),
    ('late', 'Late', 'late'),
    ('authorized_absence', 'Excused', 'excused'),
  ];

  DateTime _day = DateTime.now();
  String _person = 'student';
  String _status = 'all';
  String _classId = '';
  List<Map<String, dynamic>> _classes = const [];
  Set<String> _outside = const {};
  final _rows = <Map<String, dynamic>>[];
  Map<String, dynamic>? _summary;
  var _page = 0;
  var _lastPage = 1;
  var _loading = true;
  var _more = false;
  String? _error;
  var _request = 0;

  late final DepartmentScope _scope = DepartmentScope(widget.user.departmentHeads);

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _reload();
  }

  Future<void> _loadClasses() async {
    if (!widget.user.permissions.contains('classes.view')) return;
    try {
      final page = await DepartmentApi.classes();
      if (!mounted) return;
      setState(() {
        _classes = page.rows.where(_scope.hasClass).toList();
        _outside = {for (final c in page.rows) if (!_scope.hasClass(c)) '${c['id']}'};
      });
    } catch (_) {
      // The class filter just stays hidden.
    }
  }

  bool _keep(Map<String, dynamic> row) {
    if (_person == 'staff') return row['staff'] is! Map || _scope.hasStaff(Map<String, dynamic>.from(row['staff'] as Map));
    final classId = textOf(row['class_id']) ?? (row['student'] is Map ? departmentStudentClassId(Map<String, dynamic>.from(row['student'] as Map)) : '');
    return !_outside.contains(classId);
  }

  Future<void> _reload() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await DepartmentApi.attendance(
        date: dateKey(_day),
        personType: _person,
        status: _status,
        classId: _person == 'student' ? _classId : '',
      );
      if (!mounted || request != _request) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(page.rows.where(_keep));
        _summary = page.summary;
        _page = 1;
        _lastPage = page.lastPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _more = true);
    try {
      final page = await DepartmentApi.attendance(
        date: dateKey(_day),
        personType: _person,
        status: _status,
        classId: _person == 'student' ? _classId : '',
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.rows.where(_keep));
        _page++;
        _lastPage = page.lastPage;
      });
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked == null) return;
    setState(() => _day = picked);
    _reload();
  }

  Widget _row(Map<String, dynamic> row) {
    final person = row[_person] is Map ? row[_person] as Map : const {};
    final (label, tone) = departmentAttendanceStatus(row['status']);
    final inAt = textOf(row['check_in_at']);
    final outAt = textOf(row['check_out_at']);
    final times = [if (inAt != null) 'In ${timeLabel(inAt)}', if (outAt != null) 'Out ${timeLabel(outAt)}'].join(' · ');
    final about = _person == 'staff'
        ? textOf(person['position']) ?? ''
        : textOf(row['class_name']) ?? textOf(person['current_class'] is Map ? (person['current_class'] as Map)['name'] : person['current_class']) ?? '';
    return _PersonTile(
      name: textOf(person['full_name']) ?? (_person == 'staff' ? 'Staff member' : 'Student'),
      lines: [about, times],
      badge: FeedBadge(label, tone: tone),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final missing = intOf(summary?['missing_checkout']);
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(title: 'Attendance', subtitle: _departmentNames(context, widget.user), onBack: widget.onBack),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppLayout.page(context),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tab in const [('student', 'Students'), ('staff', 'Staff')])
                        ChoiceChip(
                          label: Text(tab.$2),
                          selected: _person == tab.$1,
                          onSelected: (_) {
                            if (_person == tab.$1) return;
                            setState(() {
                              _person = tab.$1;
                              _status = 'all';
                            });
                            _reload();
                          },
                        ),
                      OutlinedButton.icon(
                        onPressed: _pickDay,
                        icon: const Icon(Icons.event_rounded, size: 16),
                        label: Text(dayLabel(dateKey(_day))),
                      ),
                    ],
                  ),
                  if (_person == 'student' && _classes.length > 1) ...[
                    const SizedBox(height: 4),
                    AppSelect(
                      label: 'Class',
                      value: _classes.where((c) => '${c['id']}' == _classId).map(departmentClassName).firstOrNull ?? 'All classes',
                      items: ['All classes', for (final c in _classes) departmentClassName(c)],
                      onChanged: (name) {
                        setState(() => _classId = '${_classes.where((c) => departmentClassName(c) == name).firstOrNull?['id'] ?? ''}');
                        _reload();
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in _statuses)
                        ChoiceChip(
                          label: Text(summary == null ? s.$2 : '${s.$2} ${intOf(summary[s.$3])}'),
                          selected: _status == s.$1,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) {
                            if (_status == s.$1) return;
                            setState(() => _status = s.$1);
                            _reload();
                          },
                        ),
                    ],
                  ),
                  if (_person == 'staff' && missing > 0) ...[
                    const SizedBox(height: 8),
                    MutedText('$missing with no check-out', size: 12.5),
                  ],
                  const SizedBox(height: 12),
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    _Problem(message: _error!, onRetry: _reload)
                  else if (_rows.isEmpty)
                    WhiteCard(padding: const EdgeInsets.all(14), child: const MutedText('No attendance recorded for this day.'))
                  else ...[
                    for (final row in _rows) _row(row),
                    if (_page < _lastPage)
                      Center(
                        child: OutlinedButton(
                          onPressed: _more ? null : _loadMore,
                          child: Text(_more ? 'Loading…' : 'Load more'),
                        ),
                      ),
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

/// A main head's "Department heads": each department they lead.
class DepartmentHeadsScreen extends StatelessWidget {
  const DepartmentHeadsScreen({super.key, required this.user, this.onBack});

  final AppUser user;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final led = user.departmentHeads.where((h) => h.isMain).toList();
    String name(DepartmentHeadship h) =>
        h.departmentName.isNotEmpty ? h.departmentName : store.departments.where((d) => d.id == h.departmentId).firstOrNull?.name ?? 'Your department';
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(title: 'Department heads', subtitle: 'Who helps run your department', onBack: onBack),
          Expanded(
            child: ListView(
              padding: AppLayout.page(context),
              children: [
                for (final head in led)
                  NavListRow(
                    title: name(head),
                    subtitle: 'Add assistants and choose what they can do',
                    icon: Icons.manage_accounts_rounded,
                    onTap: () => showDepartmentHeadsSheet(context, departmentId: head.departmentId, departmentName: name(head)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Add or remove a department's heads, like the website's "Heads of …" form.
/// What may be changed comes from the server (`can_manage_main`,
/// `can_manage_assistants`): the admin sets the main head, and a main head
/// looks after their assistants. Saving also refreshes the signed-in user, so
/// heads who edit themselves see the result straight away.
Future<void> showDepartmentHeadsSheet(BuildContext context, {required String departmentId, required String departmentName}) async {
  final store = SchoolScope.read(context);
  final saved = await showAppSheet<bool>(
    context: context,
    title: 'Heads of $departmentName',
    builder: (_) => _DepartmentHeadsForm(departmentId: departmentId),
  );
  if (saved != true) return;
  await store.refreshSessionProfile(force: true);
  await store.syncFromApi();
}

class _DepartmentHeadsForm extends StatefulWidget {
  const _DepartmentHeadsForm({required this.departmentId});

  final String departmentId;

  @override
  State<_DepartmentHeadsForm> createState() => _DepartmentHeadsFormState();
}

class _DepartmentHeadsFormState extends State<_DepartmentHeadsForm> {
  DepartmentHeadsInfo? _info;
  String? _error;
  var _saving = false;
  String _savedSignature = '';
  final _heads = <EditableDepartmentHead>[];

  // Adding a head: pick a person, then their role.
  List<Map<String, dynamic>> _results = const [];
  var _searching = false;
  Map<String, dynamic>? _picked;
  Timer? _debounce;
  var _searchRequest = 0;
  final _opened = <String>{};

  String? get _myStaffId {
    final staff = ApiSession.instance.user?['staff'];
    return staff is Map ? textOf(staff['id']) : null;
  }

  bool get _canMain => _info?.canManageMain ?? false;
  bool get _canAssistants => _info?.canManageAssistants ?? false;

  String get _signature {
    final rows = [for (final h in _heads) h.toJson().toString()]..sort();
    return rows.join('|');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await DepartmentApi.heads(widget.departmentId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _heads
          ..clear()
          ..addAll(info.heads);
        _savedSignature = _signature;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the heads. $e');
    }
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      _searchRequest++;
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final request = ++_searchRequest;
      setState(() => _searching = true);
      try {
        final page = await DepartmentApi.staff(search: text, perPage: 20);
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _results = page.rows;
          _searching = false;
        });
      } catch (e) {
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _results = const [];
          _searching = false;
          _error = 'Could not search staff. $e';
        });
      }
    });
  }

  void _add(bool asMain) {
    final picked = _picked;
    if (picked == null) return;
    final id = '${picked['id']}';
    if (_heads.any((h) => h.staffId == id)) return;
    setState(() {
      _heads.add(EditableDepartmentHead(
        staffId: id,
        fullName: textOf(picked['full_name']) ?? 'Staff member',
        phone: textOf(picked['phone']) ?? '',
        isMain: asMain,
      ));
      if (!asMain) _opened.add(id);
      _picked = null;
      _results = const [];
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await DepartmentApi.saveHeads(widget.departmentId, _heads);
      if (!mounted) return;
      showSnack(context, 'Department heads saved.');
      closeRoute(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _check(String label, bool value, ValueChanged<bool>? onChanged) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      visualDensity: VisualDensity.compact,
      title: Text(label, style: AppText.body(size: 13, color: AppColors.slate800)),
      value: value,
      onChanged: onChanged == null ? null : (on) => onChanged(on == true),
    );
  }

  Widget _headCard(EditableDepartmentHead head) {
    final editable = _canMain || (!head.isMain && _canAssistants) || (head.isMain && head.staffId == _myStaffId);
    final removable = head.isMain ? _canMain : _canAssistants;
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in _info?.assistantPermissions ?? const <Map<String, dynamic>>[]) {
      (groups[textOf(p['group']) ?? 'Other'] ??= []).add(p);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(head.fullName, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.slate800))),
              if (removable)
                TextButton.icon(
                  onPressed: () => setState(() => _heads.remove(head)),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Remove'),
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final role in const [(true, 'Main head'), (false, 'Assistant')])
                ChoiceChip(
                  label: Text(role.$2),
                  selected: head.isMain == role.$1,
                  visualDensity: VisualDensity.compact,
                  onSelected: _canMain ? (_) => setState(() => head.isMain = role.$1) : null,
                ),
            ],
          ),
          _check('Notify on every teacher scan', head.notifyScans, editable
              ? (on) => setState(() {
                    head.notifyScans = on;
                    if (!on) head.notifySms = false;
                  })
              : null),
          _check(
            head.phone.isEmpty ? 'Also by SMS (no phone on record)' : 'Also by SMS',
            head.notifyScans && head.notifySms,
            editable && head.notifyScans ? (on) => setState(() => head.notifySms = on) : null,
          ),
          if (!head.isMain && groups.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _opened.contains(head.staffId) ? _opened.remove(head.staffId) : _opened.add(head.staffId)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'What this assistant can do (${head.permissions.length} ticked)',
                        style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.slate800),
                      ),
                    ),
                    Icon(_opened.contains(head.staffId) ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.slate500),
                  ],
                ),
              ),
            ),
            if (_opened.contains(head.staffId))
              for (final group in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(group.key.toUpperCase(), style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.slate500)),
                ),
                for (final p in group.value)
                  _check(
                    textOf(p['label']) ?? '${p['name']}',
                    head.permissions.contains('${p['name']}'),
                    _canAssistants
                        ? (on) => setState(() => on ? head.permissions.add('${p['name']}') : head.permissions.remove('${p['name']}'))
                        : null,
                  ),
              ],
          ],
        ],
      ),
    );
  }

  Widget _adder() {
    final picked = _picked;
    if (picked != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add ${textOf(picked['full_name']) ?? 'this person'} as:', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.slate800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_canMain) OutlinedButton(onPressed: () => _add(true), child: const Text('Main head')),
              OutlinedButton(onPressed: () => _add(false), child: const Text('Assistant')),
              TextButton(onPressed: () => setState(() => _picked = null), child: const Text('Cancel')),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: _onSearch,
          decoration: appFieldDecoration(context, hint: 'Search for a staff member to add').copyWith(prefixIcon: const Icon(Icons.person_search_rounded, size: 20)),
        ),
        if (_searching) const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
        for (final person in _results)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(textOf(person['full_name']) ?? 'Staff member', style: AppText.body(size: 13.5, color: AppColors.slate800)),
            subtitle: _heads.any((h) => h.staffId == '${person['id']}') ? const Text('Already a head') : null,
            enabled: !_heads.any((h) => h.staffId == '${person['id']}'),
            onTap: () => setState(() => _picked = person),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null) {
      return _error != null
          ? Text(_error!, style: AppText.body(size: 13, color: const Color(0xFFB91C1C)))
          : const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    final dirty = _signature != _savedSignature;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A head sees only this department’s teachers, classes and students. The main head publishes its results; an assistant has only what’s ticked below.',
          style: AppText.body(size: 12.5, color: AppColors.slate500),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Text(_error!, style: AppText.body(size: 13, color: const Color(0xFFB91C1C))),
          const SizedBox(height: 8),
        ],
        if (_heads.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('No heads yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
          ),
        for (final head in _heads) _headCard(head),
        if (_canAssistants || _canMain) ...[
          _adder(),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || !dirty || _picked != null ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save heads'),
          ),
        ],
      ],
    );
  }
}
