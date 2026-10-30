import 'package:flutter/material.dart';

import '../feeding.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/feeding_widgets.dart';

/// A staff member's own clock-ins (palm or card at the gate) from
/// `attendance/me`, like the website's "My attendance" page.
class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key, required this.user, this.onBack, required this.onLogout});

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  static const _ranges = [('week', 'Last 7 days', 6), ('month', 'Last 30 days', 29), ('term', 'Last 90 days', 89)];
  static const _status = {
    'present': ('Present', 'green'),
    'late': ('Late', 'amber'),
    'absent': ('Absent', 'red'),
    'authorized_absence': ('Excused', 'blue'),
    'early_departure': ('Left early', 'amber'),
  };

  String _range = 'month';
  final List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _summary;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final back = _ranges.firstWhere((r) => r.$1 == _range).$3;
    final today = DateTime.now();
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await FeedingApi.myAttendance(
        from: dateKey(today.subtract(Duration(days: back))),
        to: dateKey(today),
        page: page,
      );
      if (!mounted) return;
      final meta = body['meta'] is Map ? body['meta'] as Map : const {};
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(FeedingApi.rows(body['data']));
        _summary = body['summary'] is Map ? Map<String, dynamic>.from(body['summary'] as Map) : _summary;
        _page = page;
        _lastPage = intOf(meta['last_page']) > 0 ? intOf(meta['last_page']) : page;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load your attendance. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final today = dateKey(DateTime.now());
    return Column(
      children: [
        AdminPageHeader(
          title: 'My attendance',
          subtitle: widget.user.displayName,
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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (key, label, _) in _ranges)
                      ChoiceChip(
                        label: Text(label),
                        selected: _range == key,
                        onSelected: (_) {
                          setState(() => _range = key);
                          _load();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TileGrid(
                  minWidth: 130,
                  children: [
                    TakingsTile(
                      label: 'Days in',
                      value: '${s == null ? 0 : intOf(s['present']) + intOf(s['late']) + intOf(s['early_departure'])}',
                    ),
                    TakingsTile(label: 'Late', value: '${intOf(s?['late'])}'),
                    TakingsTile(label: 'Absent', value: '${intOf(s?['absent'])}'),
                    TakingsTile(label: 'No check-out', value: '${intOf(s?['missing_checkout'])}'),
                  ],
                ),
                const SizedBox(height: 8),
                const MutedText('You clock in and out by scanning your palm or card at the gate.', size: 12),
                const SizedBox(height: 14),
                if (_error != null) MutedText(_error!),
                if (_rows.isEmpty && !_loading && _error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: MutedText('No clock-ins in this period.')),
                  ),
                for (final r in _rows) _row(r, today),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
                  )
                else if (_page < _lastPage)
                  Center(child: TextButton(onPressed: () => _load(more: true), child: const Text('Show more'))),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> r, String today) {
    final status = _status['${r['status']}'] ?? ('${r['status'] ?? ''}', 'gray');
    final inAt = textOf(r['check_in_at']);
    final outAt = textOf(r['check_out_at']);
    final date = '${r['date'] ?? ''}';
    final out = outAt != null
        ? timeLabel(outAt)
        : inAt != null && date.compareTo(today) < 0
            ? 'Missing'
            : '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayLabel(date), style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.ink(context))),
                const SizedBox(height: 2),
                MutedText(
                  'In ${inAt == null ? '—' : timeLabel(inAt)} · Out $out${r['auto_checked_out'] == true ? ' (auto)' : ''}'
                  '${textOf(r['note']) == null ? '' : ' · ${textOf(r['note'])}'}',
                  size: 12,
                ),
              ],
            ),
          ),
          FeedBadge(status.$1, tone: status.$2),
        ],
      ),
    );
  }
}
