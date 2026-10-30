import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/daily_report_trends.dart';
import '../widgets/popups.dart';
import '../widgets/report_photos.dart';
import 'admin_forms.dart';

class SchoolLifeScreen extends StatefulWidget {
  const SchoolLifeScreen({
    super.key,
    required this.user,
    required this.onBack,
    required this.onLogout,
    this.initialTab,
  });

  final AppUser user;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  /// Opens straight to this tab (e.g. the drawer's "Exams" entry) instead
  /// of always landing on the first one. Announcements have their own
  /// screen (AnnouncementsScreen), reached from the header's comms menu.
  final String? initialTab;

  @override
  State<SchoolLifeScreen> createState() => _SchoolLifeScreenState();
}

class _SchoolLifeScreenState extends State<SchoolLifeScreen> {
  late String _tab;

  /// Plan module behind each tab; tabs the school's plan leaves out are
  /// not shown at all.
  static const _tabModule = {
    'Timetable': 'timetable_assignments',
    'Homework': 'timetable_assignments',
    'Exams': 'academics',
    'Reports': 'academics',
    'Daily report': 'daily_reports',
    'Departments': 'school_structure',
    'Transport': 'operations',
    'Leave': 'operations',
    'Library': 'operations',
    'Inventory': 'operations',
  };

  List<String> get _tabs {
    final role = widget.user.role;
    final List<String> all;
    if (role == Role.parent) {
      all = const ['Calendar', 'Timetable', 'Homework', 'Exams', 'Reports', 'Daily report', 'Transport', 'Home study', 'Library'];
    } else if (role == Role.teacher) {
      all = const ['Calendar', 'Timetable', 'Departments', 'Homework', 'Exams', 'Leave', 'Home study'];
    } else if (role == Role.cashier) {
      all = const ['Calendar'];
    } else {
      all = const ['Calendar', 'Departments', 'Exams', 'Transport', 'Leave', 'Home study', 'Library', 'Inventory'];
    }
    return [
      for (final tab in all)
        if (_tabModule[tab] == null || PlanAccess.hasModule(_tabModule[tab]!)) tab,
    ];
  }

