import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import 'common.dart';
import 'dash_cards.dart';
import 'report_photos.dart';

class FinanceDashRow {
  const FinanceDashRow({required this.name, required this.amount, required this.meta});

  final String name;
  final String amount;
  final String meta;
}

class FinanceDashboardCard extends StatelessWidget {
  const FinanceDashboardCard({
    super.key,
    required this.collected,
    required this.outstanding,
    required this.hint,
    required this.recent,
    required this.onOpen,
    this.title = 'Transactions',
    this.actionLabel = 'See all',
  });

  final String collected;
  final String outstanding;
  final String hint;
  final List<FinanceDashRow> recent;
  final VoidCallback onOpen;
  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppText.display(size: 16, weight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: onOpen,
                child: Text(actionLabel, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onOpen,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Money in', style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.ink(context))),
                        const SizedBox(height: 4),
                        Text(collected, style: AppText.display(size: 18, weight: FontWeight.w800, color: AppSurface.ink(context))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onOpen,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE4E6), Color(0xFFFECDD3)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Still due', style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.ink(context))),
                        const SizedBox(height: 4),
                        Text(outstanding, style: AppText.display(size: 18, weight: FontWeight.w800, color: AppSurface.ink(context))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(hint, style: AppText.body(size: 13, color: AppSurface.ink(context))),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Latest activity', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
            const SizedBox(height: 6),
            for (final row in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w600, color: AppSurface.ink(context))),
                          Text(row.meta, style: AppText.body(size: 12, color: AppSurface.ink(context))),
                        ],
                      ),
                    ),
                    Text(row.amount, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.ink(context))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Latest chats for home dashboards (parent / teacher / admin).
class RecentMessagesCard extends StatelessWidget {
  const RecentMessagesCard({
    super.key,
    required this.threads,
    required this.onOpenAll,
    required this.onOpenThread,
    this.viewerRole,
  });

  final List<ChatPreview> threads;
  final VoidCallback onOpenAll;
  final ValueChanged<ChatPreview> onOpenThread;
  final Role? viewerRole;

  bool _outgoing(ChatPreview thread) {
    final role = viewerRole;
    if (role == null || thread.sentByRole == null) return false;
    return thread.sentByRole == role;
  }

  bool _unreadIncoming(ChatPreview thread) {
    if (_outgoing(thread)) return false;
    return thread.unread;
  }

