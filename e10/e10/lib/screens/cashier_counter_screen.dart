import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../feeding.dart';
import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/dash_cards.dart';
import '../widgets/feeding_widgets.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart' show showSnack;

/// The cashier's home ("Counter"), as on the website: today's takings, find
/// a student to take school fees or feeding, who is present today without
/// feeding paid, and the cashier's own payments today. What shows depends on
/// the cashier's permissions and the school's plan, so it works the same for
/// every school.
class CashierCounterScreen extends StatefulWidget {
  const CashierCounterScreen({super.key, required this.user, required this.onNav, required this.onLogout});

  final AppUser user;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback onLogout;

  @override
  State<CashierCounterScreen> createState() => _CashierCounterScreenState();
}

class _CashierCounterScreenState extends State<CashierCounterScreen> {
  final _currency = schoolCurrency();
  final _search = TextEditingController();
  Map<String, dynamic>? _day;
  String? _dayError;
  List<Map<String, dynamic>> _matches = const [];
  bool _searching = false;
  Map<String, dynamic>? _student;
  bool _opening = false;
  int _weekDays = 5;
  int _monthDays = 20;
  Timer? _debounce;
  int _searchSeq = 0;

  bool get _canFees => FeedingAccess.collectFees(widget.user);
  bool get _canFeeding => FeedingAccess.collectFeeding(widget.user);
  String _money(dynamic v) => money(v, _currency);

