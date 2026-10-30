import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../core/config/api_config.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart' show showSnack;

/// Admin view of staff attendance for a day, grouped by department, like
/// the website's Attendance › Staff tab: everyone who clocks in
/// (`/staff?clocks_in=1`), their palm clock-in/out from
/// `/attendance?person_type=staff`, and "Mark staff attendance"
/// (`/attendance/manual`), which shows on the website straight away.
class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  DateTime _day = DateTime.now();
  bool _loading = false;
  String? _error;
  Map<String, Map<String, dynamic>> _byStaff = {};

  /// Staff who clock in, from the server; null until loaded (then the
  /// school's teachers are shown).
  List<NamedRecord>? _clockers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _dayKey =>
      '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final store = SchoolScope.of(context);
    final results = await Future.wait([store.staffAttendanceFor(_dayKey), _loadClockers()]);
    final rows = results[0] as List<Map<String, dynamic>>?;
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (rows == null) {
        _error = 'Could not load teacher attendance. Pull down to try again.';
        return;
      }
      _byStaff = {
        for (final row in rows)
          '${row['staff_id'] ?? (row['staff'] is Map ? (row['staff'] as Map)['id'] : '')}': row,
      };
    });
  }

  /// Everyone who clocks in (teachers and other staff), as the website lists.
  Future<void> _loadClockers() async {
    try {
      final body = await ApiClient.instance.get(ApiConfig.staffPath, query: {'clocks_in': '1', 'status': 'active', 'per_page': '200'});
      final data = body is Map ? body['data'] : null;
      if (data is! List) return;
      _clockers = [
        for (final r in data)
          if (r is Map)
            NamedRecord(
              id: '${r['id']}',
              name: '${r['full_name'] ?? r['name'] ?? ''}',
              detail: '${r['position'] ?? r['category'] ?? ''}',
              extra: r['department'] is Map ? '${(r['department'] as Map)['name'] ?? ''}' : '${r['department'] ?? ''}',
            ),
      ];
    } catch (_) {
      // Keep the school's teachers list.
    }
  }

  Future<void> _mark() async {
    final people = _clockers ?? SchoolScope.of(context).teachers;
    if (people.isEmpty) return;
    final saved = await showAppSheet<bool>(
      context: context,
      title: 'Mark staff attendance',
      builder: (_) => _MarkStaffForm(people: people, day: _day),
    );
    if (saved == true) await _load();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _day = picked);
    _load();
  }

  static String _state(Map<String, dynamic>? row) {
    if (row == null) return 'out';
    final status = '${row['status'] ?? ''}'.toLowerCase();
    if (status == 'absent') return 'absent';
    if (status == 'authorized_absence') return 'excused';
    if (status == 'late') return 'late';
    if (status == 'early_departure') return 'early';
    return 'in';
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final people = _clockers ?? store.teachers;
    final groups = <String, List<NamedRecord>>{};
    for (final t in people) {
      final dept = t.extra.trim().isEmpty ? 'No department' : t.extra.trim();
      groups.putIfAbsent(dept, () => []).add(t);
    }
    final deptNames = groups.keys.toList()
      ..sort((a, b) => a == 'No department' ? 1 : (b == 'No department' ? -1 : a.compareTo(b)));
    for (final list in groups.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    var inCount = 0, lateCount = 0, outCount = 0;
    for (final t in people) {
      switch (_state(_byStaff[t.id])) {
        case 'in' || 'early':
          inCount++;
        case 'late':
          lateCount++;
        default:
          outCount++;
      }
    }

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Staff attendance',
            subtitle: _isToday ? 'Today · by department' : '${formatStamp(_dayKey)} · by department',
            onBack: widget.onBack,
            trailing: IconButton(
              onPressed: _pickDay,
              tooltip: 'Pick a day',
              icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
            ),
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
                  Row(
                    children: [
                      _Tile(label: 'In', value: inCount, color: AppColors.emerald),
                      const SizedBox(width: 10),
                      _Tile(label: 'Late', value: lateCount, color: AppColors.honeyDark),
                      const SizedBox(width: 10),
                      _Tile(label: _isToday ? 'Not in yet' : 'Not in', value: outCount, color: AppColors.rose),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Staff clock in and out by scanning their palm or card at the gate. Marks you save here show on the website too.',
                    style: AppText.body(size: 12, color: AppSurface.muted(context)),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: people.isEmpty ? null : _mark,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: const Text('Mark staff attendance'),
                  ),
                  const SizedBox(height: 14),
                  if (people.isEmpty)
                    WhiteCard(
                      padding: const EdgeInsets.all(16),
                      child: Text('No staff who clock in yet.', style: AppText.body(size: 13, color: AppSurface.muted(context))),
                    ),
                  for (final dept in deptNames) ...[
                    _DeptCard(
                      name: dept,
                      teachers: groups[dept]!,
                      rows: _byStaff,
                      stateOf: _state,
                      past: !_isToday,
                    ),
                    const SizedBox(height: 12),
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

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.color});

  final String label;
  final int value;
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
            Text('$value', style: AppText.display(size: 22, weight: FontWeight.w800, color: color)),
            Text(label, style: AppText.body(size: 12, weight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DeptCard extends StatelessWidget {
  const _DeptCard({required this.name, required this.teachers, required this.rows, required this.stateOf, this.past = false});

  final String name;
  final List<NamedRecord> teachers;
  final Map<String, Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>?) stateOf;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final present = teachers.where((t) => !const {'out', 'absent', 'excused'}.contains(stateOf(rows[t.id]))).length;
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: AppText.body(size: 15, weight: FontWeight.w800))),
              Text('$present / ${teachers.length} in', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppSurface.muted(context))),
            ],
          ),
          const SizedBox(height: 6),
          for (final t in teachers)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppSurface.line(context)))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, weight: FontWeight.w700)),
                        if (t.detail.trim().isNotEmpty)
                          Text(t.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, color: AppColors.slate500)),
                      ],
                    ),
                  ),
                  _StateChip(row: rows[t.id], state: stateOf(rows[t.id]), past: past),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.row, required this.state, this.past = false});

  final Map<String, dynamic>? row;
  final String state;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final inAt = SchoolStore.clockOf(row?['check_in_at']);
    final rawOut = SchoolStore.clockOf(row?['check_out_at']);
    // A past day with a clock-in but no clock-out reads "Missing", as on the website.
    final outAt = rawOut.isEmpty && past && inAt.isNotEmpty ? 'Missing' : rawOut;
    final (String label, Color color) = switch (state) {
      'out' => ('Not scanned', AppColors.slate400),
      'absent' => ('Absent', AppColors.rose),
      'excused' => ('Excused', AppColors.sky),
      'early' => (inAt.isEmpty ? 'Left early' : '$inAt – ${outAt.isEmpty ? '?' : outAt} · left early', AppColors.honeyDark),
      'late' => (outAt.isEmpty ? 'Late · $inAt' : '$inAt – $outAt', AppColors.honeyDark),
      _ => (inAt.isEmpty ? 'Present' : (outAt.isEmpty ? 'In · $inAt' : '$inAt – $outAt'), AppColors.emerald),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: color)),
    );
  }
}