  @override
  Widget build(BuildContext context) {
    final latest = threads.take(4).toList();
    final unreadTotal = latest.where(_unreadIncoming).fold<int>(0, (sum, t) => sum + t.badgeCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  unreadTotal > 0 ? 'Messages · $unreadTotal waiting' : 'Messages',
                  style: AppText.display(size: 16, weight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: onOpenAll,
                child: Text(
                  'Catch up',
                  style: AppText.body(size: 14, weight: FontWeight.w600, color: AppSurface.ink(context)),
                ),
              ),
            ],
          ),
        ),
        if (latest.isEmpty)
          const WhiteCard(
            padding: EdgeInsets.all(14),
            child: Text('No chats yet. Tap Catch up to start one.'),
          )
        else
          WhiteCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < latest.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  InkWell(
                    onTap: () => onOpenThread(latest[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _unreadIncoming(latest[i])
                                ? AppColors.accentSoft
                                : AppColors.slate100,
                            child: Text(
                              latest[i].from.isEmpty ? '?' : latest[i].from[0].toUpperCase(),
                              style: AppText.body(size: 13, weight: FontWeight.w800, color: AppSurface.ink(context)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latest[i].from,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                    size: 14,
                                    weight: _unreadIncoming(latest[i]) ? FontWeight.w800 : FontWeight.w600,
                                    color: AppSurface.ink(context),
                                  ),
                                ),
                                Text(
                                  latest[i].preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                    size: 12,
                                    weight: _unreadIncoming(latest[i]) ? FontWeight.w600 : FontWeight.w400,
                                    color: AppSurface.ink(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatStamp(latest[i].time), style: AppText.body(size: 11, color: AppSurface.ink(context))),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _unreadIncoming(latest[i])
                                      ? AppColors.accentSoft
                                      : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _unreadIncoming(latest[i])
                                      ? '${latest[i].badgeCount} new'
                                      : (_outgoing(latest[i]) ? 'Sent' : 'Read'),
                                  style: AppText.body(
                                    size: 10,
                                    weight: FontWeight.w700,
                                    color: AppSurface.ink(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Today's attendance alerts — "arrived", "late", "very late", "absent" —
/// shown on the admin and parent dashboards.
class AttendanceAlertsCard extends StatelessWidget {
  const AttendanceAlertsCard({super.key, required this.items, required this.onOpen, this.status, this.statusColor});

  final List<AppNotification> items;
  final VoidCallback onOpen;

  /// Parent view: the child's own status today ("Arrived 07:42 · palm scan").
  final String? status;
  final Color? statusColor;

  static const _amber = Color(0xFFF59E0B);

  (Color, IconData) _tone(AppNotification n) {
    if (n.type == 'attendance_absent') return (AppColors.rose, Icons.person_off_rounded);
    if (n.type == 'attendance_late') return (n.text.contains('very late') ? AppColors.roseDark : _amber, Icons.schedule_rounded);
    return (AppColors.emerald, Icons.check_circle_rounded);
  }

  String _clock(String raw) {
    final d = DateTime.tryParse(raw.trim())?.toLocal();
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final shown = items.take(5).toList();
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Attendance today', style: AppText.display(size: 16, weight: FontWeight.w700))),
              GestureDetector(
                onTap: onOpen,
                child: Text('See all', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (status != null)
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (statusColor ?? AppColors.slate500).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.back_hand_rounded, size: 18, color: statusColor ?? AppColors.slate500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(status!, style: AppText.body(size: 14, weight: FontWeight.w700, color: statusColor ?? AppColors.slate500)),
                    ),
                  ],
                ),
              ),
            ),
          if (shown.isEmpty && status == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('No arrival, late or absent alerts yet today.', style: AppText.body(size: 13, color: AppSurface.ink(context))),
            )
          else
            for (final n in shown)
              Builder(builder: (context) {
                final (color, icon) = _tone(n);
                return InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, size: 17, color: color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            n.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 13, weight: n.unread ? FontWeight.w700 : FontWeight.w500, color: AppSurface.ink(context)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_clock(n.time), style: AppText.body(size: 11, color: AppSurface.ink(context))),
                      ],
                    ),
                  ),
                );
              }),
        ],
      ),
    );
  }
}


/// Today's daily report for a crèche/KG child, on the parent's dashboard: the
/// summary once the teacher has sent it, otherwise "not sent yet". Re-checks
/// every 30 seconds so a report sent while the app is open appears by itself.
class DailyReportHomeCard extends StatefulWidget {
  const DailyReportHomeCard({super.key, required this.child, required this.onOpen});

  final Student child;
  final VoidCallback onOpen;

  @override
  State<DailyReportHomeCard> createState() => _DailyReportHomeCardState();
}

class _DailyReportHomeCardState extends State<DailyReportHomeCard> {
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _failed = false;
  String _error = '';
  bool _started = false;
  Timer? _poll;

