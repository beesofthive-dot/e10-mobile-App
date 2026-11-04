import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/receipt_file.dart';
import '../feeding.dart';
import '../screens/admin_forms.dart' show showSnack;
import '../theme.dart';
import 'common.dart';
import 'popups.dart';

/// A small coloured pill (green / red / amber / blue / gray), like the
/// website's badges.
class FeedBadge extends StatelessWidget {
  const FeedBadge(this.text, {super.key, this.tone = 'gray'});

  final String text;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      'green' => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
      'red' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
      'amber' => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      'blue' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      _ => (AppColors.slate100, AppColors.slate600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: AppText.body(size: 11.5, weight: FontWeight.w700, color: fg)),
    );
  }
}

/// A titled card section with an optional action at the top right.
class CounterSection extends StatelessWidget {
  const CounterSection({super.key, required this.title, this.action, required this.child});

  final String title;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppText.display(size: 17, weight: FontWeight.w700, color: AppSurface.ink(context))),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A compact outlined button for section headers ("Refresh", "Feeding today").
class SmallAction extends StatelessWidget {
  const SmallAction({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        textStyle: AppText.body(size: 12, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }
}

class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key, this.size = 13});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.body(size: size, color: AppSurface.muted(context)));
}

/// A stat box: label, big amount, small line under it.
class TakingsTile extends StatelessWidget {
  const TakingsTile({super.key, required this.label, required this.value, this.sub, this.icon, this.valueColor});

  final String label;
  final String value;
  final String? sub;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppSurface.cardSoft(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppSurface.muted(context)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: AppSurface.muted(context))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Big amounts shrink to fit rather than losing their last digits.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: AppText.display(size: 19, weight: FontWeight.w800, color: valueColor ?? AppSurface.ink(context))),
          ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(sub!, style: AppText.body(size: 11, color: AppSurface.muted(context))),
          ],
        ],
      ),
    );
  }
}

/// Lays tiles out two (or more on wide screens) to a row.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.minWidth = 150});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final perRow = (box.maxWidth / minWidth).floor().clamp(1, 4);
      final width = (box.maxWidth - (perRow - 1) * 10) / perRow;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final c in children) SizedBox(width: width, child: c)],
      );
    });
  }
}

/// Opens a payment's PDF receipt (fees: the server's `receipt_url`;
/// feeding: `/feeding-payments/{id}/receipt`).
class ReceiptButton extends StatefulWidget {
  const ReceiptButton({
    super.key,
    this.paymentId = '',
    this.url,
    required this.receiptNumber,
    this.label = 'Receipt',
    this.primary = false,
  });

  final String paymentId;
  final String? url;
  final String receiptNumber;
  final String label;
  final bool primary;

  @override
  State<ReceiptButton> createState() => _ReceiptButtonState();
}

class _ReceiptButtonState extends State<ReceiptButton> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final bytes = await FeedingApi.receipt(url: widget.url, paymentId: widget.paymentId);
      await openPdfBytes(bytes, widget.receiptNumber.isEmpty ? 'receipt' : widget.receiptNumber);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the receipt. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _busy ? 'Opening…' : widget.label;
    const icon = Icon(Icons.receipt_long_rounded, size: 14);
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
      textStyle: WidgetStatePropertyAll(AppText.body(size: 12, weight: FontWeight.w600)),
    );
    return widget.primary
        ? FilledButton.icon(onPressed: _busy ? null : _open, icon: icon, label: Text(label), style: style)
        : OutlinedButton.icon(onPressed: _busy ? null : _open, icon: icon, label: Text(label), style: style);
  }
}

/// The feeding status pills for one child (Feeding today rows and the
/// counter's student card).
List<Widget> feedingStatusPills(Map<String, dynamic> s, String currency) {
  if (s['boarder'] == true) return const [FeedBadge('Boarder — not charged')];
  if (s['rate'] == null) return const [FeedBadge('No feeding rate for this class')];
  final unpaid = intOf(s['unpaid_days']);
  final coveredUntil = textOf(s['covered_until']);
  final state = '${s['state'] ?? ''}';
  return [
    if (coveredUntil != null)
      FeedBadge('Covered until ${dayLabel(coveredUntil)}', tone: 'green')
    else if (state == 'unpaid_present' || s['present_today'] == true)
      const FeedBadge('Present today, not paid', tone: 'red')
    else
      const FeedBadge('No days paid ahead', tone: 'amber'),
    if (unpaid > 0) FeedBadge('${plural(unpaid, 'unpaid day')} · ${money(s['unpaid_amount'], currency)}', tone: 'red'),
  ];
}