  @override
  void initState() {
    super.initState();
    _loadDay();
    if (_canFeeding) {
      // `feeding/today` carries the school's week/month day counts
      // (`feeding/settings` only lists the feeding weekdays).
      FeedingApi.today().then((s) {
        if (!mounted) return;
        setState(() {
          _weekDays = intOf(s['week_days']) > 0 ? intOf(s['week_days']) : _weekDays;
          _monthDays = intOf(s['month_days']) > 0 ? intOf(s['month_days']) : _monthDays;
        });
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadDay() async {
    try {
      final day = await FeedingApi.cashierMyDay();
      if (!mounted) return;
      setState(() {
        _day = day;
        _dayError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _dayError = 'Could not load today’s takings. $e');
    }
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    final term = text.trim();
    if (term.length < 2) {
      setState(() {
        _matches = const [];
        _searching = false;
      });
      return;
    }
    final seq = ++_searchSeq;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final found = await FeedingApi.cashierStudents(term);
        if (mounted && seq == _searchSeq) setState(() => _matches = found);
      } catch (e) {
        if (mounted && seq == _searchSeq) showSnack(context, 'Could not search students. $e');
      } finally {
        if (mounted && seq == _searchSeq) setState(() => _searching = false);
      }
    });
  }

  Future<void> _open(String id) async {
    setState(() => _opening = true);
    try {
      final s = await FeedingApi.cashierStudent(id);
      if (mounted) setState(() => _student = s);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open this student. $e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _refresh() async {
    await _loadDay();
    final id = _student?['id'];
    if (id != null) await _open('$id');
  }

  Future<void> _takeFees() async {
    final s = _student;
    if (s == null) return;
    if (await showFeePaymentSheet(context, student: s, currency: _currency)) await _refresh();
  }

  Future<void> _takeFeeding(Map<String, dynamic> row) async {
    final done = await showFeedingPaymentSheet(
      context,
      student: row,
      weekDays: _weekDays,
      monthDays: _monthDays,
      currency: _currency,
    );
    if (done != null) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    return Column(
      children: [
        DashAccountHeader(
          user: widget.user,
          subtitle: 'Counter · ${store.brandedSchoolName}',
          onLogout: widget.onLogout,
          onTapSchool: () => widget.onNav(AppScreen.schoolProfile),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppLayout.page(context),
              children: [
                _todayCard(),
                const SizedBox(height: 14),
                _findCard(),
                if (_canFeeding && _day != null) ...[
                  const SizedBox(height: 14),
                  _notPaidCard(),
                ],
                const SizedBox(height: 14),
                _paymentsCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _loading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );

  Widget _todayCard() {
    final d = _day;
    Map<String, dynamic>? part(String key) => d?[key] is Map ? Map<String, dynamic>.from(d![key] as Map) : null;
    final fees = _canFees ? part('fees') : null;
    final feeding = _canFeeding ? part('feeding') : null;
    String sub(Map<String, dynamic> p) => '${plural(intOf(p['count']), 'payment')} · cash ${_money(p['cash'])}';
    return CounterSection(
      title: 'Today',
      action: SmallAction(label: 'Refresh', icon: Icons.refresh_rounded, onTap: _loadDay),
      child: d == null
          ? (_dayError != null ? MutedText(_dayError!) : _loading())
          : TileGrid(
              minWidth: 170,
              children: [
                if (fees != null)
                  TakingsTile(
                      label: 'School fees', icon: Icons.account_balance_wallet_outlined, value: _money(fees['total']), sub: sub(fees)),
                if (feeding != null)
                  TakingsTile(label: 'Feeding', icon: Icons.restaurant_rounded, value: _money(feeding['total']), sub: sub(feeding)),
                TakingsTile(
                  label: 'Cash to hand over',
                  icon: Icons.payments_outlined,
                  value: _money(d['cash_to_hand_over']),
                  sub: 'Give this to the bursar at the end of the day',
                ),
              ],
            ),
    );
  }

  Widget _findCard() {
    final term = _search.text.trim();
    return CounterSection(
      title: 'Find a student',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: appFieldDecoration(context, hint: 'Name or admission number').copyWith(
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: term.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _search.clear();
                        _onSearch('');
                      },
                    ),
            ),
          ),
          if (_searching) const Padding(padding: EdgeInsets.only(top: 8), child: MutedText('Searching…')),
          if (term.length >= 2 && !_searching && _matches.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: MutedText('No student matches “$term”.')),
          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final m in _matches) _matchRow(m),
          ],
          if (_opening) _loading(),
          if (_student != null && !_opening) _studentPanel(_student!),
        ],
      ),
    );
  }

  Widget _matchRow(Map<String, dynamic> m) {
    final selected = '${_student?['id']}' == '${m['id']}';
    final owing = m['owing'];
    final meta = [textOf(m['admission_number']), textOf(m['class_name'])].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppSurface.brand(context).withValues(alpha: 0.08) : AppSurface.cardSoft(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _open('${m['id']}'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: selected ? AppSurface.brand(context) : AppSurface.line(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m['full_name'] ?? ''}',
                          style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.ink(context))),
                      if (meta.isNotEmpty) MutedText(meta, size: 12),
                    ],
                  ),
                ),
                if (owing != null)
                  numOf(owing) > 0
                      ? Text('Owes ${_money(owing)}',
                          style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context)))
                      : const MutedText('Fees paid', size: 12.5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
      );

  Widget _studentPanel(Map<String, dynamic> s) {
    final fees = s['fees'] is Map ? Map<String, dynamic>.from(s['fees'] as Map) : null;
    final feeding = s['feeding'] is Map ? Map<String, dynamic>.from(s['feeding'] as Map) : null;
    final owing = numOf(fees?['owing']);
    final guardians = FeedingApi.rows(s['guardians']);
    final bills = FeedingApi.rows(fees?['bills']);
    final meta = [textOf(s['admission_number']), textOf(s['class_name'])].whereType<String>().join(' · ');
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppSurface.line(context)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${s['full_name'] ?? ''}', style: AppText.display(size: 18, weight: FontWeight.w700, color: AppSurface.ink(context))),
          MutedText(meta.isEmpty ? '—' : meta),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_canFees && fees != null)
                FilledButton.icon(
                  onPressed: owing <= 0 ? null : _takeFees,
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                  label: const Text('Take school fees'),
                ),
              if (_canFeeding && feeding != null && feeding['rate'] != null && feeding['boarder'] != true)
                OutlinedButton.icon(
                  onPressed: () => _takeFeeding(feeding),
                  icon: const Icon(Icons.restaurant_rounded, size: 16),
                  label: const Text('Take feeding'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Parents / guardians'),
          if (guardians.isEmpty)
            const MutedText('None on record.')
          else
            for (final g in guardians)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${g['full_name'] ?? ''}',
                        style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context))),
                    if (textOf(g['relationship']) != null) MutedText(textOf(g['relationship'])!),
                    if (textOf(g['phone']) != null)
                      InkWell(
                        onTap: () => launchUrl(Uri(scheme: 'tel', path: textOf(g['phone']))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_rounded, size: 13, color: AppSurface.brand(context)),
                            const SizedBox(width: 3),
                            Text(textOf(g['phone'])!, style: AppText.body(size: 13, color: AppSurface.brand(context))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          if (_canFees && fees != null) ...[
            const SizedBox(height: 14),
            _label('School fees · owes ${_money(fees['owing'])}'),
            if (bills.isEmpty)
              const MutedText('Nothing owed.')
            else
              for (final b in bills) _billRow(b),
          ],
          if (_canFeeding && feeding != null) ...[
            const SizedBox(height: 14),
            _label('Feeding'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...feedingStatusPills(feeding, _currency),
                if (feeding['boarder'] != true && feeding['rate'] != null) MutedText('${_money(feeding['rate'])} a day'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _billRow(Map<String, dynamic> b) {
    final due = textOf(b['due_date']);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppSurface.cardSoft(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${b['title'] ?? 'Bill'}', style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context))),
                MutedText(
                  [textOf(b['term']), if (due != null) 'Due ${dayLabel(due)}', 'Total ${_money(b['total'])} · paid ${_money(b['paid'])}']
                      .whereType<String>()
                      .join(' · '),
                  size: 12,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_money(b['balance']), style: AppText.body(size: 13.5, weight: FontWeight.w800, color: AppSurface.ink(context))),
        ],
      ),
    );
  }

  Widget _notPaidCard() {
    final rows = FeedingApi.rows(_day?['not_paid_feeding']);
    return CounterSection(
      title: 'Present today, not paid for feeding',
      action: SmallAction(label: 'Feeding today', icon: Icons.restaurant_rounded, onTap: () => widget.onNav(AppScreen.feedingToday)),
      child: rows.isEmpty
          ? const MutedText('Nobody — everyone present today is covered, or attendance isn’t in yet.')
          : Column(
              children: [
                for (final r in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: AppSurface.cardSoft(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppSurface.line(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r['full_name'] ?? ''}',
                                  style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context))),
                              MutedText(
                                [
                                  textOf(r['class_name']) ?? '—',
                                  if (intOf(r['unpaid_days']) > 0)
                                    '${plural(intOf(r['unpaid_days']), 'unpaid day')} · ${_money(r['unpaid_amount'])}',
                                  '${_money(r['rate'])}/day',
                                ].join(' · '),
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _takeFeeding(r),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('Take feeding'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _paymentsCard() {
    final d = _day;
    final payments = FeedingApi.rows(d?['payments']);
    return CounterSection(
      title: 'My payments today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (d == null)
            _dayError != null ? const MutedText('—') : _loading()
          else if (payments.isEmpty)
            const MutedText('Nothing recorded yet today.')
          else
            for (final p in payments) _paymentRow(p),
          const SizedBox(height: 8),
          const MutedText('Made a mistake? Ask the bursar — only they can change or cancel a payment.', size: 12),
        ],
      ),
    );
  }

  Widget _paymentRow(Map<String, dynamic> p) {
    final fees = p['kind'] == 'fees';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppSurface.cardSoft(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        textOf(p['student']) ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FeedBadge(fees ? 'School fees' : 'Feeding', tone: fees ? 'blue' : 'green'),
                  ],
                ),
                const SizedBox(height: 2),
                MutedText('${timeLabel(p['paid_at'])} · ${methodLabel(p['method'])} · ${p['receipt_number'] ?? ''}', size: 12),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(p['amount']), style: AppText.body(size: 14, weight: FontWeight.w800, color: AppSurface.ink(context))),
              if (textOf(p['receipt_url']) != null)
                ReceiptButton(
                  paymentId: '${p['id'] ?? ''}',
                  url: textOf(p['receipt_url']),
                  receiptNumber: '${p['receipt_number'] ?? ''}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