  String get _today {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load(quiet: true));
  }

  @override
  void didUpdateWidget(covariant DailyReportHomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.id != widget.child.id) {
      _report = null;
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    final store = SchoolScope.of(context);
    final result = await store.fetchSentDailyReport(widget.child, _today);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.error.isNotEmpty) {
        if (_report == null) {
          _failed = true;
          _error = result.error;
        }
      } else {
        _failed = false;
        _error = '';
        _report = result.report;
      }
    });
  }

  String _label(dynamic v) {
    final t = '${v ?? ''}'.trim();
    return t.isEmpty ? '' : t[0].toUpperCase() + t.substring(1).replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final facts = <String>[
      if (r != null && _label(r['mood']).isNotEmpty) 'Mood: ${_label(r['mood'])}',
      if (r != null && _label(r['breakfast_status']).isNotEmpty) 'Breakfast: ${_label(r['breakfast_status'])}',
      if (r != null && _label(r['lunch_status']).isNotEmpty) 'Lunch: ${_label(r['lunch_status'])}',
      if (r != null && _label(r['snack_status']).isNotEmpty) 'Snack: ${_label(r['snack_status'])}',
      if (r != null && '${r['nap_minutes'] ?? ''}'.isNotEmpty && '${r['nap_minutes']}' != 'null') 'Nap: ${r['nap_minutes']} min',
    ];
    final note = r == null ? '' : '${r['note'] ?? ''}'.trim();
    return GestureDetector(
      onTap: widget.onOpen,
      child: WhiteCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.child_care_rounded, size: 18, color: AppColors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text("Today's daily report", style: AppText.display(size: 16, weight: FontWeight.w700))),
                Text('Open', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_failed)
              Text('Could not load the report: $_error', style: AppText.body(size: 13, color: AppSurface.ink(context)))
            else if (r == null)
              Text('${widget.child.name}\'s report has not been sent yet today.', style: AppText.body(size: 13, color: AppSurface.ink(context)))
            else ...[
              if (SchoolScope.of(context).dailyReportPhotos(r).isNotEmpty) ...[
                ReportPhotoGallery(
                  height: 170,
                  photos: [
                    for (final p in SchoolScope.of(context).dailyReportPhotos(r)) ReportPhoto(id: p.id, url: p.url),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (facts.isNotEmpty) Text(facts.join(' · '), style: AppText.body(size: 13, weight: FontWeight.w600)),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(note, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, color: AppSurface.ink(context))),
              ],
            ],
          ],
        ),
      ),
    );
  }
}


/// Exams and report cards on a dashboard, kept current from the school API
/// (re-checked every minute). A parent sees their child's exams — with the
/// child's own score once an exam is published — and the report cards the
/// school has published; teachers and admins see the school's latest exams
/// and every report card with its draft/published state.
class ExamsReportsHomeCard extends StatefulWidget {
  const ExamsReportsHomeCard({super.key, this.child, required this.onOpenExams, required this.onOpenReports});

  /// The parent's selected child; null for staff.
  final Student? child;
  final VoidCallback onOpenExams;
  final VoidCallback onOpenReports;

  @override
  State<ExamsReportsHomeCard> createState() => _ExamsReportsHomeCardState();
}

class _ExamsReportsHomeCardState extends State<ExamsReportsHomeCard> {
  List<Map<String, dynamic>> _exams = const [];
  List<Map<String, dynamic>> _reports = const [];
  bool _loading = true;
  String _error = '';
  bool _started = false;
  Timer? _poll;

