import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import 'staff_attendance_screen.dart' show loadClockingStaff;

/// Admin analytics for staff who clock in: today's figures, the last seven
/// school days (Mon–Fri) day by day, each department today, and each staff
/// member's record over those days. Built only from real attendance rows
/// (`/attendance?person_type=staff`, one day at a time so the server isn't
/// rate-limited); a day with no record for someone counts as absent.
class StaffAnalyticsScreen extends StatefulWidget {
  const StaffAnalyticsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<StaffAnalyticsScreen> createState() => _StaffAnalyticsScreenState();
}

class _Day {
  _Day(this.date, this.key);
  final DateTime date;
  final String key;
  Map<String, Map<String, dynamic>>? rows;
}

class _StaffAnalyticsScreenState extends State<StaffAnalyticsScreen> {
  bool _loading = false;
  String? _error;
  List<NamedRecord>? _staff;
  List<_Day> _days = const [];

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// The last seven school days (Mon–Fri), oldest first, ending today.
  List<_Day> _schoolDays() {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    final out = <_Day>[];
    while (out.length < 7) {
      if (d.weekday <= DateTime.friday) out.add(_Day(d, _key(d)));
      d = d.subtract(const Duration(days: 1));
    }
    return out.reversed.toList();
  }

  Future<void> _load() async {
    if (_loading) return;
    final store = SchoolScope.of(context);
    final days = _schoolDays();
    setState(() {
      _loading = true;
      _error = null;
      _days = days;
    });
    final staff = await loadClockingStaff();
    var failed = 0;
    for (final day in days) {
      final rows = await store.staffAttendanceFor(day.key);
      if (rows == null) {
        failed++;
        continue;
      }
      day.rows = {
        for (final row in rows)
          '${row['staff_id'] ?? (row['staff'] is Map ? (row['staff'] as Map)['id'] : '')}': row,
      };
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _staff = staff ?? store.teachers;
      if (failed > 0) _error = 'Could not load $failed of ${days.length} days. Pull down to try again.';
    });
  }

  /// in / late / absent / excused / none (no record).
  static String _state(Map<String, dynamic>? row) {
    if (row == null) return 'none';
    final status = '${row['status'] ?? ''}'.toLowerCase();
    if (status == 'absent') return 'absent';
    if (status == 'authorized_absence' || status == 'excused') return 'excused';
    if (status == 'late') return 'late';
    return 'in';
  }

  static bool _present(String state) => state == 'in' || state == 'late';

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final people = _staff ?? store.teachers;
    final loaded = [for (final d in _days) if (d.rows != null) d];
    final today = _days.isNotEmpty && _days.last.key == _key(DateTime.now()) ? _days.last : null;
    final todayRows = today?.rows ?? const <String, Map<String, dynamic>>{};

    var presentToday = 0, lateToday = 0, absentToday = 0;
    for (final t in people) {
      final s = _state(todayRows[t.id]);
      if (_present(s)) presentToday++;
      if (s == 'late') lateToday++;
      if (!_present(s)) absentToday++;
    }

    // Per day: how many were present.
    final perDay = [
      for (final d in loaded)
        (d, people.where((t) => _present(_state(d.rows![t.id]))).length),
    ];
    final possible = people.length * loaded.length;
    final attendedAll = perDay.fold<int>(0, (s, e) => s + e.$2);
    final avgPct = possible == 0 ? 0.0 : attendedAll * 100 / possible;
    var lateAll = 0;
    for (final d in loaded) {
      for (final t in people) {
        if (_state(d.rows![t.id]) == 'late') lateAll++;
      }
    }

    // Per staff member over the loaded days.
    final perStaff = [
      for (final t in people)
        () {
          var present = 0, late = 0;
          for (final d in loaded) {
            final s = _state(d.rows![t.id]);
            if (_present(s)) present++;
            if (s == 'late') late++;
          }
          return (t, present, late);
        }(),
    ]..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.name.compareTo(b.$1.name));

    // Departments today.
    final depts = <String, (int, int)>{};
    for (final t in people) {
      final name = t.extra.trim().isEmpty ? 'No department' : t.extra.trim();
      final cur = depts[name] ?? (0, 0);
      depts[name] = (cur.$1 + (_present(_state(todayRows[t.id])) ? 1 : 0), cur.$2 + 1);
    }
    final deptNames = depts.keys.toList()
      ..sort((a, b) => a == 'No department' ? 1 : (b == 'No department' ? -1 : a.compareTo(b)));

    final muted = AppSurface.muted(context);

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Staff analytics',
            subtitle: 'Attendance · last ${_days.length} school days',
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
                  Text('Today', style: AppText.body(size: 14, weight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Stat(label: 'Total staff', value: '${people.length}', color: AppColors.blue),
                      const SizedBox(width: 8),
                      _Stat(label: 'Present', value: '$presentToday', color: AppColors.emerald),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Stat(label: 'Late', value: '$lateToday', color: AppColors.honeyDark),
                      const SizedBox(width: 8),
                      _Stat(label: 'Not in', value: '$absentToday', color: AppColors.rose),
                    ],
                  ),
                  const SizedBox(height: 16),
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Staff present each day', style: AppText.body(size: 14, weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          loaded.isEmpty
                              ? 'No days loaded yet.'
                              : 'Average ${avgPct.toStringAsFixed(0)}% · $lateAll late arrivals',
                          style: AppText.body(size: 12, color: muted),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 150,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final (d, n) in perDay)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text('$n', style: AppText.body(size: 11, weight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Flexible(
                                          child: FractionallySizedBox(
                                            heightFactor: people.isEmpty ? 0.02 : (n / people.length).clamp(0.02, 1.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.emerald,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(_weekday[d.date.weekday - 1], style: AppText.body(size: 11, color: muted)),
                                        Text('${d.date.day}/${d.date.month}', style: AppText.body(size: 10, color: muted)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Departments today', style: AppText.body(size: 14, weight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        if (deptNames.isEmpty)
                          Text('No staff who clock in yet.', style: AppText.body(size: 13, color: muted)),
                        for (final name in deptNames)
                          _BarLine(
                            label: name,
                            trailing: '${depts[name]!.$1} of ${depts[name]!.$2} present',
                            fraction: depts[name]!.$2 == 0 ? 0 : depts[name]!.$1 / depts[name]!.$2,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Each staff member', style: AppText.body(size: 14, weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Days present out of ${loaded.length} · lowest first', style: AppText.body(size: 12, color: muted)),
                        const SizedBox(height: 10),
                        if (perStaff.isEmpty)
                          Text('No staff who clock in yet.', style: AppText.body(size: 13, color: muted)),
                        for (final (t, present, late) in perStaff)
                          _BarLine(
                            label: t.name,
                            sub: late > 0 ? '$late late' : null,
                            trailing: '$present of ${loaded.length} days',
                            fraction: loaded.isEmpty ? 0 : present / loaded.length,
                          ),
                      ],
                    ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppText.display(size: 22, weight: FontWeight.w800, color: color)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, weight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _BarLine extends StatelessWidget {
  const _BarLine({required this.label, required this.trailing, required this.fraction, this.sub});

  final String label;
  final String? sub;
  final String trailing;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final color = fraction >= 0.8
        ? AppColors.emerald
        : fraction >= 0.5
            ? AppColors.honeyDark
            : AppColors.rose;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sub == null ? label : '$label · $sub',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 13, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(trailing, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppSurface.muted(context))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: AppSurface.line(context),
            ),
          ),
        ],
      ),
    );
  }
}
