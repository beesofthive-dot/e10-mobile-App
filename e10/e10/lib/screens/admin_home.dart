import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/home_cards.dart';
import '../widgets/money_dashboard_card.dart';
import '../widgets/motion.dart';

enum _DashPeriod { today, week, month, term }

class AdminHome extends StatefulWidget {
  const AdminHome({
    super.key,
    required this.user,
    required this.onNav,
    required this.onLogout,
  });

  final AppUser user;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback onLogout;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  _DashPeriod _period = _DashPeriod.today;

  String _comma(num n) {
    final raw = n.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write(',');
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  String _cedi(num n) {
    final v = n.abs();
    if (v >= 1000) {
      final k = v / 1000;
      final text =
          k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
      return 'GHS ${n < 0 ? '-' : ''}${text}K';
    }
    return 'GHS ${n.round()}';
  }

  String _money(num n) => 'GHS ${n.toDouble().toStringAsFixed(2)}';

  String _whenLabel(DateTime? when, DateTime now) {
    if (when == null) return '';
    final day = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${when.day}/${when.month}/${when.year}';
  }

  DateTime? _parseDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t) ?? DateTime.tryParse(t.replaceAll('/', '-'));
  }

  bool _inPeriod(DateTime? when, DateTime now) {
    if (when == null) return _period == _DashPeriod.term;
    final start = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _DashPeriod.today => start == today,
      _DashPeriod.week =>
        !start.isBefore(today.subtract(const Duration(days: 6))),
      _DashPeriod.month =>
        start.year == today.year && start.month == today.month,
      _DashPeriod.term => true,
    };
  }

  /// Two tiles per row with even spacing.
  Widget _tileGrid(List<Widget> tiles) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        padding: EdgeInsets.zero,
        children: tiles,
      );

  String get _periodHint => switch (_period) {
        _DashPeriod.today => 'Today',
        _DashPeriod.week => 'This week',
        _DashPeriod.month => 'This month',
        _DashPeriod.term => 'This term',
      };

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final now = DateTime.now();
    final focusId = store.focusedClassId;
    final focusClass = store.classes.where((c) => c.id == focusId).firstOrNull;
    final students = [
      for (final s in store.students)
        if (focusClass == null ||
            s.classId == focusClass.id ||
            s.klass == focusClass.name)
          s,
    ];
    // The whole school's figures come straight from the server's summary, so
    // they are right before the full lists have finished downloading.
    final summary = focusClass == null ? store.dashboardSummary : null;
    final total = summary?.students ?? students.length;
    final present = summary?.studentsIn ?? students.where((s) {
      final st = store.rollOf(s.id).toLowerCase();
      return st == 'present' || st == 'late';
    }).length;
    final absent = summary?.studentsAway ?? students.where((s) {
      final st = store.rollOf(s.id).toLowerCase();
      return st == 'absent' || st == 'excused' || st == 'authorized_absence';
    }).length;
    final presentPct = total == 0 ? 0.0 : present * 100 / total;
    final absentPct = total == 0 ? 0.0 : absent * 100 / total;
    final staffSummary = store.dashboardSummary;
    final teachers = staffSummary?.clockingStaff ?? store.teachers.length;
    // Real clock-ins only: the server's count, else today's staff records —
    // never "everyone on the roll" as it used to show without a summary.
    final teacherPresent = staffSummary?.staffIn ??
        store.staffAttendanceToday().where((r) => SchoolStore.clockOf(r['check_in_at']).isNotEmpty).length;
    final collected =
        store.feesCollected(matches: (when) => _inPeriod(when, now));
    final outstanding = store.feesOutstanding();
    final payCount =
        store.feesPaymentCount(matches: (when) => _inPeriod(when, now));
    final unpaidBills = store.unpaidBillCount();
    final recentPays = store.recentFeePayments();
    final classCount = store.dashboardSummary?.classes ?? store.classes.length;
    var admissions = 0;
    for (final row
        in store.tables['students'] ?? const <Map<String, dynamic>>[]) {
      final when =
          _parseDate('${row['admission_date'] ?? row['created_at'] ?? ''}');
      if (_inPeriod(when, now)) admissions++;
    }
    final year = store.currentYearLabel;
    final term = store.currentTermLabel;
    final schoolBits = [
      store.brandedSchoolName,
      if (term.isNotEmpty) term,
      if (year.isNotEmpty) year,
    ];

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          DashAccountHeader(
            user: widget.user,
            subtitle: schoolBits.join(' · '),
            onLogout: widget.onLogout,
            onTapSchool: () => widget.onNav(AppScreen.schoolProfile),
          ),
          const SyncBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => store.syncFromApi(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: dashboardChildren(context, [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in const [
                          (_DashPeriod.today, 'Today'),
                          (_DashPeriod.week, 'This Week'),
                          (_DashPeriod.month, 'This Month'),
                          (_DashPeriod.term, 'This Term'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _period = item.$1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _period == item.$1
                                      ? (AppSurface.dark(context)
                                          ? AppSurface.card(context)
                                          : AppSurface.brand(context))
                                      : AppSurface.card(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _period == item.$1
                                        ? (AppSurface.dark(context)
                                            ? AppSurface.text(context)
                                            : Colors.transparent)
                                        : AppSurface.line(context),
                                  ),
                                ),
                                child: Text(
                                  item.$2,
                                  style: AppText.body(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: _period == item.$1
                                        ? (AppSurface.dark(context)
                                            ? AppSurface.text(context)
                                            : Colors.white)
                                        : AppSurface.muted(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHead(title: 'Students'),
                  _tileGrid([
                      DashCard(
                        icon: Icons.groups_rounded,
                        tint: const Color(0xFFDBEAFE),
                        iconColor: AppColors.blue,
                        label: 'Total students',
                        value: _comma(total),
                        hint: focusClass == null ? 'Enrolled · all classes' : 'Enrolled · ${focusClass.name}',
                        hintColor: AppColors.blue,
                        onTap: () => widget.onNav(AppScreen.adminStudents),
                      ),
                      if (PlanAccess.allows(AppScreen.attendance))
                      DashCard(
                        icon: Icons.check_circle_rounded,
                        tint: const Color(0xFFD1FAE5),
                        iconColor: AppColors.emerald,
                        label: 'Students present',
                        value: _comma(present),
                        hint: 'Today · ${presentPct.toStringAsFixed(0)}% of ${_comma(total)}',
                        hintColor: AppColors.emerald,
                        onTap: () => widget.onNav(AppScreen.attendance),
                      ),
                      if (PlanAccess.allows(AppScreen.attendance))
                      DashCard(
                        icon: Icons.notifications_active_rounded,
                        tint: const Color(0xFFFFE4E6),
                        iconColor: AppColors.rose,
                        label: 'Students absent',
                        value: _comma(absent),
                        hint: 'Today · ${absentPct.toStringAsFixed(0)}% of ${_comma(total)}',
                        hintColor: AppColors.rose,
                        onTap: () => widget.onNav(AppScreen.attendance),
                      ),
                      DashCard(
                        icon: Icons.bar_chart_rounded,
                        tint: const Color(0xFFECFDF5),
                        iconColor: AppColors.emerald,
                        label: 'Analytics',
                        value: '${presentPct.toStringAsFixed(0)}%',
                        hint: 'Student attendance rate',
                        hintColor: AppColors.emerald,
                        onTap: () => widget.onNav(AppScreen.analytics),
                      ),
                  ]),
                  const SizedBox(height: 22),
                  const SectionHead(title: 'Staff'),
                  _tileGrid([
                      DashCard(
                        icon: Icons.badge_rounded,
                        tint: const Color(0xFFFFEDD5),
                        iconColor: AppColors.orange,
                        label: 'Total staff',
                        value: _comma(teachers),
                        hintColor: AppColors.orange,
                        onTap: () => widget.onNav(PlanAccess.allows(AppScreen.staffAnalytics) ? AppScreen.staffAnalytics : AppScreen.adminTeachers),
                      ),
                      DashCard(
                        icon: Icons.how_to_reg_rounded,
                        tint: const Color(0xFFD1FAE5),
                        iconColor: AppColors.emerald,
                        label: 'Staff present',
                        value: _comma(teacherPresent),
                        hint: teachers == 0 ? 'No staff who clock in' : 'Today · of ${_comma(teachers)} staff',
                        hintColor: AppColors.emerald,
                        onTap: () => widget.onNav(PlanAccess.allows(AppScreen.staffAttendance) ? AppScreen.staffAttendance : AppScreen.adminTeachers),
                      ),
                  ]),
                  const SizedBox(height: 22),
                  const SectionHead(title: 'School & money'),
                  _tileGrid([
                      if (PlanAccess.allows(AppScreen.adminFinance))
                      DashCard(
                        icon: Icons.payments_rounded,
                        tint: const Color(0xFFDBEAFE),
                        iconColor: AppColors.violet,
                        label: 'Fees collected',
                        value: _cedi(collected),
                        hint: '$payCount payments · $_periodHint',
                        hintColor: AppColors.honeyDark,
                        onTap: () => widget.onNav(AppScreen.adminFinance),
                      ),
                      DashCard(
                        icon: Icons.person_add_alt_1_rounded,
                        tint: const Color(0xFFDBEAFE),
                        iconColor: AppColors.blue,
                        label: 'New admissions',
                        value: _comma(admissions),
                        hint: _periodHint,
                        hintColor: AppColors.blue,
                        onTap: () => widget.onNav(AppScreen.adminStudents),
                      ),
                      DashCard(
                        icon: Icons.class_rounded,
                        tint: const Color(0xFFDBEAFE),
                        iconColor: AppColors.orange,
                        label: 'Classes',
                        value: _comma(classCount),
                        hint: 'Class details',
                        hintColor: AppColors.orange,
                        onTap: () => widget.onNav(AppScreen.adminClasses),
                      ),
                      DashCard(
                        icon: Icons.badge_rounded,
                        tint: const Color(0xFFE0F2FE),
                        iconColor: AppColors.blue,
                        label: 'Staff',
                        value: _comma(store.tableRows('staff').length),
                        hint: 'Staff details',
                        hintColor: AppColors.blue,
                        onTap: () => widget.onNav(AppScreen.adminStaff),
                      ),
                  ]),
                  const SizedBox(height: 22),
                  if (PlanAccess.allows(AppScreen.staffAttendance)) ...[
                    const ScannerAlertCard(),
                    const SizedBox(height: 16),
                    StaffClockInsCard(
                      rows: store.staffAttendanceToday(),
                      nameOf: store.staffNameOf,
                      staffTotal: teachers,
                      onOpen: () => widget.onNav(AppScreen.staffAttendance),
                    ),
                  ],
                  if (PlanAccess.allows(AppScreen.adminFinance)) ...[
                  const SizedBox(height: 16),
                  MoneyDashboardCard(user: widget.user, onNav: widget.onNav),
                  const SizedBox(height: 16),
                  FinanceDashboardCard(
                    collected: _money(collected),
                    outstanding: _money(outstanding),
                    hint:
                        '$payCount landed $_periodHint · $unpaidBills still open',
                    recent: [
                      for (final row in recentPays)
                        FinanceDashRow(
                          name: store.paymentStudentName(row).isEmpty
                              ? 'Fee payment'
                              : store.paymentStudentName(row),
                          amount: _money(store.paymentAmount(row)),
                          meta: [
                            store.paymentMethodLabel(row),
                            _whenLabel(store.paymentWhen(row), now),
                          ].where((e) => e.isNotEmpty).join(' · '),
                        ),
                    ],
                    onOpen: () => widget.onNav(AppScreen.adminFinance),
                  ),
                  ],
                  if (PlanAccess.allows(AppScreen.attendance)) ...[
                  const SizedBox(height: 16),
                  AttendanceAlertsCard(
                    items: store.attendanceNoticesToday(Role.admin),
                    onOpen: () => widget.onNav(AppScreen.attendance),
                  ),
                  ],
                  if (PlanAccess.allows(AppScreen.adminReports)) ...[
                  const SizedBox(height: 16),
                  ExamsReportsHomeCard(
                    onOpenExams: () => widget.onNav(AppScreen.teacherExams),
                    onOpenReports: () => widget.onNav(AppScreen.adminReports),
                  ),
                  ],
                  const SizedBox(height: 22),
                  Text('Jump in',
                      style:
                          AppText.display(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  WhiteCard(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
                    child: Row(
                      children: [
                        SquareQuickAction(
                            color: AppColors.iconPalette[0],
                            icon: Icons.add_rounded,
                            label: 'Add student',
                            onTap: () => widget.onNav(AppScreen.adminStudents)),
                        if (PlanAccess.allows(AppScreen.adminTimetable))
                        SquareQuickAction(
                            color: AppColors.iconPalette[1],
                            icon: Icons.calendar_month_rounded,
                            label: 'Timetable',
                            onTap: () =>
                                widget.onNav(AppScreen.adminTimetable)),
                        if (PlanAccess.allows(AppScreen.attendance))
                        SquareQuickAction(
                            color: AppColors.iconPalette[2],
                            icon: Icons.event_available_rounded,
                            label: 'Attendance',
                            onTap: () => widget.onNav(AppScreen.attendance)),
                        if (PlanAccess.allows(AppScreen.adminFinance))
                        SquareQuickAction(
                            color: AppColors.iconPalette[3],
                            icon: Icons.receipt_long_rounded,
                            label: 'Transactions',
                            onTap: () => widget.onNav(AppScreen.adminFinance)),
                        SquareQuickAction(
                            color: AppColors.iconPalette[4],
                            icon: Icons.family_restroom_rounded,
                            label: 'Parents',
                            onTap: () => widget.onNav(AppScreen.adminParents)),
                      ],
                    ),
                  ),
                  if (PlanAccess.allows(AppScreen.adminDepartments)) ...[
                    const SizedBox(height: 12),
                    NavListRow(
                      title: 'Departments',
                      subtitle: 'Set who heads each department',
                      icon: Icons.apartment_rounded,
                      onTap: () => widget.onNav(AppScreen.adminDepartments),
                    ),
                  ],
                  if (PlanAccess.allows(AppScreen.teacherAnnouncements)) ...[
                  const SizedBox(height: 22),
                  LatestAnnouncementsCard(
                      onOpen: () =>
                          widget.onNav(AppScreen.teacherAnnouncements)),
                  ],
                  if (PlanAccess.allows(AppScreen.messages)) ...[
                  const SizedBox(height: 22),
                  SectionHead(
                    title: 'Open chats',
                    action: 'Messages',
                    onAction: () => widget.onNav(AppScreen.messages),
                  ),
                  for (final message
                      in store.messagesFor(widget.user.role).take(3))
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  message.preview.isEmpty
                                      ? message.from
                                      : message.preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text(message.unread ? 'Unread' : 'Read',
                              style: AppText.body(
                                  size: 11, color: AppSurface.ink(context))),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin home: who has clocked in today by palm scan (or been marked by the
/// office), live from the 30-second refresh — a short summary, then the
/// latest scans, then a link to the full staff attendance page.
class StaffClockInsCard extends StatelessWidget {
  const StaffClockInsCard({
    super.key,
    required this.rows,
    required this.nameOf,
    required this.staffTotal,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) nameOf;
  final int staffTotal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final inRows = rows.where((r) => SchoolStore.clockOf(r['check_in_at']).isNotEmpty).toList();
    final late = inRows.where((r) => '${r['status']}'.toLowerCase() == 'late').length;
    final out = rows.where((r) => SchoolStore.clockOf(r['check_out_at']).isNotEmpty).length;
    final notYet = (staffTotal - inRows.length).clamp(0, staffTotal);
    final latest = rows.take(5).toList();
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.back_hand_rounded, size: 18, color: AppColors.emerald),
              const SizedBox(width: 8),
              Expanded(child: Text('Staff clock-ins today', style: AppText.body(size: 15, weight: FontWeight.w800))),
              TextButton(onPressed: onOpen, child: const Text('See all')),
            ],
          ),
          Text(
            inRows.isEmpty
                ? 'No one has scanned in yet. Clock-ins appear here within a minute of a palm scan.'
                : '${inRows.length} of $staffTotal staff in · $late late · $out clocked out · $notYet not in yet',
            style: AppText.body(size: 12, color: AppSurface.muted(context)),
          ),
          const SizedBox(height: 8),
          for (final r in latest)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppSurface.line(context)))),
              child: Row(
                children: [
                  InitialsAvatar(name: nameOf(r), tone: Tone.emerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nameOf(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, weight: FontWeight.w700)),
                        Text(SchoolStore.isPalmRecord(r) ? 'Palm scan' : 'Marked by the office',
                            style: AppText.body(size: 11, color: AppColors.slate500)),
                      ],
                    ),
                  ),
                  _ClockChip(row: r),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final inAt = SchoolStore.clockOf(row['check_in_at']);
    final outAt = SchoolStore.clockOf(row['check_out_at']);
    final status = '${row['status']}'.toLowerCase();
    final (String label, Color color) = status == 'absent'
        ? ('Absent', AppColors.rose)
        : outAt.isNotEmpty
            ? ('Out · $outAt', AppColors.slate500)
            : status == 'late'
                ? ('Late · $inAt', AppColors.honeyDark)
                : (inAt.isEmpty ? 'Marked' : 'In · $inAt', AppColors.emerald);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: color)),
    );
  }
}

/// The website's palm-scanner warning: a scanner that has gone offline, or
/// whose clock is wrong (its scans are then not recorded, so staff look
/// absent). Checks `/palm-scanner-devices` every minute; shows nothing when
/// all scanners are fine or the list can't be read.
class ScannerAlertCard extends StatefulWidget {
  const ScannerAlertCard({super.key});

  @override
  State<ScannerAlertCard> createState() => _ScannerAlertCardState();
}

class _ScannerAlertCardState extends State<ScannerAlertCard> {
  List<Map<String, dynamic>> _devices = const [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final body = await ApiClient.instance.get('palm-scanner-devices');
      final data = body is Map ? body['data'] : body;
      if (!mounted || data is! List) return;
      setState(() => _devices = [for (final d in data) if (d is Map) Map<String, dynamic>.from(d)]);
    } catch (_) {
      // No access or no scanners: nothing to warn about.
    }
  }

  static String _name(Map<String, dynamic> d) {
    final location = '${d['location'] ?? ''}'.trim();
    return location.isNotEmpty ? '$location scanner' : 'Scanner ${d['device_code'] ?? ''}'.trim();
  }

  static String _when(dynamic raw) {
    final t = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (t == null) return 'a while';
    final now = DateTime.now();
    final time = SchoolStore.clockOf(raw);
    if (t.year == now.year && t.month == now.month && t.day == now.day) return time;
    return '${t.day}/${t.month}/${t.year} $time';
  }

  @override
  Widget build(BuildContext context) {
    final offline = _devices.where((d) => '${d['status']}' == 'offline').toList();
    final badClock = _devices.where((d) => '${d['clock_problem_scan_at'] ?? ''}'.isNotEmpty).toList();
    if (offline.isEmpty && badClock.isEmpty) return const SizedBox.shrink();
    Widget line(String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.honeyDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: title, style: AppText.body(size: 13, weight: FontWeight.w800)),
                  TextSpan(text: text, style: AppText.body(size: 13)),
                ])),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        decoration: BoxDecoration(
          color: AppColors.honey.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.honey.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            for (final d in offline)
              line('${_name(d)} is offline',
                  ': nothing received since ${_when(d['last_heard_at'])}. Scans made now are saved on the device and will arrive when it reconnects.'),
            for (final d in badClock)
              line('${_name(d)}’s clock looks wrong',
                  ' (it says ${_when(d['clock_problem_scan_at'])}). Its scans aren’t being recorded. Correct the scanner’s date and time.'),
          ],
        ),
      ),
    );
  }
}