class _MarkStaffForm extends StatefulWidget {
  const _MarkStaffForm({required this.people, required this.day});

  final List<NamedRecord> people;
  final DateTime day;

  @override
  State<_MarkStaffForm> createState() => _MarkStaffFormState();
}

class _MarkStaffFormState extends State<_MarkStaffForm> {
  static const _statuses = [('present', 'Present'), ('late', 'Late'), ('absent', 'Absent'), ('authorized_absence', 'Excused')];

  NamedRecord? _who;
  late DateTime _date = widget.day;
  String _status = 'present';
  final _note = TextEditingController();
  bool _force = false;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _dateKey => '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final who = _who;
    if (who == null) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.post(ApiConfig.manualAttendancePath, {
        'person_type': 'staff',
        'staff_id': who.id,
        'date': _dateKey,
        'status': _status,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'force': _force,
      });
      if (!mounted) return;
      showSnack(context, 'Attendance saved for ${who.name}');
      closeRoute(context, true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save the attendance. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = [for (final p in widget.people) p.name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSelect(
          label: 'Staff member *',
          value: _who?.name ?? 'Select staff member…',
          items: ['Select staff member…', ...names],
          onChanged: (name) => setState(() => _who = widget.people.where((p) => p.name == name).firstOrNull),
        ),
        const AppFieldLabel('Date', required: true),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (picked != null) setState(() => _date = picked);
          },
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(formatStamp(_dateKey)),
        ),
        const SizedBox(height: 12),
        AppSelect(
          label: 'Status *',
          value: _statuses.firstWhere((s) => s.$1 == _status).$2,
          items: [for (final s in _statuses) s.$2],
          onChanged: (label) => setState(() => _status = _statuses.firstWhere((s) => s.$2 == label).$1),
        ),
        const AppFieldLabel('Note'),
        TextField(controller: _note, decoration: appFieldDecoration(context, hint: 'e.g. No morning scan')),
        CheckboxListTile(
          value: _force,
          onChanged: (v) => setState(() => _force = v ?? false),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Override an existing palm scan for this day'),
        ),
        const SizedBox(height: 10),
        AppModalButton(label: _saving ? 'Saving…' : 'Save mark', onPressed: _saving || _who == null ? null : _save),
      ],
    );
  }
}