  bool get _parent => widget.child != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void didUpdateWidget(covariant ExamsReportsHomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child?.id != widget.child?.id) {
      setState(() => _loading = true);
      _load();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await SchoolScope.of(context).fetchExamsAndReports(studentId: widget.child?.id ?? '');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      _exams = result.exams;
      _reports = result.reports;
    });
  }

  static bool _published(Map<String, dynamic> row) =>
      row['published'] == true || row['published'] == 1 || '${row['published_at'] ?? ''}'.trim().isNotEmpty && '${row['published_at']}' != 'null';

  static String _name(dynamic v) => v is Map ? '${v['name'] ?? v['full_name'] ?? ''}'.trim() : '';

  static String _day(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  /// The parent's child's own result on an exam, if the school recorded it.
  Map<String, dynamic>? _resultFor(Map<String, dynamic> exam) {
    final results = exam['results'];
    if (results is! List) return null;
    for (final r in results) {
      if (r is Map && '${r['student_id']}' == widget.child!.id) return Map<String, dynamic>.from(r);
    }
    return null;
  }

  List<Map<String, dynamic>> get _examRows {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    DateTime when(Map<String, dynamic> e) => DateTime.tryParse('${e['exam_date'] ?? ''}') ?? DateTime(2000);
    final upcoming = [for (final e in _exams) if (!when(e).isBefore(start)) e]..sort((a, b) => when(a).compareTo(when(b)));
    final past = [for (final e in _exams) if (when(e).isBefore(start)) e]..sort((a, b) => when(b).compareTo(when(a)));
    return [...upcoming, ...past].take(3).toList();
  }

  List<Map<String, dynamic>> get _reportRows {
    final visible = _parent ? [for (final r in _reports) if (_published(r)) r] : List<Map<String, dynamic>>.of(_reports);
    DateTime when(Map<String, dynamic> r) => DateTime.tryParse('${r['published_at'] ?? r['issued_date'] ?? r['updated_at'] ?? ''}') ?? DateTime(2000);
    visible.sort((a, b) => when(b).compareTo(when(a)));
    return visible.take(3).toList();
  }

  String _average(Map<String, dynamic> report) {
    final lines = report['lines'];
    if (lines is! List || lines.isEmpty) return '';
    final scores = [
      for (final l in lines)
        if (l is Map && num.tryParse('${l['score'] ?? ''}') != null) num.parse('${l['score']}'),
    ];
    if (scores.isEmpty) return '';
    return 'Average ${(scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(1)}%';
  }

  Widget _row({required IconData icon, required Color color, required String title, required String subtitle, String badge = '', Color? badgeColor, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, weight: FontWeight.w700)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, color: AppSurface.ink(context))),
                ],
              ),
            ),
            if (badge.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: (badgeColor ?? AppColors.blue).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(badge, style: AppText.body(size: 10, weight: FontWeight.w800, color: AppSurface.ink(context))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String action, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: AppText.label())),
          GestureDetector(onTap: onTap, child: Text(action, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppSurface.ink(context)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exams = _examRows;
    final reports = _reportRows;
    final drafts = _parent ? 0 : _reports.where((r) => !_published(r)).length;
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('Exams & reports', style: AppText.display(size: 16, weight: FontWeight.w700))),
              if (!_parent && !_loading)
                Text('${_exams.length} exams · ${_reports.length} reports', style: AppText.body(size: 11, color: AppSurface.ink(context))),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            if (_error.isNotEmpty && _exams.isEmpty && _reports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Could not load exams and reports: $_error', style: AppText.body(size: 13, color: AppSurface.ink(context))),
              ),
            _section('Exams', 'See all', widget.onOpenExams),
            if (exams.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(_parent ? 'No exams scheduled for ${widget.child!.name} yet.' : 'No exams set yet.', style: AppText.body(size: 12, color: AppSurface.ink(context))),
              )
            else
              for (final e in exams)
                Builder(builder: (context) {
                  final date = DateTime.tryParse('${e['exam_date'] ?? ''}');
                  final upcoming = date != null && !date.isBefore(today);
                  final result = _parent && _published(e) ? _resultFor(e) : null;
                  final max = '${e['max_score'] ?? ''}';
                  final badge = result != null
                      ? [
                          '${result['score'] ?? '—'}${max.isNotEmpty && max != 'null' ? '/$max' : ''}',
                          if ('${result['grade'] ?? ''}'.trim().isNotEmpty && '${result['grade']}' != 'null') '${result['grade']}',
                        ].join(' · ')
                      : upcoming
                          ? (date.isAtSameMomentAs(today) ? 'Today' : 'Upcoming')
                          : (_published(e) ? 'Published' : (_parent ? 'Awaiting results' : 'Draft'));
                  return _row(
                    icon: Icons.quiz_rounded,
                    color: AppColors.violet,
                    title: '${e['name'] ?? 'Exam'}',
                    subtitle: [
                      _name(e['subject']),
                      if (!_parent) _name(e['class']),
                      if ('${e['exam_date'] ?? ''}'.isNotEmpty && '${e['exam_date']}' != 'null') _day('${e['exam_date']}'),
                    ].where((p) => p.isNotEmpty).join(' · '),
                    badge: badge,
                    badgeColor: result != null ? AppColors.emerald : (upcoming ? AppColors.honeyDark : AppColors.slate500),
                    onTap: widget.onOpenExams,
                  );
                }),
            _section('Report cards', 'Open', widget.onOpenReports),
            if (reports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _parent ? 'No report card has been published for ${widget.child!.name} yet.' : 'No report cards yet.',
                  style: AppText.body(size: 12, color: AppSurface.ink(context)),
                ),
              )
            else
              for (final r in reports)
                _row(
                  icon: Icons.description_rounded,
                  color: AppColors.blue,
                  title: [
                    if (!_parent) _name(r['student']),
                    _name(r['academic_term']).isNotEmpty ? _name(r['academic_term']) : 'Report card',
                  ].where((p) => p.isNotEmpty).join(' · '),
                  subtitle: [
                    _average(r),
                    if ('${r['promotion_status'] ?? ''}'.trim().isNotEmpty && '${r['promotion_status']}' != 'null') '${r['promotion_status']}'.replaceAll('_', ' '),
                    if ('${r['attendance_summary'] ?? ''}'.isNotEmpty && '${r['attendance_summary']}' != 'null') 'Attendance ${r['attendance_summary']}',
                  ].where((p) => p.isNotEmpty).join(' · '),
                  badge: _published(r) ? 'Published' : 'Draft',
                  badgeColor: _published(r) ? AppColors.emerald : AppColors.honeyDark,
                  onTap: widget.onOpenReports,
                ),
            if (!_parent && drafts > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text('$drafts report card${drafts == 1 ? '' : 's'} not published yet', style: AppText.body(size: 11, color: AppSurface.ink(context))),
              ),
          ],
        ],
      ),
    );
  }
}

