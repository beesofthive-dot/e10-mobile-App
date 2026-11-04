import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../core/config/api_config.dart';
import '../feeding.dart';
import '../models.dart';
import '../plan_access.dart';
import '../theme.dart';
import 'common.dart';
import 'feeding_widgets.dart';

/// The website's Money card (`GET /dashboard/money?period=`): the server's own
/// totals for the term, month or day, so nobody's phone has to download every
/// bill and payment to work them out. Each figure opens its page, and "Show
/// details" adds the weekly money in/out graph, the students owing the most
/// and the latest payments — all as on the website's dashboard. Stays hidden
/// when the figures can't be read; the dashboard's other money card still
/// shows.
class MoneyDashboardCard extends StatefulWidget {
  const MoneyDashboardCard({super.key, required this.user, this.onNav});

  final AppUser user;

  /// Opens the page behind a figure; figures are plain when null.
  final ValueChanged<AppScreen>? onNav;

  @override
  State<MoneyDashboardCard> createState() => _MoneyDashboardCardState();
}

class _MoneyDashboardCardState extends State<MoneyDashboardCard> {
  static const _periods = [('term', 'This term'), ('month', 'This month'), ('today', 'Today')];

  String _period = 'term';
  Map<String, dynamic>? _data;
  bool _failed = false;
  bool _details = false;

  bool get _allowed => widget.user.permissions.contains('payments.view') && PlanAccess.hasModule('fees');

  @override
  void initState() {
    super.initState();
    if (_allowed) _load();
  }

  Future<void> _load() async {
    final period = _period;
    try {
      final hit = await ApiClient.instance.get(ApiConfig.dashboardMoneyPath, query: {'period': period});
      final data = hit is Map && hit['data'] is Map ? Map<String, dynamic>.from(hit['data'] as Map) : null;
      if (!mounted || period != _period) return;
      setState(() {
        _data = data;
        _failed = data == null;
      });
    } catch (_) {
      if (mounted && period == _period) setState(() => _failed = true);
    }
  }