InputDecoration _field(BuildContext context, {String? hint, String? prefix}) =>
    appFieldDecoration(context, hint: hint).copyWith(prefixText: prefix);

Widget _choice<T>({
  required BuildContext context,
  required T value,
  required T group,
  required ValueChanged<T> onChanged,
  required String label,
  String? sub,
  Widget? trailing,
}) {
  return InkWell(
    onTap: () => onChanged(value),
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              value == group ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: value == group ? AppSurface.brand(context) : AppColors.slate400,
            ),
          ),
          Flexible(child: Text(label, style: AppText.body(size: 13.5, color: AppColors.slate800))),
          if (sub != null && sub.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text('· $sub', style: AppText.body(size: 13, color: AppColors.slate500)),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    ),
  );
}

/// Record a feeding payment for one child (a row from `feeding/today` or
/// the counter's `feeding` block). Returns `{status, payment}` once saved.
Future<Map<String, dynamic>?> showFeedingPaymentSheet(
  BuildContext context, {
  required Map<String, dynamic> student,
  required int weekDays,
  required int monthDays,
  required String currency,
}) {
  return showAppSheet<Map<String, dynamic>>(
    context: context,
    title: 'Record feeding',
    subtitle: '${student['full_name'] ?? ''}',
    builder: (_) => _FeedingPaymentForm(student: student, weekDays: weekDays, monthDays: monthDays, currency: currency),
  );
}

class _FeedingPaymentForm extends StatefulWidget {
  const _FeedingPaymentForm({required this.student, required this.weekDays, required this.monthDays, required this.currency});

  final Map<String, dynamic> student;
  final int weekDays;
  final int monthDays;
  final String currency;

  @override
  State<_FeedingPaymentForm> createState() => _FeedingPaymentFormState();
}

class _FeedingPaymentFormState extends State<_FeedingPaymentForm> {
  String _option = 'today';
  late String _mode = intOf(widget.student['unpaid_days']) > 0 ? 'arrears_first' : 'ahead_only';
  String _method = 'cash';
  final _days = TextEditingController(text: '3');
  final _amount = TextEditingController();
  Map<String, dynamic>? _quote;
  bool _saving = false;
  Timer? _debounce;
  int _quoteSeq = 0;

  Map<String, dynamic> get _s => widget.student;
  String _money(dynamic v) => money(v, widget.currency);

  bool get _ready => _option == 'days'
      ? (int.tryParse(_days.text) ?? 0) >= 1
      : _option != 'amount' || (double.tryParse(_amount.text) ?? 0) > 0;

  Map<String, dynamic> get _body => {
        'student_id': _s['student_id'] ?? _s['id'],
        'option': _option,
        'mode': _mode,
        'method': _method,
        if (_option == 'days') 'days': int.tryParse(_days.text) ?? 0,
        if (_option == 'amount') 'amount': double.tryParse(_amount.text) ?? 0,
      };

