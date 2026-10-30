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
/// bill and payment to work them out. Stays hidden when the figures can't be
/// read; the dashboard's other money card still shows.
class MoneyDashboardCard extends StatefulWidget {
  const MoneyDashboardCard({super.key, required this.user});

  final AppUser user;

  @override
  State<MoneyDashboardCard> createState() => _MoneyDashboardCardState();
}

class _MoneyDashboardCardState extends State<MoneyDashboardCard> {
  static const _periods = [('term', 'This term'), ('month', 'This month'), ('today', 'Today')];

  String _period = 'term';
  Map<String, dynamic>? _data;
  bool _failed = false;

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
              TakingsTile(label: 'Collected', value: cash('collected'), sub: payments('collected_count')),
              if (split) ...[
                TakingsTile(label: 'School fees', value: cash('fees_collected'), sub: payments('fees_count')),
                TakingsTile(label: 'Feeding', value: cash('feeding_collected'), sub: payments('feeding_count')),
              ],
              TakingsTile(label: 'Billed', value: cash('billed'), sub: _period == 'term' ? 'This term’s bills' : 'Bills issued'),
              TakingsTile(label: 'Outstanding', value: cash('outstanding'), sub: '$owing ${owing == 1 ? 'student' : 'students'} owing'),
              TakingsTile(
                label: 'Collection rate',
                value: rate == null ? '—' : '$rate%',
                sub: term == null ? 'No term bills yet' : 'of $term bills paid',
              ),
              TakingsTile(label: 'Expenses', value: cash('expenses'), sub: '${intOf(data['expenses_count'])} recorded'),
              TakingsTile(label: 'Money in vs out', value: cash('net'), sub: 'Collected minus expenses'),
            ],
          ),
        ],
      ),
    );
  }
}
