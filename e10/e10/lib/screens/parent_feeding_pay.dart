import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../feeding.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/feeding_widgets.dart';
import '../widgets/popups.dart';

/// A parent pays for feeding with mobile money — the same flow as school
/// fees: pick what to pay for, approve the MoMo prompt on the phone, and the
/// school records the payment with its reference and receipt by itself.
/// Returns true once the payment went through.
class FeedingPayForm extends StatefulWidget {
  const FeedingPayForm({super.key, required this.studentId, required this.status, required this.phone, required this.currency});

  final String studentId;

  /// The child's feeding status from `students/{id}/feeding/history`.
  final Map<String, dynamic> status;
  final String phone;
  final String currency;

  @override
  State<FeedingPayForm> createState() => _FeedingPayFormState();
}

enum _Stage { form, waiting, done }

class _FeedingPayFormState extends State<FeedingPayForm> {
  static const _networks = [('mtn_momo', 'MTN'), ('telecel_cash', 'Telecel'), ('airteltigo_money', 'AirtelTigo')];

  late final int _unpaid = intOf(widget.status['unpaid_days']);
  late String _option = _unpaid > 0 ? 'arrears' : 'today';
  String _mode = 'arrears_first';
  final _days = TextEditingController(text: '5');
  final _amount = TextEditingController();
  late final _wallet = TextEditingController(text: widget.phone);
  late String _provider = SchoolStore.momoProviderFor(widget.phone) ?? 'mtn_momo';

  _Stage _stage = _Stage.form;
  bool _starting = false;
  String? _error;
  Map<String, dynamic> _intent = const {};
  Timer? _poll;
  int _checks = 0;

  double get _rate => numOf(widget.status['rate']);
  double get _unpaidAmount => numOf(widget.status['unpaid_amount']);
  String _money(dynamic v) => money(v, widget.currency);

  /// What this will collect, worked out like the cashier's quote. The
  /// server has the final word and the prompt shows the exact amount.
  double get _estimate {
    final arrears = _unpaid > 0 && _mode == 'arrears_first' ? _unpaidAmount : 0.0;
    return switch (_option) {
      'arrears' => _unpaidAmount,
      'today' => arrears + _rate,
      'days' => arrears + _rate * (int.tryParse(_days.text) ?? 0),
      _ => double.tryParse(_amount.text) ?? 0,
    };
  }

  bool get _valid {
    if (_wallet.text.replaceAll(RegExp(r'\D'), '').length < 10) return false;
    return switch (_option) {
      'days' => (int.tryParse(_days.text) ?? 0) >= 1,
      'amount' => (double.tryParse(_amount.text) ?? 0) > 0,
      _ => true,
    };
  }

  @override
  void dispose() {
    _poll?.cancel();
    _days.dispose();
    _amount.dispose();
    _wallet.dispose();
    super.dispose();
  }