  void _pick(String period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  /// Tap action for a figure, only when this user can open that page.
  VoidCallback? _open(AppScreen screen) {
    final nav = widget.onNav;
    if (nav == null || !widget.user.canOpen(screen) || !PlanAccess.allows(screen)) return null;
    return () => nav(screen);
  }

  static List<Map<String, dynamic>> _rows(dynamic v) =>
      v is List ? [for (final r in v) if (r is Map) Map<String, dynamic>.from(r)] : const [];

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (!_allowed || _failed || data == null) return const SizedBox.shrink();
    final currency = schoolCurrency();
    String cash(String key) => money(data[key], currency);
    String payments(String key) => plural(intOf(data[key]), 'payment');
    final split = data['feeding_collected'] != null;
    final rate = data['collection_rate'];
    final owing = intOf(data['students_owing']);
    final term = textOf(data['collection_term']);
    final label = textOf(data['label']);
    final net = numOf(data['net']);
    final chart = _rows(data['chart']);
    final topOwing = _rows(data['top_owing']);
    final latest = _rows(data['latest_payments']);
    final muted = AppText.body(size: 12, color: AppSurface.muted(context));

    Widget tile(String label, String value, String sub, AppScreen screen, {Color? tone}) {
      final onTap = _open(screen);
      final child = TakingsTile(label: label, value: value, sub: sub, valueColor: tone);
      return onTap == null
          ? child
          : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.md), child: child);
    }

    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label == null ? 'Money' : 'Money · $label', style: AppText.display(size: 16, weight: FontWeight.w700, color: AppSurface.ink(context))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _periods)
                ChoiceChip(
                  label: Text(p.$2),
                  selected: _period == p.$1,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _pick(p.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TileGrid(
            minWidth: 140,
            children: [
              tile('Collected', cash('collected'), split ? 'School fees + feeding · ${payments('collected_count')}' : payments('collected_count'),
                  AppScreen.adminFinance, tone: AppColors.emerald),
              if (split) ...[
                tile('School fees', cash('fees_collected'), payments('fees_count'), AppScreen.adminFinance, tone: AppColors.emerald),
                tile('Feeding', cash('feeding_collected'), payments('feeding_count'), AppScreen.feedingToday, tone: AppColors.emerald),
              ],
              tile('Billed', cash('billed'), _period == 'term' ? 'This term’s bills' : 'Bills issued', AppScreen.adminFinance),
              tile('Outstanding', cash('outstanding'), '$owing ${owing == 1 ? 'student' : 'students'} owing', AppScreen.adminFinance,
                  tone: AppColors.honeyDark),
              tile('Collection rate', rate == null ? '—' : '$rate%', term == null ? 'No term bills yet' : 'of $term bills paid', AppScreen.adminFinance),
              tile('Expenses', cash('expenses'), '${intOf(data['expenses_count'])} recorded', AppScreen.expenses, tone: AppColors.rose),
              tile('Money in vs out', cash('net'), 'Collected minus expenses', AppScreen.expenses,
                  tone: net < 0 ? AppColors.rose : AppColors.emerald),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() => _details = !_details),
            icon: Icon(_details ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
            label: Text(_details ? 'Hide details' : 'Show details'),
          ),
          if (_details) ...[
            if (chart.length > 1) ...[
              Row(
                children: [
                  _Legend(color: AppColors.emerald, label: 'Money in'),
                  const SizedBox(width: 12),
                  _Legend(color: AppColors.rose, label: 'Money out'),
                  const SizedBox(width: 6),
                  Text('· by week', style: muted),
                ],
              ),
              const SizedBox(height: 8),
              MoneyInOutChart(points: chart, currency: currency),
              const SizedBox(height: 14),
            ],
            Text('Students owing the most', style: AppText.body(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (topOwing.isEmpty)
              Text('Nobody owes anything.', style: muted)
            else
              for (final r in topOwing)
                _MoneyRow(
                  title: textOf(r['full_name']) ?? 'Student',
                  sub: textOf(r['admission_number']),
                  amount: money(r['owed'], currency),
                ),
            const SizedBox(height: 12),
            Text('Latest payments', style: AppText.body(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (latest.isEmpty)
              Text('No payments yet.', style: muted)
            else
              for (final r in latest)
                _MoneyRow(
                  title: textOf(r['student']) ?? '—',
                  sub: '${methodLabel(r['method'])} · ${dayLabel(r['paid_at'])}',
                  amount: money(r['amount'], currency),
                ),
            const SizedBox(height: 10),
            Text('Counts only money recorded in e10. Cash received but not entered is not included.',
                style: AppText.body(size: 11, color: AppSurface.muted(context))),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: AppText.body(size: 12, color: AppSurface.muted(context))),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.title, required this.amount, this.sub});

  final String title;
  final String? sub;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppSurface.line(context)))),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: title, style: AppText.body(size: 13, weight: FontWeight.w600)),
                if (sub != null && sub!.isNotEmpty)
                  TextSpan(text: ' · $sub', style: AppText.body(size: 11, color: AppSurface.muted(context))),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(amount, style: AppText.body(size: 13, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Money in (green) and out (red) side by side per week, scaled to the
/// biggest bar; scrolls sideways when there are more weeks than fit.
class MoneyInOutChart extends StatelessWidget {
  const MoneyInOutChart({super.key, required this.points, required this.currency});

  final List<Map<String, dynamic>> points;
  final String currency;

  @override
  Widget build(BuildContext context) {
    var top = 1.0;
    for (final p in points) {
      top = [top, numOf(p['in']), numOf(p['out'])].reduce((a, b) => a > b ? a : b);
    }
    const barHeight = 96.0;
    Widget bar(double v, Color c) => Container(
          width: 11,
          height: v <= 0 ? 0 : (v / top * barHeight).clamp(2, barHeight).toDouble(),
          decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
        );
    return SizedBox(
      height: barHeight + 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: points.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = points[i];
          final label = textOf(p['label']) ?? '';
          return Tooltip(
            message: '$label: in ${money(p['in'], currency)}, out ${money(p['out'], currency)}',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [bar(numOf(p['in']), AppColors.emerald), const SizedBox(width: 2), bar(numOf(p['out']), AppColors.rose)],
                ),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, style: AppText.body(size: 10, color: AppSurface.muted(context))),
              ],
            ),
          );
        },
      ),
    );
  }
}