  @override
  void initState() {
    super.initState();
    final wanted = widget.initialTab;
    _tab = wanted != null && _tabs.contains(wanted) ? wanted : _tabs.first;
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final tabs = _tabs;
    if (!tabs.contains(_tab)) _tab = tabs.first;
    return Column(
      children: [
        TopBar(
          title: widget.user.role == Role.cashier ? 'School Calendar' : 'School life',
          subtitle: widget.user.role.isAdminPortal
              ? 'Live records from the school office'
              : widget.user.role == Role.teacher
                  ? 'Class work, leave and home study'
                  : widget.user.role == Role.cashier
                      ? 'Events and holidays'
                      : 'School life for ${store.focusedChild(Role.parent)?.name ?? 'your child'}',
          onBack: widget.onBack,
          onLogout: widget.onLogout,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              if (store.syncError != null) ...[
                WhiteCard(
                  padding: const EdgeInsets.all(12),
                  child: Text(store.syncError!, style: AppText.body(size: 12, color: AppColors.slate700)),
                ),
                const SizedBox(height: 12),
              ],
              if (tabs.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in tabs)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = tab),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _tab == tab ? AppColors.accent : AppSurface.card(context),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _tab == tab ? AppColors.accent : AppSurface.line(context)),
                            ),
                            child: Text(
                              tab,
                              style: AppText.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: _tab == tab ? Colors.white : AppSurface.muted(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._body(store),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _forChild(SchoolStore store, List<Map<String, dynamic>> rows) {
    // A teacher sees their own homework here, not other teachers'.
    if (widget.user.role == Role.teacher) return [for (final row in rows) if (store.isMyClassWork(row)) row];
    if (widget.user.role != Role.parent) return rows;
    final child = store.focusedChild(Role.parent);
    if (child == null) return rows;
    return [for (final row in rows) if (store.rowMatchesStudent(row, child)) row];
  }

  List<Widget> _body(SchoolStore store) {
    return switch (_tab) {
      'Calendar' => _list(
          store.tableRows('calendar_events'),
          empty: 'No calendar events yet.',
          title: (row) => _s(row['title']),
          detail: (row) => [
            _s(row['event_type']),
            formatStamp(_s(row['start_date'])),
            if (_s(row['end_date']).isNotEmpty && _s(row['end_date']) != _s(row['start_date'])) formatStamp(_s(row['end_date'])),
            _s(row['location']),
          ].where((p) => p.isNotEmpty).join(' · '),
          badge: (row) => _s(row['event_type']).isEmpty ? 'Event' : _s(row['event_type']),
        ),
      'Timetable' => _list(
          [
            for (final s in store.timetable)
              if (widget.user.role != Role.parent ||
                  store.focusedChild(Role.parent) == null ||
                  store.slotMatchesChild(s, store.focusedChild(Role.parent)!))
                {
                  'title': s.subject.isEmpty ? 'Lesson' : s.subject,
                  'detail': [s.day, s.end.isEmpty ? s.start : '${s.start} – ${s.end}', s.className, s.teacher, s.room]
                      .where((p) => p.isNotEmpty)
                      .join(' · '),
                },
          ],
          empty: 'No timetable published yet.',
          title: (row) => _s(row['title']),
          detail: (row) => _s(row['detail']),
          badge: (row) => 'Lesson',
        ),
      'Departments' => _list(
          store.tableRows('departments'),
          empty: 'No departments yet.',
          title: (row) => _s(row['name']),
          detail: (row) => _s(row['description']),
          badge: (row) => _s(row['status']).isEmpty ? 'Dept' : _s(row['status']),
        ),
      'Homework' => _list(
          _forChild(store, store.tableRows('assignments')),
          empty: 'No homework posted yet.',
          title: (row) => _s(row['title']),
          detail: (row) => [
            _mapName(row['subject']),
            _mapName(row['class'], fallbackKeys: const ['name', 'stream']),
            if (_s(row['deadline']).isNotEmpty) 'Due ${_s(row['deadline'])}',
            _mapName(row['teacher'], fallbackKeys: const ['full_name']),
          ].where((p) => p.isNotEmpty).join(' · '),
          badge: (row) => _s(row['deadline']).isEmpty ? 'Open' : 'Due',
          body: (row) => _s(row['instructions']),
        ),
      'Exams' => _list(
          _forChild(store, store.tableRows('exams')),
          empty: 'No exams on file.',
          title: (row) => _s(row['name']),
          detail: (row) => [
            _mapName(row['subject']),
            _mapName(row['class']),
            formatStamp(_s(row['exam_date'])),
            if (row['published'] == true) 'Published',
          ].where((p) => p.isNotEmpty).join(' · '),
          badge: (row) => row['published'] == true ? 'Live' : _s(row['kind']).isEmpty ? 'Exam' : _s(row['kind']),
          body: widget.user.role != Role.parent
              ? null
              : (row) {
                  if (row['published'] != true) return '';
                  final child = store.focusedChild(Role.parent);
                  if (child == null) return '';
                  final subject = _mapName(row['subject']);
                  final mark = store.academics
                      .where((m) => m.student == child.name && (subject.isEmpty || m.subject == subject))
                      .firstOrNull;
                  if (mark == null) return '';
                  return [
                    'Score ${mark.score}%',
                    if (mark.grade.isNotEmpty) 'Grade ${mark.grade}',
                    if (mark.remark.trim().isNotEmpty) mark.remark.trim(),
                  ].join(' · ');
                },
        ),
      'Reports' => _list(
          _forChild(store, store.tableRows('report_cards')),
          empty: widget.user.role == Role.parent
              ? 'No reports have been sent yet. You will see them here after admin sends them.'
              : 'No report cards yet.',
          title: (row) => row['student'] is Map ? _s((row['student'] as Map)['full_name']) : 'Report card',
          detail: (row) => [
            _mapName(row['class']),
            _s(row['status']),
            formatStamp(_s(row['created_at'])),
          ].where((p) => p.isNotEmpty).join(' · '),
          badge: (row) => _s(row['status']).isEmpty ? 'Report' : _s(row['status']),
        ),
      'Daily report' => _dailyReport(store),
      'Transport' => _transport(store),
      'Home study' => _homeStudy(store),
      'Leave' => _leave(store),
      'Library' => _list(
          store.tableRows('library_books'),
          empty: 'No library titles yet.',
          title: (row) => _s(row['title']),
          detail: (row) => [
            _s(row['author']),
            if (_s(row['isbn']).isNotEmpty) 'ISBN ${_s(row['isbn'])}',
            _s(row['shelf_location']),
            if (row['available_copies'] != null) '${row['available_copies']} in',
          ].where((p) => p.isNotEmpty).join(' · '),
          badge: (row) => '${row['available_copies'] ?? 'Book'}',
        ),
      'Inventory' => _list(
          store.tableRows('inventory_items'),
          empty: 'No inventory items yet.',
          title: (row) => _s(row['name']),
          detail: (row) => [
            _s(row['category']),
            _s(row['condition']),
            _s(row['serial_number']),
            if (row['assignee'] is Map) _s((row['assignee'] as Map)['full_name']),
          ].where((p) => p.isNotEmpty).join(' · '),
          badge: (row) => _s(row['status']).isEmpty ? 'Item' : _s(row['status']),
        ),
      _ => [_empty('Nothing here yet.')],
    };
  }

  List<Widget> _dailyReport(SchoolStore store) {
    final child = store.focusedChild(Role.parent);
    if (child == null) return [_empty('No linked child yet.')];
    return [_ParentDailyReportCard(child: child, siblings: store.linkedChildren(Role.parent))];
  }

  List<Widget> _transport(SchoolStore store) {
    final rows = _forChild(store, store.tableRows('student_transports'));
    final routes = store.tableRows('bus_routes');
    final buses = store.tableRows('buses');
    if (rows.isEmpty && routes.isEmpty && buses.isEmpty) {
      return [_empty('No bus or pickup records yet.')];
    }
    return [
      if (rows.isNotEmpty) ..._list(
        rows,
        empty: '',
        title: (row) => row['student'] is Map ? _s((row['student'] as Map)['full_name']) : 'Pupil transport',
        detail: (row) => [
          row['bus_route'] is Map ? _s((row['bus_route'] as Map)['name']) : '',
          _s(row['pickup_point']),
          _s(row['status']),
        ].where((p) => p.isNotEmpty).join(' · '),
        badge: (row) => _s(row['status']).isEmpty ? 'Route' : _s(row['status']),
      ),
      if (widget.user.role.isAdminPortal) ...[
        if (rows.isNotEmpty) const SizedBox(height: 8),
        ..._list(
          buses,
          empty: 'No buses on file.',
          title: (row) => _s(row['name']).isNotEmpty ? _s(row['name']) : _s(row['registration_number']),
          detail: (row) => [
            _s(row['registration_number']),
            if (row['capacity'] != null) '${row['capacity']} seats',
            _s(row['status']),
          ].where((p) => p.isNotEmpty).join(' · '),
          badge: (row) => _s(row['status']).isEmpty ? 'Bus' : _s(row['status']),
        ),
        ..._list(
          routes,
          empty: 'No routes on file.',
          title: (row) => _s(row['name']),
          detail: (row) => [
            _s(row['departure_time']),
            _s(row['return_time']),
            if (row['monthly_fee'] != null) 'GHS ${row['monthly_fee']}',
          ].where((p) => p.isNotEmpty).join(' · '),
          badge: (_) => 'Route',
        ),
      ],
    ];
  }

  List<Widget> _homeStudy(SchoolStore store) {
    final canRequest = widget.user.role == Role.parent || widget.user.role == Role.teacher;
    final canDecide = widget.user.role.isAdminPortal || widget.user.role == Role.teacher;
    return [
      if (canRequest)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HoneyButton(label: 'Request home study', onPressed: () => _requestHomeStudy(store)),
        ),
      ..._list(
        _forChild(store, store.tableRows('home_study_engagements')),
        empty: 'No home-study requests yet.',
        title: (row) => row['student'] is Map ? _s((row['student'] as Map)['full_name']) : 'Home study',
        detail: (row) => [
          _mapName(row['teacher'], fallbackKeys: const ['full_name']),
          _mapName(row['subject']),
          _s(row['purpose']),
          _s(row['status']),
        ].where((p) => p.isNotEmpty).join(' · '),
        badge: (row) => _s(row['status']).isEmpty ? 'Request' : _s(row['status']),
        actions: canDecide
            ? (row) {
                if (_s(row['status']).toLowerCase().contains('pending')) {
                  return [
                    ('Approve', true),
                    ('Decline', false),
                  ];
                }
                return const <(String, bool)>[];
              }
            : null,
        onAction: (row, approve) async {
          final error = await store.decideHomeStudy('${row['id']}', approve: approve);
          if (!mounted) return;
          showSnack(context, error.isEmpty ? (approve ? 'Home study approved.' : 'Home study declined.') : error);
        },
      ),
    ];
  }

  List<Widget> _leave(SchoolStore store) {
    final teacher = widget.user.role == Role.teacher;
    final admin = widget.user.role.isAdminPortal;
    return [
      if (teacher)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HoneyButton(label: 'Request leave', onPressed: () => _requestLeave(store)),
        ),
      ..._list(
        store.tableRows('leave_requests'),
        empty: 'No leave requests yet.',
        title: (row) => row['staff'] is Map ? _s((row['staff'] as Map)['full_name']) : 'Leave',
        detail: (row) => [
          _s(row['leave_type']),
          formatStamp(_s(row['start_date'])),
          formatStamp(_s(row['end_date'])),
          _s(row['reason']),
          _s(row['status']),
        ].where((p) => p.isNotEmpty).join(' · '),
        badge: (row) => _s(row['status']).isEmpty ? 'Leave' : _s(row['status']),
        actions: admin
            ? (row) {
                if (_s(row['status']).toLowerCase() == 'pending') {
                  return const [('Approve', true), ('Decline', false)];
                }
                return const <(String, bool)>[];
              }
            : null,
        onAction: (row, approve) async {
          final error = await store.decideLeave('${row['id']}', approve: approve);
          if (!mounted) return;
          showSnack(context, error.isEmpty ? (approve ? 'Leave approved.' : 'Leave declined.') : error);
        },
      ),
    ];
  }

  List<Widget> _list(
    List<Map<String, dynamic>> rows, {
    required String empty,
    required String Function(Map<String, dynamic>) title,
    required String Function(Map<String, dynamic>) detail,
    required String Function(Map<String, dynamic>) badge,
    String Function(Map<String, dynamic>)? body,
    List<(String, bool)> Function(Map<String, dynamic>)? actions,
    Future<void> Function(Map<String, dynamic>, bool approve)? onAction,
  }) {
    if (rows.isEmpty) return empty.isEmpty ? const [] : [_empty(empty)];
    return [
      for (final row in rows) ...[
        WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: title(row), tone: Tone.honey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title(row), style: AppText.body(weight: FontWeight.w800)),
                        if (detail(row).isNotEmpty)
                          Text(detail(row), style: AppText.body(size: 12, color: AppColors.slate500)),
                      ],
                    ),
                  ),
                  StatusBadge(text: badge(row), tone: Tone.slate),
                ],
              ),
              if (body != null && body(row).trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  body(row).trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 13, color: AppColors.slate600),
                ),
              ],
              if (actions != null && onAction != null && actions(row).isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final action in actions(row)) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onAction(row, action.$2),
                          child: Text(action.$1),
                        ),
                      ),
                      if (action != actions(row).last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _empty(String text) => WhiteCard(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: AppText.body(size: 13, color: AppColors.slate500)),
      );

  Future<void> _requestHomeStudy(SchoolStore store) async {
    if (store.students.isEmpty || store.teachers.isEmpty) {
      showSnack(context, 'Need a linked child and a teacher first.');
      return;
    }
    var studentId = store.students.first.id;
    var teacherId = store.teachers.first.id;
    final purpose = TextEditingController();
    await showAppSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Home study', style: AppText.display(size: 18)),
                const SizedBox(height: 12),
                AdminDropdown(
                  label: 'Child',
                  value: store.students.any((s) => s.id == studentId) ? store.students.firstWhere((s) => s.id == studentId).name : store.students.first.name,
                  items: store.studentNames,
                  onChanged: (name) {
                    final match = store.students.where((s) => s.name == name);
                    if (match.isNotEmpty) setLocal(() => studentId = match.first.id);
                  },
                ),
                AdminDropdown(
                  label: 'Teacher',
                  value: store.teachers.any((t) => t.id == teacherId) ? store.teachers.firstWhere((t) => t.id == teacherId).name : store.teachers.first.name,
                  items: store.teacherNames,
                  onChanged: (name) {
                    final match = store.teachers.where((t) => t.name == name);
                    if (match.isNotEmpty) setLocal(() => teacherId = match.first.id);
                  },
                ),
                TextField(
                  controller: purpose,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Purpose'),
                ),
                const SizedBox(height: 12),
                HoneyButton(
                  label: 'Send request',
                  onPressed: () async {
                    final error = await store.requestHomeStudy(
                      studentId: studentId,
                      teacherStaffId: teacherId,
                      purpose: purpose.text,
                    );
                    if (!ctx.mounted) return;
                    closeRoute(ctx);
                    if (!mounted) return;
                    showSnack(context, error.isEmpty ? 'Home-study request sent.' : error);
                  },
                ),
              ],
            );
          },
        );
      },
    );
    disposeAfterClose([purpose]);
  }

  Future<void> _requestLeave(SchoolStore store) async {
    var type = 'annual';
    final start = TextEditingController();
    final end = TextEditingController();
    final reason = TextEditingController();
    await showAppSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Staff leave', style: AppText.display(size: 18)),
                const SizedBox(height: 12),
                AdminDropdown(
                  label: 'Type',
                  value: type,
                  items: const ['annual', 'sick', 'maternity', 'emergency', 'other'],
                  onChanged: (v) => setLocal(() => type = v),
                ),
                TextField(controller: start, decoration: const InputDecoration(labelText: 'Start date (YYYY-MM-DD)')),
                const SizedBox(height: 8),
                TextField(controller: end, decoration: const InputDecoration(labelText: 'End date (YYYY-MM-DD)')),
                const SizedBox(height: 8),
                TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason')),
                const SizedBox(height: 12),
                HoneyButton(
                  label: 'Submit leave',
                  onPressed: () async {
                    final error = await store.requestLeave(
                      leaveType: type,
                      startDate: start.text.trim(),
                      endDate: end.text.trim(),
                      reason: reason.text,
                    );
                    if (!ctx.mounted) return;
                    closeRoute(ctx);
                    if (!mounted) return;
                    showSnack(context, error.isEmpty ? 'Leave request sent.' : error);
                  },
                ),
              ],
            );
          },
        );
      },
    );
    disposeAfterClose([start, end, reason]);
  }

  String _s(dynamic value) => value == null ? '' : '$value'.trim();

  String _mapName(dynamic value, {List<String> fallbackKeys = const ['name', 'full_name']}) {
    if (value is! Map) return '';
    for (final key in fallbackKeys) {
      final text = _s(value[key]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

/// Read-only view of a child's KG/Nursery daily report for a given day —
/// the teacher side (TeacherDailyReportsScreen) already composes and sends
/// these, but nothing on the parent side ever fetched or displayed one.
class _ParentDailyReportCard extends StatefulWidget {
  const _ParentDailyReportCard({required this.child, this.siblings = const []});

  final Student child;

  /// Every child linked to this parent — a daily report is per child, so the
  /// card lets the parent pick which one to read.
  final List<Student> siblings;

  @override
  State<_ParentDailyReportCard> createState() => _ParentDailyReportCardState();
}

class _ParentDailyReportCardState extends State<_ParentDailyReportCard> {
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _sent = false;
  bool _failed = false;
  String _error = '';
  Map<String, dynamic> _fields = const {};
  bool _ready = false;
  Timer? _poll;
  late Student _child = widget.child;
  String _tab = 'today';
  bool _weekLoading = false;
  String _weekError = '';
  Map<String, Map<String, dynamic>>? _week;

  static List<String> get _weekDays {
    final now = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final d = DateTime(now.year, now.month, now.day - i);
          return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        }(),
    ];
  }

  String get _firstName {
    final parts = _child.name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Your child' : parts.first;
  }

  Future<void> _loadWeek() async {
    setState(() {
      _weekLoading = true;
      _weekError = '';
    });
    final result = await SchoolScope.of(context).fetchDailyReportWeek(_child, _weekDays);
    if (!mounted) return;
    setState(() {
      _weekLoading = false;
      _weekError = result.error;
      _week = result.byDay;
    });
  }

  static const _mealLevelLabels = {'all': 'Ate it all', 'most': 'Most of it', 'some': 'Some of it', 'none': "Didn't eat", 'skipped': 'Skipped'};

  String get _dateKey {
    final m = _date.month.toString().padLeft(2, '0');
    final d = _date.day.toString().padLeft(2, '0');
    return '${_date.year}-$m-$d';
  }

  bool get _isToday {
    final now = DateTime.now();
    return now.year == _date.year && now.month == _date.month && now.day == _date.day;
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _load();
    // A report the teacher sends while this screen is open shows up on its
    // own, without the parent having to leave and come back.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final store = SchoolScope.of(context);
    final result = await store.fetchSentDailyReport(_child, _dateKey);
    if (!mounted) return;
    if (result.error.isNotEmpty) {
      // Keep whatever is on screen on a background refresh; only flag the
      // failure when there is nothing to show.
      setState(() {
        _loading = false;
        if (!quiet || !_sent) {
          _failed = true;
          _error = result.error;
        }
      });
      return;
    }
    setState(() {
      _loading = false;
      _failed = false;
      _error = '';
      _sent = result.report != null;
      _fields = result.report ?? const {};
    });
  }

  void _shiftDate(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
    _load();
  }

  Widget _tabButton(String key, String label) {
    final selected = _tab == key;
    return Material(
      color: selected ? AppColors.navy : AppSurface.line(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (selected) return;
          setState(() => _tab = key);
          if (key == 'trends' && _week == null && !_weekLoading) _loadWeek();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Text(label, style: AppText.body(size: 14, weight: FontWeight.w700, color: selected ? Colors.white : AppSurface.text(context))),
        ),
      ),
    );
  }

  Widget _header() {
    final initials = _child.name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
    final when = '${_date.day} ${months[_date.month - 1]} ${_date.year}';
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.navy,
          child: Text(initials, style: AppText.body(size: 14, weight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$_firstName's Day", style: AppText.display(size: 20, weight: FontWeight.w700)),
              Text(
                [when, if (_child.klass.isNotEmpty) _child.klass].join(' · '),
                style: AppText.body(size: 12, color: AppSurface.muted(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trends() {
    if (_weekLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_weekError.isNotEmpty && (_week == null || _week!.isEmpty)) {
      return Row(
        children: [
          Expanded(child: Text('Could not load this week: $_weekError', style: AppText.body(size: 13, color: AppColors.slate500))),
          TextButton(onPressed: _loadWeek, child: const Text('Retry')),
        ],
      );
    }
    return DailyReportTrends(days: _weekDays, byDay: _week ?? const {}, firstName: _firstName);
  }

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 12),
          Row(
            children: [
              _tabButton('today', _isToday ? 'Today' : 'Day'),
              const SizedBox(width: 8),
              _tabButton('trends', 'Trends'),
            ],
          ),
          if (widget.siblings.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final kid in widget.siblings)
                  ChoiceChip(
                    label: Text(kid.name, style: AppText.body(size: 12, weight: FontWeight.w700)),
                    selected: kid.id == _child.id,
                    onSelected: (_) {
                      if (kid.id == _child.id) return;
                      setState(() {
                        _child = kid;
                        _sent = false;
                        _fields = const {};
                        _week = null;
                      });
                      _load();
                      if (_tab == 'trends') _loadWeek();
                    },
                  ),
              ],
            ),
          ],
          const Divider(height: 24),
          if (_tab == 'trends') _trends() else ..._today(),
        ],
      ),
    );
  }

  List<Widget> _today() {
    return [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _loading ? null : () => _shiftDate(-1),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  _isToday ? 'Today · $_dateKey' : _dateKey,
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 13, weight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _loading || _isToday ? null : () => _shiftDate(1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Could not load the daily report: $_error',
                      style: AppText.body(size: 13, color: AppColors.slate500),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else if (!_sent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No daily report sent for ${_child.name} on this date yet.',
                style: AppText.body(size: 13, color: AppColors.slate500),
              ),
            )
          else ...[
            _moodBlock(),
            const SizedBox(height: 12),
            if (_photos.isNotEmpty) ...[
              ReportPhotoGallery(photos: _photos),
              const SizedBox(height: 12),
            ],
            if ('${_fields['note'] ?? ''}'.trim().isNotEmpty) ...[
              _noteBlock(),
              const SizedBox(height: 14),
            ],
            Text('MEALS', style: AppText.label()),
            const SizedBox(height: 6),
            _mealRow('Breakfast', '${_fields['breakfast_status'] ?? ''}'),
            _mealRow('Lunch', '${_fields['lunch_status'] ?? ''}'),
            _mealRow('Snack', '${_fields['snack_status'] ?? ''}'),
            const SizedBox(height: 8),
            if (_fields['nap_minutes'] != null && '${_fields['nap_minutes']}' != 'null') _row('Nap', '${_fields['nap_minutes']} min'),
            if (_int(_fields['diaper_count']) > 0)
              _row('Diapers', '${_int(_fields['diaper_count'])} (${_int(_fields['diaper_wet_count'])} wet · ${_int(_fields['diaper_soiled_count'])} soiled)'),
            if (_fields['activities'] is List && (_fields['activities'] as List).isNotEmpty)
              _row('Activities', (_fields['activities'] as List).join(', ')),
          ],
    ];
  }

  static const _moodLooks = {
    'happy': ('😊', 'Happy', Color(0xFF15803D), Color(0xFFDCFCE7)),
    'calm': ('😌', 'Calm', Color(0xFF1D4ED8), Color(0xFFDBEAFE)),
    'fussy': ('😣', 'Fussy', Color(0xFFBE123C), Color(0xFFFFE4E6)),
    'tired': ('😴', 'Tired', Color(0xFFB45309), Color(0xFFFEF3C7)),
    'okay': ('🙂', 'Okay', Color(0xFF1D4ED8), Color(0xFFDBEAFE)),
    'sad': ('😢', 'Sad', Color(0xFFBE123C), Color(0xFFFFE4E6)),
    'unwell': ('🤒', 'Unwell', Color(0xFFBE123C), Color(0xFFFFE4E6)),
  };

  List<ReportPhoto> get _photos => [
        for (final p in SchoolScope.of(context).dailyReportPhotos(_fields)) ReportPhoto(id: p.id, url: p.url),
      ];

  int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  Widget _moodBlock() {
    final key = '${_fields['mood'] ?? ''}'.toLowerCase();
    final look = _moodLooks[key];
    final bg = look?.$4 ?? const Color(0xFFF1F5F9);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S MOOD", style: AppText.label()),
          const SizedBox(height: 6),
          Text(look?.$1 ?? '🙂', style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 2),
          Text(
            look?.$2 ?? (key.isEmpty ? 'Not recorded' : key),
            style: AppText.display(size: 20, weight: FontWeight.w700, color: look?.$3 ?? AppColors.slate600),
          ),
        ],
      ),
    );
  }

  String _ago(String raw) {
    final t = DateTime.tryParse(raw)?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'sent just now';
    if (d.inMinutes < 60) return 'sent ${d.inMinutes}m ago';
    if (d.inHours < 24) return 'sent ${d.inHours}h ago';
    return 'sent ${d.inDays}d ago';
  }

  Widget _noteBlock() {
    final teacher = _fields['teacher'] is Map ? '${(_fields['teacher'] as Map)['full_name'] ?? ''}'.trim() : '';
    final name = teacher.isEmpty ? 'Class teacher' : teacher;
    final initials = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final when = _ago('${_fields['sent_at'] ?? _fields['updated_at'] ?? ''}');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.rose,
            child: Text(initials, style: AppText.body(size: 11, weight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: name.toUpperCase(), style: AppText.body(size: 11, weight: FontWeight.w800)),
                    if (when.isNotEmpty) TextSpan(text: '  $when', style: AppText.body(size: 11, color: AppColors.slate400)),
                  ]),
                ),
                const SizedBox(height: 3),
                Text('${_fields['note']}'.trim(), style: AppText.body(size: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealRow(String label, String value) {
    final text = _mealLevelLabels[value] ?? '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.restaurant_rounded, size: 15, color: AppColors.honeyDark),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppText.body(size: 13, weight: FontWeight.w700))),
          Text(text, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.honeyDark)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 84, child: Text(label, style: AppText.body(size: 12, color: AppColors.slate500))),
            Expanded(child: Text(value, style: AppText.body(size: 13, weight: FontWeight.w600))),
          ],
        ),
      );
}