  bool _isSuccess(String s) => const {'successful', 'paid', 'completed', 'success'}.contains(s);
  bool _isFailed(String s) => const {'failed', 'cancelled', 'expired'}.contains(s);

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final intent = await FeedingApi.startParentFeedingPayment(
        studentId: widget.studentId,
        provider: _provider,
        payerPhone: _wallet.text.trim(),
        option: _option,
        mode: _option == 'arrears' ? 'arrears_first' : _mode,
        days: _option == 'days' ? int.tryParse(_days.text) : null,
        amount: _option == 'amount' ? double.tryParse(_amount.text) : null,
      );
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _stage = _Stage.waiting;
      });
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    } on ApiException catch (e) {
      if (e.status == 404 || e.status == 405) FeedingApi.resetPayAvailability();
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the payment. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _check() async {
    final id = '${_intent['id'] ?? ''}';
    if (id.isEmpty) return;
    _checks++;
    try {
      final now = await FeedingApi.paymentIntent(id);
      if (!mounted) return;
      final status = '${now['status'] ?? ''}';
      setState(() => _intent = {..._intent, ...now});
      if (_isSuccess(status) || _isFailed(status)) {
        _poll?.cancel();
        setState(() => _stage = _Stage.done);
      }
    } catch (_) {
      // A missed check is retried on the next tick.
    }
    if (_checks >= 60 && _stage == _Stage.waiting) {
      _poll?.cancel();
      if (mounted) setState(() => _stage = _Stage.done);
    }
  }

  Widget _choice(String value, String label, {String? sub, Widget? trailing}) {
    final on = _option == value;
    return InkWell(
      onTap: () => setState(() => _option = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: 20, color: on ? AppSurface.brand(context) : AppColors.slate400),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: AppText.body(size: 13.5, color: AppColors.slate800))),
            if (sub != null) ...[const SizedBox(width: 6), Text('· $sub', style: AppText.body(size: 13, color: AppColors.slate500))],
            if (trailing != null && on) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
        _Stage.form => _form(),
        _Stage.waiting => _waiting(),
        _Stage.done => _done(),
      };

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${_money(_rate)} a day'),
            if (_unpaid > 0)
              TextSpan(
                text: ' · ${plural(_unpaid, 'unpaid day')} (${_money(_unpaidAmount)})',
                style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
              ),
          ]),
          style: AppText.body(size: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 14),
        const AppFieldLabel('Paying for'),
        if (_unpaid > 0) _choice('arrears', 'Unpaid days only', sub: _money(_unpaidAmount)),
        _choice('today', 'Today', sub: _money(_rate)),
        _choice(
          'days',
          'Number of days',
          trailing: SizedBox(
            width: 70,
            child: TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              decoration: appFieldDecoration(context),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        _choice(
          'amount',
          'Any amount',
          trailing: SizedBox(
            width: 110,
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: appFieldDecoration(context, hint: widget.currency),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        if (_unpaid > 0 && _option != 'arrears') ...[
          const SizedBox(height: 10),
          const AppFieldLabel('Unpaid days'),
          SwitchListTile(
            value: _mode == 'arrears_first',
            onChanged: (on) => setState(() => _mode = on ? 'arrears_first' : 'ahead_only'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Pay unpaid days first'),
          ),
        ],
        const SizedBox(height: 10),
        const AppFieldLabel('Mobile money'),
        Wrap(
          spacing: 6,
          children: [
            for (final (value, label) in _networks)
              ChoiceChip(label: Text(label), selected: _provider == value, onSelected: (_) => setState(() => _provider = value)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _wallet,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
          decoration: appFieldDecoration(context, hint: 'Wallet number, e.g. 024 000 0000'),
          onChanged: (v) => setState(() => _provider = SchoolStore.momoProviderFor(v) ?? _provider),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(8)),
          child: Text(
            _estimate > 0 ? 'About ${_money(_estimate)} — the prompt on your phone shows the exact amount.' : 'Choose what to pay for.',
            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.slate700),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppText.body(size: 12.5, color: const Color(0xFFB91C1C))),
        ],
        const SizedBox(height: 14),
        AppModalButton(label: _starting ? 'Starting…' : 'Pay with mobile money', onPressed: _starting || !_valid ? null : _start),
      ],
    );
  }

  Widget _waiting() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3))),
          const SizedBox(height: 16),
          Text('Approve the payment on your phone', textAlign: TextAlign.center, style: AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.slate800)),
          const SizedBox(height: 6),
          Text(
            'A mobile money prompt for ${_money(_intent['amount'] ?? _estimate)} was sent to ${_wallet.text.trim()}. Enter your PIN there — this page updates by itself.',
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, color: AppColors.slate500),
          ),
          if (textOf(_intent['reference']) != null) ...[
            const SizedBox(height: 10),
            Text('Reference ${textOf(_intent['reference'])}', textAlign: TextAlign.center, style: AppText.body(size: 12.5, color: AppColors.slate600)),
          ],
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => closeRoute(context, false), child: const Text('Close — I’ll check later')),
        ],
      );

  Widget _done() {
    final status = '${_intent['status'] ?? ''}';
    final ok = _isSuccess(status);
    final reference = textOf(_intent['reference']);
    final receipt = textOf(_intent['receipt_number']);
    final paymentId = textOf(_intent['feeding_payment_id']) ?? textOf(_intent['payment_id']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 44, color: ok ? const Color(0xFF16A34A) : const Color(0xFFB91C1C)),
        const SizedBox(height: 10),
        Text(
          ok ? 'Feeding paid · ${_money(_intent['amount'] ?? _estimate)}' : (_isFailed(status) ? 'The payment didn’t go through' : 'Still waiting for the payment'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 16, weight: FontWeight.w800, color: AppColors.slate800),
        ),
        const SizedBox(height: 6),
        if (ok && textOf(_intent['covers']) != null)
          Text('Pays for ${textOf(_intent['covers'])}', textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppColors.slate600)),
        if (!ok && _isFailed(status))
          Text(textOf(_intent['failure_reason']) ?? 'Nothing was charged. You can try again.', textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppColors.slate600)),
        if (!ok && !_isFailed(status))
          Text('If you approved it, it will show on this page shortly.', textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppColors.slate600)),
        if (reference != null) ...[
          const SizedBox(height: 10),
          Text('Reference $reference', textAlign: TextAlign.center, style: AppText.body(size: 12.5, color: AppColors.slate600)),
        ],
        if (receipt != null) Text('Receipt $receipt', textAlign: TextAlign.center, style: AppText.body(size: 12.5, color: AppColors.slate600)),
        const SizedBox(height: 16),
        if (ok && paymentId != null) ...[
          Center(child: ReceiptButton(paymentId: paymentId, receiptNumber: receipt ?? '', label: 'View receipt', primary: true)),
          const SizedBox(height: 8),
        ],
        AppModalButton(label: 'Done', onPressed: () => closeRoute(context, ok)),
      ],
    );
  }
}
