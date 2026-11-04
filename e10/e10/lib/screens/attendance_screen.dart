import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/core/config/api_config.dart';
import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart' show showAppConfirm;
import 'admin_forms.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    this.onBack,
    required this.onLogout,
    required this.role,
    this.user,
    this.onOpenStaff,
  });

  final VoidCallback? onBack;

  /// Admins: opens teachers' attendance by department.
  final VoidCallback? onOpenStaff;
  final VoidCallback onLogout;
  final Role role;
  final AppUser? user;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // ============================================================
  // API
  // ============================================================

  bool _apiLoading = false;
  bool _apiFailed = false;
  String? _apiError;

  Map<String, String> _marks = {};

  /// Today's API row per student (palm scan or hand-marked).
  final Map<String, Map<String, dynamic>> _todayRows = {};
  bool _submitted = false;
  String _klass = '';
  String _mode = 'boarders';
  bool _ready = false;
  bool _classChosen = false;

  Uri _api(String path) {
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    return ApiConfig.endpoint(cleanPath);
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('auth_token') ??
        prefs.getString('access_token') ??
        prefs.getString('token');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _token();

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // ============================================================
  // LOAD ATTENDANCE FROM API
  // ============================================================

  Future<void> _loadLiveAttendance() async {
    if (!mounted) return;

    setState(() {
      _apiLoading = true;
      _apiFailed = false;
      _apiError = null;
    });

    try {
      if (widget.role == Role.parent) {
        if (mounted) {
          setState(() {
            _apiLoading = false;
            _apiFailed = false;
            _apiError = null;
          });
        }
        return;
      }
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final store = SchoolScope.of(context);
      final classId = _boardersOnly ? '' : (store.classes.where((c) => c.name == _klass).firstOrNull?.id ?? '');
      // Today only (without a date the API returns the whole history and old
      // days' statuses overwrote today's roll), and the chosen class only —
      // the same query the website's attendance page sends.
      final query = {
        'date': today,
        'person_type': 'student',
        if (classId.isNotEmpty) 'class_id': classId,
        'per_page': '100',
      };
      final firstPage = _api('attendance').replace(queryParameters: query);
      final headers = await _headers();
      var response = await http
          .get(firstPage, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rows = <dynamic>[];
        if (decoded is List) {
          rows.addAll(decoded);
        } else if (decoded is Map<String, dynamic>) {
          final first = decoded['attendance'] ?? decoded['data'] ?? decoded['rows'] ?? decoded['records'];
          if (first is List) rows.addAll(first);
          // The server caps a page, so a school with more scans than one
          // page used to show only the first page's students in the counts.
          final meta = decoded['meta'];
          final lastPage = meta is Map ? int.tryParse('${meta['last_page'] ?? 1}') ?? 1 : 1;
          for (var page = 2; page <= lastPage && page <= 50; page++) {
            response = await http
                .get(_api('attendance').replace(queryParameters: {...query, 'page': '$page'}), headers: headers)
                .timeout(const Duration(seconds: 20));
            if (response.statusCode != 200) break;
            final more = jsonDecode(response.body);
            final list = more is Map ? (more['data'] ?? more['attendance']) : more;
            if (list is List) rows.addAll(list);
          }
        }
        if (!mounted) return;
        _applyApiRows(rows);

        if (!mounted) return;

        setState(() {
          _apiLoading = false;
          _apiFailed = false;
        });

        return;
      }

      if (response.statusCode == 401) {
        throw Exception('Your session has expired. Please log in again.');
      }

      if (response.statusCode == 403) {
        throw Exception(
          'You do not have permission to view attendance.',
        );
      }

      throw Exception(
        'Attendance API returned ${response.statusCode}.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _apiLoading = false;
        _apiFailed = true;
        _apiError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applyApiRows(List rows) {
    final store = SchoolScope.of(context);

    final apiMarks = <String, String>{};
    final apiRows = <Map<String, dynamic>>[];
    // Only this roster's students: today's rows for other classes used to be
    // added to the counts too, so they never matched the website.
    final rosterIds = {for (final s in _roster(store)) s.id};
    _todayRows.clear();

    for (final item in rows) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      apiRows.add(row);

      final studentId =
          row['student_id']?.toString() ??
          row['studentId']?.toString() ??
          (row['student'] is Map ? row['student']['id']?.toString() : null);

      if (studentId == null || studentId.isEmpty || !rosterIds.contains(studentId)) {
        continue;
      }

      final status =
          item['status']?.toString().toLowerCase() ??
          'present';

      apiMarks[studentId] = _normStatus(status);
      _todayRows[studentId] = row;
    }

    if (apiRows.isNotEmpty) {
      store.mergeAttendanceRows(apiRows);
    }

    if (!mounted) return;

    setState(() {
      if (_canSubmit) {
        // Keep the teacher's unsaved boarder marks; the server wins for
        // anyone it already has a row for.
        _marks.addAll(apiMarks);
      } else {
        // Viewers see exactly what the server has for today — no defaults.
        _marks = apiMarks;
      }
    });

    // Keep SchoolStore in sync when possible.
    for (final entry in apiMarks.entries) {
      if (store.students.any((s) => s.id == entry.key)) {
        // SchoolStore remains the fallback/source for screens that
        // already consume rollOf().
      }
    }
  }

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_ready) return;

    final store = SchoolScope.of(context);

    _klass = store.classNames.firstOrNull ?? '';

    _load(store);

    _ready = true;

    _loadLiveAttendance();
  }

  void _load(SchoolStore store) {
    final kids = _roster(store);

    if (_canSubmit) {
      _marks = {
        for (final student in kids)
          if (!_palmMarked(student))
            student.id: _normStatus(
              store.rollOf(student.id),
            )
          else if (_todayRows[student.id] != null)
            student.id: _normStatus('${_todayRows[student.id]!['status'] ?? 'present'}'),
      };

      _submitted = false;
    } else {
      _marks = {
        for (final student in kids)
          if (store.rollMarks.containsKey(student.id))
            student.id: _normStatus(
              store.rollMarks[student.id]!,
            ),
      };
    }
  }

  String _normStatus(String value) {
    final status = value.toLowerCase();

    if (status == 'late') return 'late';

    if (status == 'excused' ||
        status == 'authorized_absence' ||
        status == 'excuse') {
      return 'excused';
    }

    if (status == 'absent') return 'absent';

    if (status == 'early_departure' || status == 'left_early') return 'left_early';

    return 'present';
  }

  /// Day students are marked by the palm scanner at the gate; only boarders
  /// are marked by hand (the scanner ignores boarders' scans).
  bool _palmMarked(Student student) => !_boardersOnly && !student.boarder;

  bool get _boardersOnly =>
      widget.role == Role.teacher &&
      _mode == 'boarders';

  List<Student> _roster(SchoolStore store) {
    if (_boardersOnly) {
      return store.students
          .where((s) => s.boarder)
          .toList();
    }

    final klass = store.classes
        .where((c) => c.name == _klass)
        .firstOrNull;

    return store.students.where((s) {
      return s.klass == _klass ||
          (klass != null && s.classId == klass.id);
    }).toList();
  }

  /// Counted the way the website's summary counts: one bucket per status,
  /// for this roster's students only.
  int _count(String key) {
    final ids = {for (final s in _roster(SchoolScope.of(context))) s.id};
    return _marks.entries
        .where((e) => ids.contains(e.key) && e.value == key)
        .length;
  }

  bool get _canSubmit =>
      widget.role.canSubmitAttendance;

  // ============================================================
  // MARK NOT-SCANNED DAY STUDENTS ABSENT (admin)
  // ============================================================

  bool _markingAbsent = false;

  /// Admins (who may mark attendance by hand, as on the website): day
  /// students with no record today — they never scanned at the gate — are
  /// submitted as Absent ("No palm scan") so the day tallies everywhere.
  /// Boarders are left to the class teacher's boarding register.
  bool get _canMarkAbsent =>
      widget.role.isAdminPortal && (widget.user?.permissions.contains('attendance.mark') ?? false);

  Future<void> _markStudentsAbsent({String classId = '', String className = ''}) async {
    final store = SchoolScope.of(context);
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    setState(() => _markingAbsent = true);
    final missing = await store.dayStudentsNotScanned(today, classId: classId);
    if (!mounted) return;
    setState(() => _markingAbsent = false);
    if (missing == null) {
      showSnack(context, 'Could not read today’s attendance. Check the connection and try again.');
      return;
    }
    if (missing.isEmpty) {
      showSnack(context, 'Every day student${className.isEmpty ? '' : ' in $className'} has a record today.');
      return;
    }
    final names = missing.map((s) => s.name).take(6).join(', ');
    final ok = await showAppConfirm(
      context: context,
      title: 'Mark ${missing.length} day student${missing.length == 1 ? '' : 's'} absent?',
      message: '$names${missing.length > 6 ? ' and ${missing.length - 6} more' : ''} did not scan in today'
          '${className.isEmpty ? '' : ' ($className)'}. They will be saved as Absent with the note “No palm scan”, '
          'and it shows on the website and to parents. Do this at the end of the school day. Boarders are not included.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Mark absent',
    );
    if (!ok || !mounted) return;
    setState(() => _markingAbsent = true);
    final result = await store.markNotScannedAbsent([for (final s in missing) ('student', s.id)], today);
    if (!mounted) return;
    setState(() => _markingAbsent = false);
    showSnack(
      context,
      result.failed == 0
          ? '${result.marked} student${result.marked == 1 ? '' : 's'} marked absent'
          : '${result.marked} marked absent, ${result.failed} not saved. ${result.error}',
    );
    await _loadLiveAttendance();
  }

  Widget _markAbsentButton({String classId = '', String className = ''}) => OutlinedButton.icon(
        onPressed: _markingAbsent ? null : () => _markStudentsAbsent(classId: classId, className: className),
        icon: _markingAbsent
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.person_off_outlined, size: 18),
        label: Text(className.isEmpty
            ? 'Mark day students not scanned today as absent'
            : 'Mark not-scanned day students absent'),
      );

  // ============================================================
  // CLASS PICKER
  // ============================================================

  Widget _classPicker(BuildContext context) {
    final store = SchoolScope.of(context);
    final user = widget.user;

    final rooms =
        widget.role == Role.teacher && user != null
            ? store.homeroomClassesFor(user)
            : store.classes;

    final canMark =
        widget.role == Role.teacher &&
        user != null &&
        store.isClassTeacher(user);

    return Column(
      children: [
        AdminPageHeader(
          title: 'Attendance',
          subtitle: canMark
              ? 'Select your class to take attendance for today.'
              : widget.role == Role.teacher
                  ? 'Only the class teacher marks the roll.'
                  : 'Select a class to view attendance submitted today.',
          onBack: widget.onBack,
        ),

        if (_apiLoading)
          const LinearProgressIndicator(minHeight: 2),

        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              if (_apiFailed)
                _ApiWarning(
                  message: _apiError ??
                      'Unable to load live attendance.',
                  onRetry: _loadLiveAttendance,
                ),

              if (_canMarkAbsent) ...[
                _markAbsentButton(),
                const SizedBox(height: 8),
              ],
              if (widget.onOpenStaff != null) ...[
                NavListRow(
                  title: 'Teacher attendance',
                  subtitle: 'Palm scans by department',
                  icon: Icons.badge_outlined,
                  tint: const Color(0xFFFFF7ED),
                  iconColor: AppColors.honeyDark,
                  onTap: widget.onOpenStaff!,
                ),
                const SizedBox(height: 8),
              ],
              if (widget.role == Role.teacher && !canMark)
                WhiteCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'You are not the class teacher for a homeroom. Set homework and assignments from Home like a subject teacher. The class teacher marks attendance.',
                    style: AppText.body(
                      size: 14,
                      color: AppSurface.muted(context),
                    ),
                  ),
                )
              else if (rooms.isEmpty)
                WhiteCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No classes yet.',
                    style: AppText.body(
                      size: 13,
                      color: AppColors.slate500,
                    ),
                  ),
                )
              else ...[
                for (final klass in rooms)
                  NavListRow(
                    title: klass.name,
                    icon: Icons.front_hand_outlined,
                    tint: const Color(0xFFECFDF5),
                    iconColor: AppColors.emerald,
                    onTap: () {
                      setState(() {
                        _klass = klass.name;
                        _mode = 'class';
                        _classChosen = true;
                        _load(store);
                      });

                      _loadLiveAttendance();
                    },
                  ),
                if (canMark)
                  NavListRow(
                    title: 'Boarders',
                    subtitle: 'Every boarding student, any class',
                    icon: Icons.hotel_rounded,
                    tint: const Color(0xFFEFF6FF),
                    iconColor: AppColors.icon,
                    onTap: () {
                      setState(() {
                        _klass = 'Boarders';
                        _mode = 'boarders';
                        _classChosen = true;
                        _load(store);
                      });

                      _loadLiveAttendance();
                    },
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CLASS ROLL
  // ============================================================

  Widget _classRoll(
    BuildContext context, {
    required bool canEdit,
  }) {
    final store = SchoolScope.of(context);
    final roster = _roster(store);

    const presentGreen = Color(0xFF1B5E20);

    return Column(
      children: [
        AdminPageHeader(
          title:
              canEdit ? 'Take Attendance' : 'View attendance',
          subtitle:
              canEdit ? _klass : '$_klass · submitted today',
          onBack: () {
            setState(() {
              _classChosen = false;
              _submitted = false;
            });
          },
        ),

        if (_apiLoading)
          const LinearProgressIndicator(minHeight: 2),

        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: AttendanceStatGrid(
            totalLabel: '${roster.length} on this roster',
            stats: [
              (label: 'Present', value: _count('present'), icon: Icons.check_circle_rounded, color: presentGreen),
              (label: 'Absent', value: _count('absent'), icon: Icons.cancel_rounded, color: AppColors.rose),
              (label: 'Late', value: _count('late'), icon: Icons.timer_outlined, color: AppColors.honeyDark),
              (label: 'Excused', value: _count('excused'), icon: Icons.event_busy_rounded, color: AppColors.sky),
            ],
          ),
        ),

        if (!_boardersOnly && roster.any(_palmMarked))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.back_hand_outlined, size: 16, color: AppColors.emerald),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    canEdit
                        ? 'Day students are marked by palm scan at the gate. Mark boarders below.'
                        : 'Day students are marked by palm scan; boarders by the class teacher.',
                    style: AppText.body(size: 12, color: AppColors.slate500),
                  ),
                ),
              ],
            ),
          ),

        if (!canEdit && _canMarkAbsent && !_boardersOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: _markAbsentButton(
              classId: store.classes.where((c) => c.name == _klass).firstOrNull?.id ?? '',
              className: _klass,
            ),
          ),

        if (!canEdit)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              _marks.isEmpty
                  ? 'The teacher has not submitted this class yet.'
                  : 'Read only · marked by the class teacher.',
              style: AppText.body(
                size: 13,
                color: AppColors.slate500,
              ),
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: roster.length,
            itemBuilder: (context, i) {
              final student = roster[i];

              var mark = _marks[student.id];

              if (mark == 'excused') {
                mark = 'absent';
              }

              return Container(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                decoration:
                    const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _SoftAvatar(
                      name: student.name,
                      index: i,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  student.name,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: AppText.body(
                                    size: 16,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (student.allergies.trim().isNotEmpty || student.medicalNotes.trim().isNotEmpty) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.health_and_safety_rounded, size: 15, color: AppColors.rose),
                              ],
                            ],
                          ),
                          Text(
                            'ID ${store.studentDisplayId(student)}',
                            style: AppText.body(size: 11, color: AppColors.slate400),
                          ),
                        ],
                      ),
                    ),

                    if (_palmMarked(student))
                      _PalmChip(row: _todayRows[student.id])
                    else
                    for (final option in const [
                      (
                        'present',
                        'P',
                        presentGreen,
                      ),
                      (
                        'late',
                        'L',
                        AppColors.honeyDark,
                      ),
                      (
                        'absent',
                        'A',
                        AppColors.rose,
                      ),
                    ])
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          left: 8,
                        ),
                        child: _PlaCircle(
                          letter: option.$2,
                          selected:
                              mark == option.$1,
                          color: option.$3,
                          onTap: canEdit
                              ? () {
                                  setState(() {
                                    _marks[
                                            student.id] =
                                        option.$1;
                                    _submitted = false;
                                  });
                                }
                              : null,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        if (canEdit && roster.any((s) => !_palmMarked(s)))
          Material(
            color: AppSurface.page(context),
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _submitted
                      ? null
                      : () async {
                          await _submitAttendance(
                            context,
                            store,
                            roster,
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AppColors.headerStart,
                    disabledBackgroundColor:
                        AppColors.headerMid,
                    foregroundColor: Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _submitted
                        ? 'Submitted to admin'
                        : 'Save attendance',
                    style: AppText.body(
                      size: 16,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submitAttendance(
    BuildContext context,
    SchoolStore store,
    List<Student> roster,
  ) async {
    final marks = {
      for (final student in roster)
        if (!_palmMarked(student))
        student.id: _marks[student.id] == 'excused'
            ? 'absent'
            : (_marks[student.id] ?? 'present'),
    };

    // SchoolStore.saveAttendance posts to the real `/attendance/class-register`
    // endpoint (this screen's own `_saveAttendanceToApi` posted to the bare
    // `/attendance` path, which the API only exposes for GET, so every
    // submission was silently failing before reaching this call).
    final storeOk = await store.saveAttendance(
      _klass,
      marks,
    );

    if (!context.mounted) return;

    if (!storeOk) {
      showSnack(
        context,
        store.syncError ?? 'Attendance could not be saved.',
      );
      return;
    }

    setState(() {
      _marks.addAll(marks);
      _submitted = true;
    });

    showSnack(
      context,
      'Attendance submitted successfully.',
    );
  }

  // ============================================================
  // PARENT VIEW
  // ============================================================

  Widget _parentView(BuildContext context) {
    final store = SchoolScope.of(context);

    final child = store.focusedChild(Role.parent);

    final rows = child == null
        ? const <Map<String, dynamic>>[]
        : store.attendanceRowsFor(child.id);

    var present = 0;
    var late = 0;
    var absent = 0;
    var excused = 0;
    var leftEarly = 0;

    for (final row in rows) {
      final status =
          '${row['status'] ?? ''}'.toLowerCase();

      if (status == 'late') {
        late++;
      } else if (status == 'excused' ||
          status == 'authorized_absence' ||
          status == 'excuse') {
        excused++;
      } else if (status == 'absent') {
        absent++;
      } else if (status == 'early_departure') {
        leftEarly++;
      } else {
        present++;
      }
    }

    final total =
        present + late + absent + excused + leftEarly;

    final pct = child == null
        ? 0
        : total == 0
            ? child.attendance
            : ((present + late + leftEarly) /
                    total *
                    100)
                .round();

    return Column(
      children: [
        AdminPageHeader(
          title: 'Attendance',
          onBack: widget.onBack,
        ),

        if (_apiLoading)
          const LinearProgressIndicator(
            minHeight: 2,
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadLiveAttendance,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: AppLayout.page(context),
              children: [
                if (_apiFailed)
                  _ApiWarning(
                    message: _apiError ??
                        'Unable to load live attendance.',
                    onRetry: _loadLiveAttendance,
                  ),

                if (child != null) ...[
                  Text(
                    '${child.name}${child.klass.isEmpty ? '' : ' · ${child.klass}'}',
                    textAlign: TextAlign.center,
                    style: AppText.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppSurface.text(context),
                    ),
                  ),
                  Text(
                    'Student ID: ${store.studentDisplayId(child)}',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 12, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 16),
                ],

                Center(
                  child: SizedBox(
                    width: 168,
                    height: 168,
                    child: CustomPaint(
                      painter:
                          _RingPainter(
                        pct.clamp(0, 100) / 100,
                      ),
                      child: Center(
                        child: Text(
                          '$pct%',
                          style: AppText.display(
                            size: 36,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Builder(builder: (context) {
                  // Same term-scoped figures as the parent home's grid.
                  final term = child == null ? null : store.attendanceTermSummaryFor(child.id);
                  return AttendanceStatGrid(
                    totalLabel: term == null
                        ? '$total days recorded'
                        : '${term.totalDays} days recorded · ${store.currentTermLabel}',
                    stats: [
                      (label: 'Present', value: term?.onTime ?? present, icon: Icons.check_circle_rounded, color: const Color(0xFF1B5E20)),
                      (label: 'Absent', value: term?.absent ?? absent, icon: Icons.cancel_rounded, color: AppColors.rose),
                      (label: 'Late', value: term?.late ?? late, icon: Icons.timer_outlined, color: AppColors.honeyDark),
                      (label: 'Excused', value: term?.excused ?? excused, icon: Icons.event_busy_rounded, color: AppColors.sky),
                    ],
                  );
                }),

                const SizedBox(height: 22),

                Text(
                  'Recent days',
                  style: AppText.display(
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                if (rows.isEmpty)
                  WhiteCard(
                    padding:
                        const EdgeInsets.all(14),
                    child: Text(
                      child == null
                          ? 'No linked child yet.'
                          : 'No attendance days recorded yet.',
                      style: AppText.body(
                        size: 13,
                        color:
                            AppColors.slate500,
                      ),
                    ),
                  )
                else
                  for (final row
                      in rows.take(14))
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 4,
                      ),
                      child: Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 12,
                        ),
                        decoration:
                            const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  AppColors.border,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dayLabel(
                                  '${row['date'] ?? ''}',
                                ),
                                style:
                                    AppText.body(
                                  size: 14,
                                  weight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),

                            Text(
                              _timeLabel(
                                '${row['check_in_at'] ?? ''}',
                              ),
                              style:
                                  AppText.body(
                                size: 13,
                                color:
                                    AppColors
                                        .slate500,
                              ),
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            StatusDot(
                              label:
                                  _statusLabel(
                                '${row['status'] ?? 'present'}',
                              ),
                              color:
                                  _statusColor(
                                '${row['status'] ?? 'present'}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _dayLabel(String raw) {
    final d = DateTime.tryParse(raw);

    if (d == null) {
      return raw.isEmpty ? '—' : raw;
    }

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  String _timeLabel(String raw) {
    final d = DateTime.tryParse(raw);

    if (d == null) return '';

    final h =
        d.hour % 12 == 0 ? 12 : d.hour % 12;

    final m =
        d.minute.toString().padLeft(2, '0');

    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _statusLabel(String status) {
    final s = status.toLowerCase();

    if (s == 'late') return 'Late';

    if (s == 'early_departure') return 'Left early';

    if (s == 'absent') return 'Absent';

    if (s == 'excused' ||
        s == 'authorized_absence' ||
        s == 'excuse') {
      return 'Excuse';
    }

    return 'Present';
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();

    if (s == 'late' || s == 'early_departure') {
      return AppColors.honeyDark;
    }

    if (s == 'absent') {
      return AppColors.rose;
    }

    if (s == 'excused' ||
        s == 'authorized_absence' ||
        s == 'excuse') {
      return AppColors.sky;
    }

    return const Color(0xFF1B5E20);
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (widget.role == Role.parent) {
      return _parentView(context);
    }

    if (widget.role == Role.teacher ||
        widget.role.isAdminPortal) {
      if (!_classChosen) {
        return _classPicker(context);
      }

      final user = widget.user;

      final canEdit =
          widget.role == Role.teacher &&
          user != null &&
          SchoolScope.of(context).canMarkAttendance(
            user,
            // "Boarders" spans every homeroom, not one real class — checking
            // it against `rooms.any((c) => c.name == 'Boarders')` would
            // never match, wrongly making the roll read-only. Any class
            // teacher may mark it, same as canMarkAttendance's own no-class
            // "am I a class teacher at all" check.
            className: _boardersOnly ? '' : _klass,
          );

      return _classRoll(
        context,
        canEdit: canEdit,
      );
    }

    final store = SchoolScope.of(context);

    final roster = _roster(store);

    final title = widget.role == Role.teacher
        ? (_klass.isEmpty
            ? 'Attendance'
            : _klass)
        : (_canSubmit
            ? 'Take Attendance'
            : 'View Attendance');

    final today = DateTime.now();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final dateStr =
        '${today.day} ${months[today.month - 1]} ${today.year}';

    final subtitle = _boardersOnly
        ? '${roster.length} boarders · $dateStr'
        : _canSubmit
            ? '$_klass · $dateStr'
            : '$_klass · read only · $dateStr';

    return Column(
      children: [
        AdminPageHeader(
          title: widget.role == Role.teacher
              ? (_klass.isEmpty
                  ? 'Attendance'
                  : _klass)
              : title,
          subtitle:
              widget.role == Role.teacher
                  ? 'Take attendance for today'
                  : subtitle,
          onBack:
              widget.role == Role.teacher
                  ? () => setState(
                        () =>
                            _classChosen =
                                false,
                      )
                  : widget.onBack,
        ),

        if (_apiLoading)
          const LinearProgressIndicator(
            minHeight: 2,
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadLiveAttendance,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: AppLayout.page(context),
              children: [
                if (_apiFailed)
                  _ApiWarning(
                    message: _apiError ??
                        'Unable to load live attendance.',
                    onRetry:
                        _loadLiveAttendance,
                  ),

                if (widget.role != Role.teacher &&
                    !_canSubmit) ...[
                  WhiteCard(
                    padding:
                        const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const AppIcon(
                          Icons.visibility_rounded,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin can review class attendance. Teachers submit the roll.',
                            style: AppText.body(
                              size: 12,
                              color:
                                  AppColors.slate500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (widget.role != Role.teacher &&
                    !_boardersOnly &&
                    store.classNames.isNotEmpty)
                  AdminDropdown(
                    label: 'Class',
                    value: _klass,
                    items: store.classNames,
                    onChanged: (value) {
                      setState(() {
                        _klass = value;
                        _load(store);
                      });

                      _loadLiveAttendance();
                    },
                  ),

                AttendanceStatGrid(
                  totalLabel: '${roster.length} on this roster',
                  stats: [
                    (label: 'Present', value: _count('present'), icon: Icons.check_circle_rounded, color: AppColors.emerald),
                    (label: 'Absent', value: _count('absent'), icon: Icons.cancel_rounded, color: AppColors.rose),
                    (label: 'Late', value: _count('late'), icon: Icons.timer_outlined, color: AppColors.honeyDark),
                    (label: 'Excused', value: _count('excused'), icon: Icons.event_busy_rounded, color: AppColors.sky),
                  ],
                ),

                const SizedBox(height: 14),

                if (_canSubmit) ...[
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _marks = {
                          for (final student
                              in roster)
                            student.id:
                                'present',
                        };
                      });
                    },
                    style:
                        OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 14,
                      ),
                      side:
                          const BorderSide(
                        color:
                            Color(0xFF6EE7B7),
                        width: 2,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(12),
                      ),
                    ),
                    child: Text(
                      'Mark All Present',
                      style: AppText.body(
                        weight:
                            FontWeight.w700,
                        color:
                            const Color(
                          0xFF047857,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: roster.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 138,
                  ),
                  itemBuilder:
                      (context, i) {
                    final student =
                        roster[i];

                    final mark =
                        _marks[student.id] ??
                            'present';

                    return WhiteCard(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        10,
                        10,
                        10,
                        8,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            student.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                AppText.body(
                              size: 12,
                              weight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          Text(
                            student.klass,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                AppText.body(
                              size: 10,
                              color:
                                  AppColors
                                      .slate400,
                            ),
                          ),

                          const Spacer(),

                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final option
                                  in const [
                                (
                                  'present',
                                  'Present',
                                ),
                                (
                                  'late',
                                  'Late',
                                ),
                                (
                                  'excused',
                                  'Excuse',
                                ),
                                (
                                  'absent',
                                  'Absent',
                                ),
                              ])
                                _MarkChip(
                                  label:
                                      option
                                          .$2,
                                  selected:
                                      mark ==
                                          option
                                              .$1,
                                  enabled:
                                      _canSubmit,
                                  onTap: () {
                                    setState(() {
                                      _marks[
                                              student
                                                  .id] =
                                          option.$1;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                if (_canSubmit)
                  if (!_submitted)
                    HoneyButton(
                      label:
                          'Submit Attendance',
                      onPressed: () async {
                        await _submitAttendance(
                          context,
                          store,
                          roster,
                        );
                      },
                    )
                  else
                    Container(
                      padding:
                          const EdgeInsets.all(
                        20,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFECFDF5,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(16),
                        border: Border.all(
                          color:
                              const Color(
                            0xFF6EE7B7,
                          ),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const AppIcon(
                            Icons.check_rounded,
                            size:
                                AppIconSize.card,
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Text(
                            'Attendance Recorded!',
                            style:
                                AppText.display(
                              size: 18,
                              color:
                                  const Color(
                                0xFF047857,
                              ),
                            ),
                          ),
                          Text(
                            'Parents have been notified automatically',
                            style:
                                AppText.body(
                              size: 14,
                              color:
                                  const Color(
                                0xFF059669,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// API WARNING
// ================================================================

class _ApiWarning extends StatelessWidget {
  const _ApiWarning({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.rose
              .withValues(alpha: 0.08),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.rose
                .withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.rose,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppText.body(
                  size: 12,
                  color: AppColors.slate600,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// ATTENDANCE RING
// ================================================================

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        size.width / 2 - 10;

    final track = Paint()
      ..color =
          const Color(0xFFE8F5E9)
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap =
          StrokeCap.round;

    final fill = Paint()
      ..color =
          const Color(0xFF1B5E20)
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap =
          StrokeCap.round;

    canvas.drawCircle(
      center,
      radius,
      track,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
      -1.5708,
      6.2832 *
          progress.clamp(0, 1),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(
    covariant _RingPainter oldDelegate,
  ) {
    return oldDelegate.progress !=
        progress;
  }
}

// ================================================================
// MARK CHIP
// ================================================================

class _MarkChip extends StatelessWidget {
  const _MarkChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? AppColors.honey
              : AppColors.slate100,
          borderRadius:
              BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: AppText.body(
            size: 9,
            weight:
                FontWeight.w700,
            color: selected
                ? Colors.white
                : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SOFT AVATAR
// ================================================================

class _SoftAvatar extends StatelessWidget {
  const _SoftAvatar({
    required this.name,
    required this.index,
  });

  final String name;
  final int index;

  static const _tints = [
    (
      Color(0xFFDBEAFE),
      Color(0xFF1D4ED8),
    ),
    (
      Color(0xFFE0F2FE),
      Color(0xFF0284C7),
    ),
    (
      Color(0xFFEFF6FF),
      Color(0xFF2563EB),
    ),
    (
      Color(0xFFBFDBFE),
      Color(0xFF1E3A8A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tone =
        _tints[index % _tints.length];

    final initials = name
        .split(' ')
        .where(
          (p) => p.isNotEmpty,
        )
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();

    return Container(
      width: 40,
      height: 40,
      alignment:
          Alignment.center,
      decoration:
          BoxDecoration(
        color: tone.$1,
        shape:
            BoxShape.circle,
      ),
      child: Text(
        initials,
        style: AppText.body(
          size: 12,
          weight:
              FontWeight.w800,
          color: tone.$2,
        ),
      ),
    );
  }
}

// ================================================================
// P / L / A CIRCLE
// ================================================================

class _PlaCircle extends StatelessWidget {
  const _PlaCircle({
    required this.letter,
    required this.selected,
    required this.color,
    this.onTap,
  });

  final String letter;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment:
            Alignment.center,
        decoration:
            BoxDecoration(
          color: selected
              ? color
              : Colors.transparent,
          shape:
              BoxShape.circle,
        ),
        child: Text(
          letter,
          style: AppText.body(
            size: 13,
            weight:
                FontWeight.w800,
            color: selected
                ? Colors.white
                : AppColors.slate400,
          ),
        ),
      ),
    );
  }
}



/// A day student's palm-scan result for today (read-only).
class _PalmChip extends StatelessWidget {
  const _PalmChip({required this.row});

  final Map<String, dynamic>? row;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final inAt = SchoolStore.clockOf(r?['check_in_at']);
    final outAt = SchoolStore.clockOf(r?['check_out_at']);
    final status = '${r?['status'] ?? ''}'.toLowerCase();
    final String label;
    final Color color;
    if (r == null) {
      label = 'Not scanned';
      color = AppColors.slate400;
    } else if (status == 'absent') {
      label = 'Absent';
      color = AppColors.rose;
    } else if (inAt.isEmpty) {
      label = status == 'late' ? 'Late' : 'Present';
      color = status == 'late' ? AppColors.honeyDark : AppColors.emerald;
    } else {
      final how = SchoolStore.isPalmRecord(r) ? 'Palm' : 'In';
      label = outAt.isEmpty ? '$how $inAt${status == 'late' ? ' · late' : ''}' : '$inAt – $outAt';
      color = status == 'late' ? AppColors.honeyDark : AppColors.emerald;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(r == null ? Icons.schedule_rounded : Icons.back_hand_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppText.body(size: 12, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
