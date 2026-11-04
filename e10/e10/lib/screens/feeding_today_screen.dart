import 'dart:async';

import 'package:flutter/material.dart';

import '../feeding.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/feeding_manage.dart';
import '../widgets/feeding_widgets.dart';
import '../widgets/popups.dart';

/// "Feeding today": pick a class (or search a child), see who is covered or
/// owes, and record feeding payments. Same data and rules as the website's
/// Feeding today tab, for whichever school is signed in.
class FeedingTodayScreen extends StatefulWidget {
  const FeedingTodayScreen({super.key, required this.user, this.onBack, required this.onLogout});

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<FeedingTodayScreen> createState() => _FeedingTodayScreenState();
}

class _FeedingTodayScreenState extends State<FeedingTodayScreen> {
  final _currency = schoolCurrency();
  final _search = TextEditingController();
  String _classId = '';
  String _show = 'all';
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _myDay;
  Map<String, dynamic>? _justPaid;
  Timer? _debounce;
  int _seq = 0;

  bool get _canCollect => FeedingAccess.collectFeeding(widget.user);
  String _money(dynamic v) => money(v, _currency);

  @override
  void initState() {
    super.initState();
    _load();
    _loadMyDay();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final data = await FeedingApi.today(classId: _classId, search: _search.text);
      if (mounted && seq == _seq) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = 'Could not load feeding. $e');
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  void _loadMyDay() {
    if (!_canCollect) return;
    FeedingApi.feedingMyDay().then((d) {
      if (mounted) setState(() => _myDay = d);
    }).catchError((_) {
      if (mounted) setState(() => _myDay = null);
    });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _record(Map<String, dynamic> row) async {
    final data = _data;
    if (data == null) return;
    final result = await showFeedingPaymentSheet(
      context,
      student: row,
      weekDays: intOf(data['week_days']) > 0 ? intOf(data['week_days']) : 5,
      monthDays: intOf(data['month_days']) > 0 ? intOf(data['month_days']) : 20,
      currency: _currency,
    );
    if (result == null || !mounted) return;
    final status = result['status'] is Map ? Map<String, dynamic>.from(result['status'] as Map) : null;
    final payment = result['payment'] is Map ? Map<String, dynamic>.from(result['payment'] as Map) : null;
    setState(() {
      if (status != null) {
        final students = FeedingApi.rows(data['students']);
        _data = {
          ...data,
          'students': [
            for (final s in students) '${s['student_id']}' == '${status['student_id']}' ? status : s,
          ],
        };
      }
      _justPaid = payment;
    });
    _loadMyDay();
  }

  /// The website's Feeding tabs, each shown only with its permission.
  List<(String, String)> get _tabs {
    final u = widget.user;
    final collectOrView = FeedingAccess.collectFeeding(u) || FeedingAccess.seeAllFeeding(u);
    return [
      if (collectOrView) ('today', 'Feeding today'),
      if (collectOrView) ('payments', 'Payments'),
      if (FeedingAccess.cashup(u)) ('cashup', 'Cash-up'),
      if (FeedingAccess.seeAllFeeding(u)) ('report', 'Report'),
      if (FeedingAccess.feedingSettings(u)) ('whopays', 'Who pays'),
      if (FeedingAccess.feedingSettings(u)) ('settings', 'Rates & days'),
    ];
  }

  late String _tab = _tabs.isEmpty ? 'today' : _tabs.first.$1;

  Widget _tabBar() {
    final tabs = _tabs;
    if (tabs.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (key, label) in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(label), selected: _tab == key, onSelected: (_) => setState(() => _tab = key)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tab != 'today') {
      return Column(
        children: [
          AdminPageHeader(
            title: 'Feeding',
            subtitle: dayLabel(dateKey(DateTime.now())),
            onBack: widget.onBack,
            trailing: SchoolMarkButton(user: widget.user, onLogout: widget.onLogout, light: true),
          ),
          Expanded(
            child: ListView(
              padding: AppLayout.page(context),
              children: [
                _tabBar(),
                switch (_tab) {
                  'payments' => FeedingPaymentsTab(user: widget.user, currency: _currency),
                  'cashup' => FeedingCashupTab(currency: _currency),
                  'report' => FeedingReportTab(currency: _currency),
                  'whopays' => FeedingWhoPaysTab(currency: _currency),
                  _ => FeedingSettingsTab(currency: _currency),
                },
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      );
    }
    final data = _data;
    final all = FeedingApi.rows(data?['students']);
    final shown = [for (final s in all) if (_show == 'all' || s['state'] == _show) s];
    final covered = all.where((s) => s['state'] == 'covered').length;
    final unpaidPresent =
        all.where((s) => s['state'] == 'unpaid_present' && s['boarder'] != true && s['rate'] != null).length;
    final classes = FeedingApi.rows(data?['classes']);
    final picking = _classId.isEmpty && _search.text.trim().length < 2;
    final notFeedingDay = data != null && data['feeding_today'] == false;
    return Column(
      children: [
        AdminPageHeader(
          title: _tabs.length > 1 ? 'Feeding' : 'Feeding today',
          subtitle: '${dayLabel(data?['date'] ?? dateKey(DateTime.now()))}${notFeedingDay ? ' (not a feeding day)' : ''}',
          onBack: widget.onBack,
          trailing: SchoolMarkButton(user: widget.user, onLogout: widget.onLogout, light: true),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _loadMyDay();
              await _load();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppLayout.page(context),
              children: [
                _tabBar(),
                if (_error != null) ...[
                  MutedText(_error!),
                  const SizedBox(height: 12),
                ],
                if (data != null && data['set_up'] == false) ...[
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Feeding isn’t set up yet.', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.ink(context))),
                        const SizedBox(height: 4),
                        const MutedText(
                          'The bursar or an admin sets the feeding days and the daily rate for the school, a department or a class.',
                          size: 12.5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_justPaid != null) ...[
                  _paidBanner(_justPaid!),
                  const SizedBox(height: 12),
                ],
                CounterSection(
                  title: 'Children',
                  action: SmallAction(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      _load();
                      _loadMyDay();
                    },
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSelect(
                        label: 'Class',
                        value: classes.firstWhere((c) => '${c['id']}' == _classId, orElse: () => const {})['name']?.toString() ??
                            'Pick a class…',
                        items: ['Pick a class…', for (final c in classes) '${c['name'] ?? ''}'],
                        onChanged: (name) {
                          final match = classes.firstWhere((c) => '${c['name']}' == name, orElse: () => const {});
                          setState(() {
                            _classId = '${match['id'] ?? ''}';
                            _search.clear();
                          });
                          _load();
                        },
                      ),
                      TextField(
                        controller: _search,
                        onChanged: _onSearch,
                        decoration: appFieldDecoration(context, hint: 'Or search a name / admission no.')
                            .copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 18)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (value, label) in const [
                            ('all', 'Everyone'),
                            ('unpaid_present', 'Present and not paid'),
                            ('unpaid', 'Not paid'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _show == value,
                              onSelected: (_) => setState(() => _show = value),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      if (all.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${all.length} ${all.length == 1 ? 'child' : 'children'} · $covered covered · '),
                            TextSpan(
                              text: '$unpaidPresent present and not paid',
                              style: TextStyle(color: unpaidPresent > 0 ? const Color(0xFFB91C1C) : null),
                            ),
                          ]),
                          style: AppText.body(size: 12.5, color: AppSurface.muted(context)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (_loading && data == null && _error == null)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
                        )
                      else if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(child: MutedText(picking ? 'Pick a class or search for a child' : 'No children to show')),
                        )
                      else
                        for (final s in shown) _childCard(s),
                    ],
                  ),
                ),
                if (_canCollect && _myDay != null) ...[
                  const SizedBox(height: 14),
                  CounterSection(
                    title: 'My takings today',
                    child: TileGrid(
                      minWidth: 110,
                      children: [
                        TakingsTile(label: 'Cash', value: _money(_myDay!['cash'])),
                        TakingsTile(label: 'Mobile money', value: _money(_myDay!['mobile_money'])),
                        TakingsTile(label: 'Total', value: _money(_myDay!['total']), sub: plural(intOf(_myDay!['count']), 'payment')),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paidBanner(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${_money(p['amount'])} recorded for ${p['student'] ?? ''} · ${p['receipt_number'] ?? ''}',
            style: AppText.body(size: 13, weight: FontWeight.w600, color: const Color(0xFF166534)),
          ),
          ReceiptButton(
            paymentId: '${p['id'] ?? ''}',
            receiptNumber: '${p['receipt_number'] ?? ''}',
            label: 'View receipt',
            primary: true,
          ),
          OutlinedButton(
            onPressed: () => setState(() => _justPaid = null),
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _statePill(Map<String, dynamic> s) {
    if (s['boarder'] == true) return const FeedBadge('Boarder');
    if (s['rate'] == null) return const FeedBadge('No rate');
    return switch ('${s['state']}') {
      'covered' => FeedBadge('Covered · until ${dayLabel(s['covered_until'])}', tone: 'green'),
      'unpaid_present' => const FeedBadge('Not paid · present', tone: 'red'),
      _ => const FeedBadge('Not paid', tone: 'amber'),
    };
  }

  Widget _childCard(Map<String, dynamic> s) {
    final inHand = intOf(s['days_in_hand']);
    final unpaid = intOf(s['unpaid_days']);
    final meta = [
      textOf(s['admission_number']),
      textOf(s['class_name']),
      if (s['rate'] != null && numOf(s['rate']) > 0) '${_money(s['rate'])} a day',
    ].whereType<String>().join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSurface.cardSoft(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['full_name'] ?? ''}', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.ink(context))),
                    if (meta.isNotEmpty) MutedText(meta, size: 12),
                  ],
                ),
              ),
              if (_canCollect && s['boarder'] != true && s['rate'] != null)
                FilledButton.icon(
                  onPressed: () => _record(s),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Record'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statePill(s),
              if (inHand > 0) MutedText('${plural(inHand, 'day')} paid ahead', size: 12),
              if (unpaid > 0)
                Text(
                  '${plural(unpaid, 'unpaid day')} · ${_money(s['unpaid_amount'])}',
                  style: AppText.body(size: 12, weight: FontWeight.w700, color: const Color(0xFFB91C1C)),
                ),
              if (numOf(s['change']) > 0) MutedText('${_money(s['change'])} change kept', size: 12),
            ],
          ),
        ],
      ),
    );
  }
}
