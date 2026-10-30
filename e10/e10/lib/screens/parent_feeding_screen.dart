import 'package:flutter/material.dart';

import '../feeding.dart';
import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/feeding_widgets.dart';
import '../widgets/popups.dart';
import 'parent_feeding_pay.dart';

/// A parent's view of their child's feeding: paid-until status, the days
/// fed this month and the feeding payments (with receipts), like the
/// website's parent "Feeding" page.
class ParentFeedingScreen extends StatefulWidget {
  const ParentFeedingScreen({super.key, required this.user, this.onBack, required this.onLogout});

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<ParentFeedingScreen> createState() => _ParentFeedingScreenState();
}

class _ParentFeedingScreenState extends State<ParentFeedingScreen> {
  static const _dayStatus = {
    'covered': ('Fed · paid ahead', 'green'),
    'paid': ('Fed · paid later', 'blue'),
    'unpaid': ('Fed · not paid', 'red'),
  };

  final _currency = schoolCurrency();
  String _month = monthKey(DateTime.now());
  String _childId = '';
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;
  int _seq = 0;

  /// Whether the school's server takes feeding payments online.
  bool _canPay = false;

  String _money(dynamic v) => money(v, _currency);

  Future<void> _pay(Map<String, dynamic> status) async {
    final child = SchoolScope.of(context).linkedChildren(Role.parent).where((k) => k.id == _childId).firstOrNull;
    final paid = await showAppSheet<bool>(
      context: context,
      title: 'Pay for feeding',
      subtitle: child?.name,
      builder: (_) => FeedingPayForm(studentId: _childId, status: status, phone: widget.user.phone, currency: _currency),
    );
    if (paid == true) await _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_childId.isEmpty) {
      final child = SchoolScope.of(context).focusedChild(Role.parent);
      if (child != null) {
        _childId = child.id;
        _load();
      }
    }
  }

  Future<void> _load() async {
    if (_childId.isEmpty) return;
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await FeedingApi.studentFeedingHistory(_childId, _month);
      if (mounted && seq == _seq) setState(() => _data = data);
      final canPay = await FeedingApi.parentPayAvailable(_childId);
      if (mounted && seq == _seq) setState(() => _canPay = canPay);
    } catch (e) {
      if (mounted && seq == _seq) {
        setState(() {
          _data = null;
          _error = 'Could not load feeding. $e';
        });
      }
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final kids = store.linkedChildren(Role.parent);
    final data = _data;
    final status = data?['status'] is Map ? Map<String, dynamic>.from(data!['status'] as Map) : null;
    final days = FeedingApi.rows(data?['days']);
    final payments = FeedingApi.rows(data?['payments']);
    final totals = data?['totals'] is Map ? Map<String, dynamic>.from(data!['totals'] as Map) : const <String, dynamic>{};
    final firstMonth = textOf(data?['first_month']);
    final thisMonth = monthKey(DateTime.now());
    return Column(
      children: [
        AdminPageHeader(
          title: 'Feeding',
          subtitle: store.brandedSchoolName,
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
                if (kids.isEmpty)
                  const WhiteCard(
                    padding: EdgeInsets.all(16),
                    child: MutedText('No children are linked to your account yet.'),
                  )
                else ...[
                  WhiteCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (kids.length > 1)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final k in kids)
                                ChoiceChip(
                                  label: Text(k.name),
                                  selected: k.id == _childId,
                                  onSelected: (_) {
                                    setState(() {
                                      _childId = k.id;
                                      _data = null;
                                    });
                                    _load();
                                  },
                                ),
                            ],
                          )
                        else
                          Text(kids.first.name, style: AppText.display(size: 18, weight: FontWeight.w700, color: AppSurface.ink(context))),
                        if (status != null && status['set_up'] == true) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (textOf(status['covered_until']) != null)
                                FeedBadge('Covered until ${dayLabel(status['covered_until'])}', tone: 'green')
                              else if (intOf(status['unpaid_days']) == 0)
                                const FeedBadge('Not paid ahead'),
                              if (intOf(status['unpaid_days']) > 0)
                                FeedBadge(
                                  '${plural(intOf(status['unpaid_days']), 'unpaid day')} · ${_money(status['unpaid_amount'])}',
                                  tone: 'red',
                                ),
                            ],
                          ),
                          if (status['rate'] != null) ...[
                            const SizedBox(height: 6),
                            MutedText(
                              _canPay
                                  ? '${_money(status['rate'])} a day. Pay here with mobile money, or at the school’s cashier.'
                                  : '${_money(status['rate'])} a day, paid to the school’s cashier.',
                              size: 12,
                            ),
                            if (_canPay && status['boarder'] != true) ...[
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => _pay(status),
                                icon: const Icon(Icons.phone_iphone_rounded, size: 18),
                                label: const Text('Pay for feeding'),
                              ),
                            ],
                          ],
                        ],
                        if (status != null && status['set_up'] != true) ...[
                          const SizedBox(height: 8),
                          const MutedText('Feeding isn’t charged for this child.', size: 12.5),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    MutedText(_error!),
                  ],
                  const SizedBox(height: 14),
                  CounterSection(
                    title: 'Feeding days',
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          visualDensity: VisualDensity.compact,
                          onPressed: data == null || (firstMonth != null && _month.compareTo(firstMonth) <= 0)
                              ? null
                              : () {
                                  setState(() => _month = shiftMonth(_month, -1));
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text(monthLabel(_month), style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
                        IconButton(
                          tooltip: 'Next month',
                          visualDensity: VisualDensity.compact,
                          onPressed: _month.compareTo(thisMonth) >= 0
                              ? null
                              : () {
                                  setState(() => _month = shiftMonth(_month, 1));
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (data != null && days.isEmpty) const MutedText('No feeding days recorded this month.'),
                              if (days.isNotEmpty) ...[
                                Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: '${plural(intOf(totals['eaten']), 'day')} fed'),
                                    if (intOf(totals['unpaid']) > 0)
                                      TextSpan(
                                        text: ' · ${plural(intOf(totals['unpaid']), 'day')} not paid (${_money(totals['unpaid_amount'])})',
                                        style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                                      ),
                                  ]),
                                  style: AppText.body(size: 12.5, color: AppSurface.muted(context)),
                                ),
                                const SizedBox(height: 6),
                                for (final d in days)
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppSurface.line(context)))),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(dayLabel(d['date']), style: AppText.body(size: 13.5, color: AppSurface.ink(context))),
                                        ),
                                        FeedBadge(
                                          _dayStatus['${d['status']}']?.$1 ?? '${d['status'] ?? ''}',
                                          tone: _dayStatus['${d['status']}']?.$2 ?? 'gray',
                                        ),
                                        SizedBox(
                                          width: 86,
                                          child: Text(_money(d['rate']),
                                              textAlign: TextAlign.right,
                                              style: AppText.body(size: 12.5, color: AppSurface.muted(context))),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 8),
                              const MutedText('Only days your child was at school on a feeding day are listed. Absent days use nothing.',
                                  size: 12),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  CounterSection(
                    title: 'Payments',
                    child: _loading
                        ? const SizedBox.shrink()
                        : payments.isEmpty
                            ? const MutedText('No feeding payments yet.')
                            : Column(children: [for (final p in payments) _payment(p)]),
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

  Widget _payment(Map<String, dynamic> p) {
    final voided = p['voided'] == true;
    return Opacity(
      opacity: voided ? 0.65 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppSurface.line(context)))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _money(p['amount']),
                    style: AppText.body(size: 14, weight: FontWeight.w800, color: AppSurface.ink(context)).copyWith(
                      decoration: voided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                MutedText(stampLabel(p['paid_at']), size: 12),
              ],
            ),
            const SizedBox(height: 2),
            MutedText(
              'For ${p['paid_for'] ?? ''} · ${p['method'] == 'mobile_money' ? 'Mobile money' : 'Cash'} · ${p['receipt_number'] ?? ''}',
              size: 12.5,
            ),
            if (voided) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  const FeedBadge('Cancelled'),
                  if (textOf(p['void_reason']) != null) MutedText(textOf(p['void_reason'])!, size: 12)
                ],
              ),
            ],
            const SizedBox(height: 6),
            ReceiptButton(paymentId: '${p['id'] ?? ''}', receiptNumber: '${p['receipt_number'] ?? ''}'),
          ],
        ),
      ),
    );
  }
}