  @override
  void initState() {
    super.initState();
    _requote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _days.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Asks the server what this would collect and cover (nothing is saved).
  void _requote() {
    _debounce?.cancel();
    if (!_ready) {
      setState(() => _quote = null);
      return;
    }
    final seq = ++_quoteSeq;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final q = await FeedingApi.quote(_body);
        if (mounted && seq == _quoteSeq) setState(() => _quote = q);
      } catch (_) {
        if (mounted && seq == _quoteSeq) setState(() => _quote = null);
      }
    });
  }

  void _set(VoidCallback change) {
    setState(change);
    _requote();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await FeedingApi.recordFeedingPayment(_body);
      final payment = FeedingApi.rows([result['payment']]).firstOrNull ?? const {};
      if (!mounted) return;
      showSnack(context, 'Recorded ${_money(payment['amount'])} · receipt ${payment['receipt_number'] ?? ''}');
      closeRoute(context, result);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not record the payment. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _quoteLine(Map<String, dynamic> q) {
    final arrears = intOf(q['arrears_days']);
    final ahead = intOf(q['ahead_days']);
    final covers = arrears > 0 || ahead > 0 ? textOf(q['covers']) : null;
    final before = numOf(q['change_before']);
    final after = numOf(q['change_after']);
    final left = intOf(q['unpaid_left']);
    return [
      covers != null ? 'Pays for $covers' : 'Too little for a day — kept as change',
      if (after > 0) '${_money(after)} kept as change',
      if (before > 0 && after < before) 'uses ${_money(before - after)} change',
      if (left > 0) '${plural(left, 'unpaid day')} still owed',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final rate = numOf(_s['rate']);
    final unpaid = intOf(_s['unpaid_days']);
    final options = [
      ('today', 'Today', _money(rate)),
      ('week', 'A week (${widget.weekDays} days)', _money(_s['week_price'] ?? rate * widget.weekDays)),
      ('month', 'This month (${widget.monthDays} days)', _money(_s['month_price'] ?? rate * widget.monthDays)),
      ('days', 'Number of days', ''),
      ('amount', 'Any amount', ''),
    ];
    final q = _quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${textOf(_s['class_name']) ?? 'No class'} · ${_money(rate)} a day'),
            if (unpaid > 0)
              TextSpan(
                text: ' · ${plural(unpaid, 'unpaid day')} (${_money(_s['unpaid_amount'])})',
                style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
              ),
            if (numOf(_s['change']) > 0) TextSpan(text: ' · ${_money(_s['change'])} change kept'),
          ]),
          style: AppText.body(size: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 14),
        const AppFieldLabel('Paying for'),
        for (final (value, label, sub) in options)
          _choice<String>(
            context: context,
            value: value,
            group: _option,
            onChanged: (v) => _set(() => _option = v),
            label: label,
            sub: sub,
            trailing: value == 'days' && _option == 'days'
                ? SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _days,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                      decoration: _field(context),
                      onChanged: (_) => _set(() {}),
                    ),
                  )
                : value == 'amount' && _option == 'amount'
                    ? SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _amount,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          decoration: _field(context, hint: widget.currency),
                          onChanged: (_) => _set(() {}),
                        ),
                      )
                    : null,
          ),
        if (unpaid > 0) ...[
          const SizedBox(height: 10),
          const AppFieldLabel('Unpaid days'),
          _choice<String>(
            context: context,
            value: 'arrears_first',
            group: _mode,
            onChanged: (v) => _set(() => _mode = v),
            label: 'Pay unpaid days first',
          ),
          _choice<String>(
            context: context,
            value: 'ahead_only',
            group: _mode,
            onChanged: (v) => _set(() => _mode = v),
            label: 'Only for today and ahead (unpaid days stay owed)',
          ),
        ],
        const SizedBox(height: 10),
        const AppFieldLabel('Paid by'),
        Wrap(
          spacing: 12,
          children: [
            _choice<String>(context: context, value: 'cash', group: _method, onChanged: (v) => _set(() => _method = v), label: 'Cash'),
            _choice<String>(
              context: context,
              value: 'mobile_money',
              group: _method,
              onChanged: (v) => _set(() => _method = v),
              label: 'Mobile money',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(8)),
          child: q != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_option == 'amount' ? 'Received' : 'Collect'} ${_money(q['amount'])}',
                      style: AppText.body(size: 16, weight: FontWeight.w800, color: AppColors.slate800),
                    ),
                    const SizedBox(height: 3),
                    Text(_quoteLine(q), style: AppText.body(size: 12.5, color: AppColors.slate500)),
                  ],
                )
              : Text(
                  _ready
                      ? 'Working it out…'
                      : _option == 'amount'
                          ? 'Enter the amount received'
                          : 'Enter the number of days',
                  style: AppText.body(size: 13, color: AppColors.slate500),
                ),
        ),
        const SizedBox(height: 16),
        AppModalButton(label: _saving ? 'Recording…' : 'Record payment', onPressed: _saving || q == null ? null : _save),
      ],
    );
  }
}

/// Take a school-fees payment at the counter for a student from
/// `cashier/students/{id}`. Returns true once a payment was recorded.
Future<bool> showFeePaymentSheet(BuildContext context, {required Map<String, dynamic> student, required String currency}) async {
  final done = await showAppSheet<bool>(
    context: context,
    title: 'School fees',
    subtitle: '${student['full_name'] ?? ''}',
    builder: (_) => _FeePaymentForm(student: student, currency: currency),
  );
  return done == true;
}