/// The newest school announcements on a home dashboard (admin, teacher and
/// parent). The server only sends each person the announcements meant for
/// them — school-wide ones, their role's, and their own classes' — so this
/// just shows the latest of whatever arrived, newest first.
class LatestAnnouncementsCard extends StatelessWidget {
  const LatestAnnouncementsCard({super.key, required this.onOpen, this.limit = 3});

  final VoidCallback onOpen;
  final int limit;

  static String _s(dynamic v) => v == null || '$v' == 'null' ? '' : '$v'.trim();

  static String _stamp(Map<String, dynamic> row) => _s(row['posted_at'] ?? row['created_at']);

  static String _poster(Map<String, dynamic> row) {
    final poster = row['poster'];
    final name = poster is Map ? _s(poster['full_name']) : '';
    return name.isEmpty ? 'School' : name;
  }

  static String _audience(SchoolStore store, Map<String, dynamic> row) {
    return switch (_s(row['audience'])) {
      'all' || '' => 'Everyone',
      'parents' => 'Parents',
      'teachers' => 'Teachers',
      'students' => 'Students',
      'single_class' => row['class'] is Map && _s((row['class'] as Map)['name']).isNotEmpty
          ? _s((row['class'] as Map)['name'])
          : store.classDisplayName(_s(row['class_id'])),
      final other => other,
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    DateTime when(Map<String, dynamic> r) => DateTime.tryParse(_stamp(r)) ?? DateTime(2000);
    final rows = [...store.tableRows('announcements')]..sort((a, b) => when(b).compareTo(when(a)));
    final shown = rows.take(limit).toList();
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 18, color: AppSurface.brand(context)),
              const SizedBox(width: 8),
              Expanded(child: Text('Announcements', style: AppText.display(size: 16, weight: FontWeight.w700))),
              GestureDetector(
                onTap: onOpen,
                child: Text('See all', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('No announcements yet.', style: AppText.body(size: 13, color: AppSurface.ink(context))),
            )
          else
            for (final row in shown)
              InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _s(row['title']).isEmpty ? 'Announcement' : _s(row['title']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(size: 14, weight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppSurface.brand(context).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _audience(store, row),
                              style: AppText.body(size: 10, weight: FontWeight.w800, color: AppSurface.ink(context)),
                            ),
                          ),
                        ],
                      ),
                      if (_s(row['body']).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _s(row['body']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 12.5, color: AppSurface.ink(context)),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        [_poster(row), formatStamp(_stamp(row))].where((p) => p.isNotEmpty).join(' · '),
                        style: AppText.body(size: 11, color: AppSurface.ink(context)),
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

/// The timetable on a dashboard, arranged by day like the main website:
/// Monday–Friday tabs (Saturday/Sunday too when the school has lessons
/// then), opening on today, each day's periods in time order, breaks and
/// lunch named, and the period on right now highlighted.
class WeekTimetableCard extends StatefulWidget {
  const WeekTimetableCard({
    super.key,
    required this.slots,
    required this.onOpen,
    this.title = 'Timetable',
    this.showClass = false,
    this.emptyText = 'Nothing scheduled.',
  });

  final List<TimeSlot> slots;
  final VoidCallback onOpen;
  final String title;
  final bool showClass;
  final String emptyText;

  @override
  State<WeekTimetableCard> createState() => _WeekTimetableCardState();
}

class _WeekTimetableCardState extends State<WeekTimetableCard> {
  late String _day = _defaultDay;

  static String get _today => SchoolStore.weekdays[DateTime.now().weekday - 1];

  List<String> get _days => [
        ...SchoolStore.weekdays.take(5),
        for (final d in SchoolStore.weekdays.skip(5))
          if (widget.slots.any((s) => s.day == d)) d,
      ];

  String get _defaultDay => _days.contains(_today) ? _today : SchoolStore.weekdays.first;

  bool _isNow(TimeSlot slot) {
    if (slot.day != _today) return false;
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final start = SchoolStore.slotMinutes(slot.start);
    final end = slot.end.isEmpty ? start + 45 : SchoolStore.slotMinutes(slot.end);
    return minutes >= start && minutes < end;
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    if (!days.contains(_day)) _day = _defaultDay;
    final periods = SchoolStore.slotsForDay(widget.slots, _day);
    final brand = AppSurface.brand(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(title: widget.title, action: 'Full timetable', onAction: widget.onOpen),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(d == _today ? '${d.substring(0, 3)} · Today' : d.substring(0, 3)),
                    selected: d == _day,
                    showCheckmark: false,
                    selectedColor: brand.withValues(alpha: 0.16),
                    labelStyle: AppText.body(size: 12, weight: FontWeight.w700),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _day = d),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (periods.isEmpty)
          WhiteCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              widget.slots.isEmpty ? widget.emptyText : 'Nothing scheduled on $_day.',
              style: AppText.body(size: 13),
            ),
          )
        else
          for (final slot in periods)
            ScheduleRow(
              title: slot.subject.isEmpty ? 'Lesson' : slot.subject,
              subtitle: [
                if (widget.showClass && slot.className.isNotEmpty) slot.className,
                if (slot.kind == 'lesson' && slot.teacher.isNotEmpty && !widget.showClass) slot.teacher,
                if (slot.room.isNotEmpty) slot.room.toLowerCase().startsWith('room') ? slot.room : 'Room ${slot.room}',
              ].join(' · '),
              time: slot.end.isEmpty ? slot.start : '${slot.start} – ${slot.end}',
              isNow: _isNow(slot),
            ),
      ],
    );
  }
}