class _FeePaymentForm extends StatefulWidget {
  const _FeePaymentForm({required this.student, required this.currency});

  final Map<String, dynamic> student;
  final String currency;

  @override
  State<_FeePaymentForm> createState() => _FeePaymentFormState();
}

class _FeePaymentFormState extends State<_FeePaymentForm> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late final _paidBy = TextEditingController(
    text: '${FeedingApi.rows(widget.student['guardians']).firstOrNull?['full_name'] ?? ''}',
  );
  String _method = 'cash';
  bool _saving = false;
  Map<String, dynamic>? _done;

  double get _owing => numOf((widget.student['fees'] as Map?)?['owing']);
  double get _value => double.tryParse(_amount.text) ?? 0;
  bool get _tooMuch => _value - _owing > 0.009;
  bool get _momo => _method != 'cash';
  bool get _valid => _value > 0 && !_tooMuch && (!_momo || _reference.text.trim().isNotEmpty);
  String _money(dynamic v) => money(v, widget.currency);

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _paidBy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await FeedingApi.recordFeePayment({
        'student_id': widget.student['id'],
        'amount': _value,
        'method': _method,
        if (_momo) 'reference': _reference.text.trim(),
        if (_paidBy.text.trim().isNotEmpty) 'paid_by': _paidBy.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Recorded ${_money(result['amount'])} · receipt ${result['receipt_number'] ?? ''}');
      setState(() => _done = result);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not record the payment. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Payment recorded · ${_money(done['amount'])} (${methodLabel(done['method'])})',
            style: AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.slate800),
          ),
          const SizedBox(height: 4),
          Text('Receipt ${done['receipt_number'] ?? ''}', style: AppText.body(size: 13, color: AppColors.slate600)),
          const SizedBox(height: 8),
          for (final a in FeedingApi.rows(done['allocations']))
            Text('${textOf(a['bill_title']) ?? 'Bill'}: ${_money(a['amount'])}', style: AppText.body(size: 13, color: AppColors.slate600)),
          const SizedBox(height: 4),
          Text('Still owes ${_money(done['owing_after'])}.', style: AppText.body(size: 13, color: AppColors.slate500)),
          const SizedBox(height: 16),
          Row(
            children: [
              ReceiptButton(
                paymentId: '${done['id'] ?? ''}',
                url: textOf(done['receipt_url']),
                receiptNumber: '${done['receipt_number'] ?? ''}',
                label: 'Print receipt',
                primary: true,
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => closeRoute(context, true), child: const Text('Done')),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Owes '),
            TextSpan(text: _money(_owing), style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: '. The money pays the oldest bill first.'),
          ]),
          style: AppText.body(size: 13.5, color: AppColors.slate700),
        ),
        const SizedBox(height: 14),
        AppFieldLabel('Amount received (${widget.currency})', required: true),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          decoration: _field(context),
          onChanged: (_) => setState(() {}),
        ),
        if (_tooMuch)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('That’s more than the ${_money(_owing)} owed.', style: AppText.body(size: 12, color: const Color(0xFFB91C1C))),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _amount.text = _owing.toStringAsFixed(2)),
            child: const Text('Pay it all'),
          ),
        ),
        const SizedBox(height: 4),
        const AppFieldLabel('How it was paid', required: true),
        Wrap(
          spacing: 4,
          children: [
            for (final (value, label) in counterMethods)
              _choice<String>(context: context, value: value, group: _method, onChanged: (v) => setState(() => _method = v), label: label),
          ],
        ),
        if (_momo) ...[
          const SizedBox(height: 10),
          const AppFieldLabel('Mobile money transaction ID', required: true),
          TextField(
            controller: _reference,
            maxLength: 50,
            decoration: _field(context, hint: 'From the MoMo message'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 10),
        const AppFieldLabel('Paid by'),
        TextField(controller: _paidBy, maxLength: 150, decoration: _field(context, hint: 'Who handed it over')),
        Text(
          'Recorded for today. Only the bursar can change or cancel it afterwards.',
          style: AppText.body(size: 12, color: AppColors.slate500),
        ),
        const SizedBox(height: 16),
        AppModalButton(
          label: _saving ? 'Recording…' : 'Record ${_value > 0 ? _money(_value) : 'payment'}',
          onPressed: _saving || !_valid ? null : _save,
        ),
      ],
    );
  }
}
