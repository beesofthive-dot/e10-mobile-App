import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/popups.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/finance_ui.dart';
import 'admin_forms.dart';
import '../widgets/txn_tiles.dart';
import '../widgets/card_input.dart';

enum _PayView { account, bill, pay, result }

/// A parent's school fees for the focused child: balance, bills, payment
/// history and mobile-money payment. The school-wide Transactions dashboard
/// (filters, totals, charts) is staff-only and lives in the finance screen.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    required this.user,
    this.onBack,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  static const _networks = [
    ('mtn_momo', 'MTN'),
    ('telecel_cash', 'Telecel'),
    ('airteltigo_money', 'AirtelTigo'),
  ];

  String _provider = 'mtn_momo';
  String _payChoice = 'full';
  _PayView _view = _PayView.account;
  Invoice? _bill;
  BillLine? _feeLine;
  FeePaymentResult? _result;
  DateTime? _startedAt;
  Timer? _poll;
  Timer? _intentPoll;
  bool _showReceipt = false;
  bool _processing = false;
  final _wallet = TextEditingController();
  final _amount = TextEditingController();

  /// 'momo' or 'card'. Card details stay on this screen: they are never sent
  /// or stored (no card gateway is connected to the school system yet).
  String _payWith = 'momo';
  final _cardNumber = TextEditingController();
  final _cardExpiry = TextEditingController();
  final _cardCvv = TextEditingController();

  @override
  void initState() {
    super.initState();
    _wallet.text = widget.user.phone;
    _provider = SchoolStore.momoProviderFor(widget.user.phone) ?? 'mtn_momo';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final kid in _kids) {
        _store.refreshChildFees(kid.id);
      }
      _store.loadPaymentIntents();
    });
    _intentPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _store.refreshPendingIntents();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _intentPoll?.cancel();
    _wallet.dispose();
    _amount.dispose();
    _cardNumber.dispose();
    _cardExpiry.dispose();
    _cardCvv.dispose();
    super.dispose();
  }

  SchoolStore get _store => SchoolScope.of(context);

  List<Student> get _kids => _store.linkedChildren(widget.user.role);

  Student get _childRecord {
    return _store.focusedChild(widget.user.role) ??
        const Student(
          id: '',
          name: 'No linked child',
          klass: '',
          avatar: '',
          attendance: 0,
          fees: 0,
          outstanding: 0,
          status: '',
        );
  }

  void _back() {
    setState(() {
      if (_view == _PayView.result && _showReceipt) {
        _showReceipt = false;
        return;
      }
      switch (_view) {
        case _PayView.result:
          _stopPolling();
          _view = _PayView.account;
          _result = null;
          _bill = null;
          _feeLine = null;
        case _PayView.pay:
          _view = _bill == null ? _PayView.account : _PayView.bill;
        case _PayView.bill:
          _view = _PayView.account;
          _bill = null;
          _feeLine = null;
        case _PayView.account:
          widget.onBack?.call();
      }
    });
  }

  Future<void> _openBill(Invoice bill) async {
    setState(() {
      _bill = bill;
      _view = _PayView.bill;
      _feeLine = null;
      _payChoice = 'full';
    });
    final fresh = await _store.loadBillDetail(bill.id);
    if (!mounted || fresh == null) return;
    setState(() => _bill = fresh);
  }

  /// Opens the pay form for the open bill (or one of its fees), or for the
  /// child's whole outstanding balance when no bill is open.
  void _startPay({BillLine? fee}) {
    final due = _dueNow;
    if (due <= 0.009) return;
    setState(() {
      _feeLine = fee;
      _payChoice = fee != null ? 'fee' : 'full';
      _amount.text = (fee != null ? (fee.amount < due ? fee.amount : due) : due).toStringAsFixed(2);
      _view = _PayView.pay;
    });
  }

  void _payBalance() {
    setState(() => _bill = null);
    _startPay();
  }

  /// What the parent can pay right now: the open bill's balance, capped by
  /// the child's total outstanding (the payment goes against that balance).
  double get _dueNow {
    final balance = _store.studentFinance(_childRecord.id).balance;
    final bill = _bill;
    if (bill == null) return balance;
    return bill.dueAmount < balance ? bill.dueAmount : balance;
  }

  double get _payAmount {
    final due = _dueNow;
    if (_payChoice == 'full') return due;
    if (_payChoice == 'fee' && _feeLine != null) {
      return _feeLine!.amount < due ? _feeLine!.amount : due;
    }
    return double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
  }

  Future<void> _pay() async {
    final child = _childRecord;
    final phone = _wallet.text.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').length < 9) {
      _toast('Enter a valid mobile money number.');
      return;
    }
    final amount = _payAmount;
    final due = _dueNow;
    if (amount <= 0 || amount - due > 0.009) {
      _toast('Enter an amount up to GHS ${due.toStringAsFixed(2)}.');
      return;
    }
    setState(() => _processing = true);
    final result = await _store.startParentPayment(
      studentId: child.id,
      studentName: child.name,
      amount: amount,
      provider: _provider,
      payerPhone: phone,
      parentName: widget.user.displayName,
      feeLabel: _feeLine?.label ?? _bill?.description ?? '',
    );
    if (!mounted) return;
    setState(() {
      _processing = false;
      if (result.ok) {
        _result = result;
        _showReceipt = false;
        _startedAt = DateTime.now();
        _view = _PayView.result;
      }
    });
    if (!result.ok) {
      _toast(result.error);
      return;
    }
    _schedulePoll();
  }

  /// Checks the pay-intent every 3 seconds (as the website does) until the
  /// provider confirms, fails or cancels it.
  void _schedulePoll() {
    _poll?.cancel();
    _poll = Timer(const Duration(seconds: 3), () async {
      final current = _result;
      if (!mounted || current == null || !current.isPending) return;
      final next = await _store.paymentIntentStatus(current, studentId: _childRecord.id);
      if (!mounted || _result?.paymentId != current.paymentId) return;
      if (next != null) setState(() => _result = next);
      if (_result?.isSuccess ?? false) _toast('Payment confirmed');
      if (_result?.isPending ?? false) _schedulePoll();
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  BillTxn _txnFromResult(FeePaymentResult result, Student child) {
    return BillTxn(
      id: result.paymentId,
      amount: double.tryParse(result.amount) ?? 0,
      method: result.method,
      status: result.status,
      reference: result.reference,
      receiptNumber: result.receiptNumber,
      transactionNumber: result.transactionNumber,
      paidAt: result.date,
      studentName: result.childName.isEmpty ? child.name : result.childName,
      previousDebt: result.previousDebt,
      remainingDebt: result.remaining,
      paidBy: result.parentName.isEmpty ? widget.user.displayName : result.parentName,
      billId: _bill?.id ?? '',
      billNumber: _bill?.displayNumber ?? '',
      schoolName: result.schoolName.isEmpty ? _store.brandedSchoolName : result.schoolName,
      feeLabel: result.feeLabel,
    );
  }

  void _toast(String text) {
    showSnack(context, text);
  }

  String get _headerTitle {
    if (_view == _PayView.bill) return 'Bill details';
    if (_view == _PayView.pay) return 'Pay fees';
    if (_view == _PayView.result && _showReceipt) return 'Receipt';
    if (_view == _PayView.result) return 'Payment';
    return 'Fees';
  }

  Color _billStatusColor(Invoice bill) {
    if (bill.isPaid) return AppColors.emerald;
    if (bill.isOverdue || bill.isCancelled) return AppColors.rose;
    if (bill.amountPaid > 0.009) return AppColors.sky;
    return AppColors.inkBlue;
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final child = _childRecord;
    final finance = store.studentFinance(child.id);
    final bills = store.billsForStudent(child.id);
    final history = store.paymentsForStudent(child.id);
    final schoolName = child.schoolName.isEmpty ? store.brandedSchoolName : child.schoolName;

    return Column(
      children: [
        AdminPageHeader(
          title: _headerTitle,
          subtitle: schoolName,
          onBack: _back,
          trailing: SchoolMarkButton(user: widget.user, onLogout: widget.onLogout, light: true),
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              if (_view == _PayView.account) ..._account(child, finance, bills, history, schoolName),
              if (_view == _PayView.bill && _bill != null) ..._billDetails(child, schoolName),
              if (_view == _PayView.pay) ..._payForm(child),
              if (_view == _PayView.result && _result != null) ..._resultView(child, schoolName),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _account(
    Student child,
    ({double charges, double paid, double balance}) finance,
    List<Invoice> bills,
    List<BillTxn> history,
    String schoolName,
  ) {
    return [
      WhiteCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MY CHILD', style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.blue, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(child.name, style: AppText.display(size: 20, weight: FontWeight.w800)),
            if (child.klass.isNotEmpty)
              Text(child.klass, style: AppText.body(size: 13, color: AppSurface.muted(context))),
            const SizedBox(height: 16),
            Row(
              children: [
                _MoneyTile(label: 'Total bill', value: finance.charges, color: AppColors.sky),
                _MoneyTile(label: 'Paid', value: finance.paid, color: AppColors.emerald),
                _MoneyTile(
                  label: 'Outstanding',
                  value: finance.balance,
                  color: finance.balance > 0.009 ? AppColors.rose : AppColors.emerald,
                ),
              ],
            ),
            if (finance.balance > 0.009) ...[
              const SizedBox(height: 14),
              HoneyButton(label: 'Pay fees', color: AppColors.blue, onPressed: _payBalance),
            ],
          ],
        ),
      ),
      ..._inProgress(child),
      const SizedBox(height: 18),
      const SectionLabel(text: 'Bills'),
      WhiteCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: bills.isEmpty
              ? [financeEmptyRow('No bills yet')]
              : [
                  const _TxnBillHead(),
                  for (final bill in bills.take(60))
                    _TxnBillRow(bill: bill, date: txnDateLabel(bill.date), ghs: _ghs, onTap: () => _openBill(bill)),
                ],
        ),
      ),
      const SizedBox(height: 18),
      const SectionLabel(text: 'Payment history'),
      WhiteCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: history.isEmpty
              ? [financeEmptyRow('No payments yet')]
              : [
                  const _TxnTableHead(),
                  for (final t in history.take(40))
                    _TxnTableRow(
                      txn: t,
                      date: txnDateLabel(t.paidAt),
                      ghs: _ghs,
                      onTap: () => showParentTxnSheet(context, txn: t, childName: child.name, schoolName: schoolName),
                    ),
                ],
        ),
      ),
    ];
  }

  /// Mobile-money payments for this child the provider has not settled yet,
  /// e.g. one started earlier and left before it was approved.
  List<Widget> _inProgress(Student child) {
    final open = [
      for (final row in _store.paymentIntents)
        if (const {'pending', 'processing', 'created'}.contains('${row['status']}') &&
            '${row['id']}' != (_result?.paymentId ?? '') &&
            ('${row['student_id'] ?? ''}'.isEmpty || '${row['student_id']}' == child.id))
          row,
    ];
    if (open.isEmpty) return const [];
    return [
      const SizedBox(height: 14),
      WhiteCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PAYMENT IN PROGRESS', style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.sky, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            for (final row in open)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_ghs(double.tryParse('${row['amount']}') ?? 0)} · waiting for mobile money approval',
                  style: AppText.body(size: 13, weight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'The balance updates automatically once the provider confirms.',
              style: AppText.body(size: 12, color: AppSurface.muted(context)),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _billDetails(Student child, String schoolName) {
    final bill = _bill!;
    final canPay = _dueNow > 0.009;
    final lines = bill.lineItems.isEmpty
        ? [BillLine(label: bill.description.isEmpty ? 'School fees' : bill.description, amount: bill.amount)]
        : bill.lineItems;
    return [
      WhiteCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(bill.displayNumber, style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.sky)),
                ),
                Text(
                  bill.parentStatus.toUpperCase(),
                  style: AppText.body(size: 11, weight: FontWeight.w800, color: _billStatusColor(bill)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _kv('Student', child.name),
            if (child.klass.isNotEmpty) _kv('Class', child.klass),
            _kv('School', schoolName),
            if (bill.academicYear.isNotEmpty) _kv('Academic year', bill.academicYear),
            if (bill.term.isNotEmpty) _kv('Term', bill.term),
            if (bill.date.isNotEmpty) _kv('Issued', formatStamp(bill.date)),
            if (bill.dueDate.isNotEmpty) _kv('Due date', formatStamp(bill.dueDate)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const SectionLabel(text: 'Bill breakdown'),
      WhiteCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.label, style: AppText.body(size: 14, weight: FontWeight.w600)),
                          if (line.category.trim().isNotEmpty)
                            Text(line.category.trim(), style: AppText.body(size: 11, color: AppColors.slate400)),
                        ],
                      ),
                    ),
                    Text('GHS ${line.amount.toStringAsFixed(2)}', style: AppText.body(size: 13, weight: FontWeight.w800)),
                    if (canPay) ...[
                      const SizedBox(width: 8),
                      _TxnMini(
                        label: 'Pay',
                        onTap: () => _startPay(fee: line),
                      ),
                    ],
                  ],
                ),
              ),
            const Divider(height: 8),
            _kv('Total', 'GHS ${bill.amount.toStringAsFixed(2)}'),
            _kv('Amount paid', 'GHS ${bill.amountPaid.toStringAsFixed(2)}'),
            _kv('Outstanding', 'GHS ${bill.dueAmount.toStringAsFixed(2)}'),
          ],
        ),
      ),
      if (canPay) ...[
        const SizedBox(height: 16),
        HoneyButton(
          label: 'Pay bill',
          color: AppColors.sky,
          onPressed: () => _startPay(),
        ),
      ],
    ];
  }

  List<Widget> _payForm(Student child) {
    final bill = _bill;
    final due = _dueNow;
    return [
      WhiteCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(child.name, style: AppText.body(size: 16, weight: FontWeight.w800)),
            Text(
              bill == null
                  ? 'Outstanding GHS ${due.toStringAsFixed(2)}'
                  : '${bill.displayNumber} · outstanding GHS ${due.toStringAsFixed(2)}',
              style: AppText.body(size: 12, color: AppSurface.muted(context)),
            ),
            const SizedBox(height: 14),
            const SectionLabel(text: 'Choose amount'),
            _Choice(
              selected: _payChoice == 'full',
              title: bill == null ? 'Pay full balance' : 'Pay full bill',
              subtitle: 'GHS ${due.toStringAsFixed(2)}',
              onTap: () => setState(() {
                _payChoice = 'full';
                _feeLine = null;
                _amount.text = due.toStringAsFixed(2);
              }),
            ),
            _Choice(
              selected: _payChoice == 'partial',
              title: 'Pay partial amount',
              subtitle: 'Enter any amount up to the outstanding',
              onTap: () => setState(() {
                _payChoice = 'partial';
                _feeLine = null;
              }),
            ),
            if (bill != null && bill.lineItems.isNotEmpty)
              _Choice(
                selected: _payChoice == 'fee',
                title: _feeLine == null ? 'Pay specific fee' : 'Pay ${_feeLine!.label}',
                subtitle: _feeLine == null
                    ? 'Pick a line on the bill'
                    : 'GHS ${(_feeLine!.amount < due ? _feeLine!.amount : due).toStringAsFixed(2)}',
                onTap: () {
                  if (_feeLine != null) {
                    setState(() => _payChoice = 'fee');
                    return;
                  }
                  _pickFee(bill);
                },
              ),
            if (_payChoice == 'partial') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: AppText.body(size: 14),
                decoration: InputDecoration(
                  labelText: 'Amount to pay (GHS)',
                  hintText: due.toStringAsFixed(2),
                  filled: true,
                  fillColor: AppSurface.card(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      const SectionLabel(text: 'Pay with'),
      Row(
        children: [
          Expanded(
            child: _Choice(
              selected: _payWith == 'momo',
              title: 'Mobile money',
              subtitle: 'MTN, Telecel, AirtelTigo',
              icon: Icons.phone_iphone_rounded,
              onTap: () => setState(() => _payWith = 'momo'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Choice(
              selected: _payWith == 'card',
              title: 'Visa / Mastercard',
              subtitle: 'Coming soon',
              icon: Icons.credit_card_rounded,
              onTap: () => setState(() => _payWith = 'card'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      if (_payWith == 'momo') ..._momoFields() else ..._cardFields(),
    ];
  }

  List<Widget> _momoFields() {
    return [
      WhiteCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _wallet,
              keyboardType: TextInputType.phone,
              onChanged: (v) {
                final detected = SchoolStore.momoProviderFor(v);
                if (detected != null && detected != _provider) setState(() => _provider = detected);
              },
              style: AppText.body(size: 13),
              decoration: InputDecoration(
                labelText: 'Wallet number',
                hintText: '024 XXX XXXX',
                filled: true,
                fillColor: AppSurface.cardSoft(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final (id, label) in _networks)
                  ChoiceChip(
                    label: Text(label, style: AppText.body(size: 11, weight: FontWeight.w600)),
                    selected: _provider == id,
                    onSelected: (_) => setState(() => _provider = id),
                    selectedColor: const Color(0xFFE0F2FE),
                    side: BorderSide(color: _provider == id ? AppColors.sky : AppColors.border),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      HoneyButton(
        label: _processing ? 'Sending…' : 'Pay GHS ${_payAmount.toStringAsFixed(2)}',
        color: AppColors.sky,
        loading: _processing,
        onPressed: _processing ? null : _pay,
      ),
      const SizedBox(height: 8),
      Text(
        'You will get a prompt on this number. Approve it with your mobile money PIN. '
        'The balance updates once the provider confirms.',
        style: AppText.body(size: 12, color: AppSurface.muted(context)),
      ),
    ];
  }

  List<Widget> _cardFields() {
    final digits = _cardNumber.text.replaceAll(RegExp(r'\D'), '');
    final brand = detectCardBrand(digits);
    String? numberError;
    if (digits.length >= 6 && brand == null) {
      numberError = 'Only Visa or Mastercard';
    } else if (digits.length == 16 && !luhnValid(digits)) {
      numberError = 'Check the card number';
    }
    final expiry = _cardExpiry.text;
    final expiryErr = expiry.length == 5 ? expiryError(expiry) : null;
    final cvvErr = _cardCvv.text.isNotEmpty && _cardCvv.text.length < 3 ? '3 digits' : null;
    final brandColor = brand == CardBrand.visa ? const Color(0xFF1A1F71) : const Color(0xFFEB001B);

    InputDecoration deco(String label, String hint, {String? error, Widget? suffix}) => InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          suffixIcon: suffix,
          filled: true,
          fillColor: AppSurface.cardSoft(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        );

    return [
      WhiteCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _cardNumber,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.creditCardNumber],
              inputFormatters: [CardNumberFormatter()],
              onChanged: (_) => setState(() {}),
              style: AppText.body(size: 14, weight: FontWeight.w600),
              decoration: deco(
                'Card number',
                '0000 0000 0000 0000',
                error: numberError,
                suffix: brand == null
                    ? const Icon(Icons.credit_card_rounded, size: 20)
                    : Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Center(
                          widthFactor: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: brandColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              brand.label.toUpperCase(),
                              style: AppText.body(size: 11, weight: FontWeight.w900, color: brandColor, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _cardExpiry,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.creditCardExpirationDate],
                    inputFormatters: [CardExpiryFormatter()],
                    onChanged: (_) => setState(() {}),
                    style: AppText.body(size: 14),
                    decoration: deco('Expiry', 'MM/YY', error: expiryErr),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cardCvv,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    autofillHints: const [AutofillHints.creditCardSecurityCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    onChanged: (_) => setState(() {}),
                    style: AppText.body(size: 14),
                    decoration: deco('CVV', '123', error: cvvErr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              brand == null ? 'We accept Visa and Mastercard. The card type is detected from the number.' : '${brand.label} card detected.',
              style: AppText.body(size: 12, color: AppSurface.muted(context)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const HoneyButton(label: 'Card payments coming soon', color: AppColors.slate400, onPressed: null),
      const SizedBox(height: 8),
      Text(
        'Card payments are not switched on for the school yet. Please pay with mobile money for now. '
        'Your card details are not saved or sent anywhere.',
        style: AppText.body(size: 12, color: AppSurface.muted(context)),
      ),
    ];
  }

  /// Once the provider confirms, the school records a real payment (receipt
  /// number, invoice, payer…); show that record rather than the intent.
  BillTxn? _recordedPayment(FeePaymentResult result, Student child) {
    if (!result.isSuccess) return null;
    final payments = _store.paymentsForStudent(child.id);
    for (final t in payments) {
      if ((result.receiptNumber.isNotEmpty && t.receiptNumber == result.receiptNumber) ||
          (result.reference.isNotEmpty && t.reference == result.reference)) {
        return t;
      }
    }
    return null;
  }

  List<Widget> _resultView(Student child, String schoolName) {
    final result = _result!;
    final txn = _recordedPayment(result, child) ?? _txnFromResult(result, child);
    final bill = billForTxn(_store, txn);
    if (_showReceipt) {
      return [
        PaymentReceipt(txn: txn, childName: child.name),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _showReceipt = false),
          child: Text('Back to payment', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.sky)),
        ),
      ];
    }
    final pending = result.isPending;
    final failed = result.isFailed;
    final slow = pending && _startedAt != null && DateTime.now().difference(_startedAt!) > const Duration(minutes: 3);
    final settlementError = failed && result.failureKind == 'settlement_error';
    final tone = pending
        ? AppColors.sky
        : failed
            ? AppColors.rose
            : AppColors.emerald;
    final ref = result.reference.trim().isEmpty ? '' : ' Reference ${result.reference}.';
    final receipt = result.receiptNumber.trim().isEmpty ? '' : ' Receipt ${result.receiptNumber}.';
    return [
      Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(
            pending
                ? Icons.hourglass_top_rounded
                : failed
                    ? Icons.error_outline_rounded
                    : Icons.check_rounded,
            color: tone,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        pending
            ? 'Payment request sent to ${_wallet.text.trim()}'
            : settlementError
                ? 'Payment needs attention'
                : failed
                    ? 'Payment not completed'
                    : 'Payment confirmed',
        textAlign: TextAlign.center,
        style: AppText.display(size: 20, weight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        pending
            ? slow
                ? 'This is taking longer than usual. You can close this; the balance updates and you get a notification once it is confirmed.'
                : 'Approve it on your phone with your mobile money PIN. Waiting for confirmation… this updates automatically.'
            : settlementError
                ? 'Your payment was received but could not be applied to the bill yet. The school will sort it out.$ref'
                : failed
                    ? 'The balance has not changed. You can try again.$ref'
                    : 'The bill and your child’s balance have been updated.$receipt',
        textAlign: TextAlign.center,
        style: AppText.body(size: 13, color: AppSurface.muted(context)),
      ),
      if (pending) ...[
        const SizedBox(height: 16),
        const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      ],
      const SizedBox(height: 16),
      TxnInfoCard(rows: txnDetailRows(txn, childName: child.name, schoolName: schoolName, bill: bill)),
      const SizedBox(height: 12),
      if (result.isSuccess)
        HoneyButton(
          label: 'View receipt',
          color: AppColors.sky,
          onPressed: () => setState(() => _showReceipt = true),
        ),
      if (failed && !settlementError)
        HoneyButton(
          label: 'Try again',
          color: AppColors.sky,
          onPressed: () => setState(() => _view = _PayView.pay),
        ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _back,
        child: Text('Close', style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.sky)),
      ),
    ];
  }

  Future<void> _pickFee(Invoice bill) async {
    final picked = await showAppSheet<BillLine>(
      context: context,
      title: 'Pay a specific fee',
      builder: (context) {
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in bill.lineItems)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.label, style: AppText.body(size: 14, weight: FontWeight.w700)),
                  trailing: Text('GHS ${line.amount.toStringAsFixed(2)}', style: AppText.body(size: 13, weight: FontWeight.w800)),
                  onTap: () => closeRoute(context, line),
                ),
            ],
        );
      },
    );
    if (picked == null || !mounted) return;
    final due = _dueNow;
    setState(() {
      _feeLine = picked;
      _payChoice = 'fee';
      _amount.text = (picked.amount < due ? picked.amount : due).toStringAsFixed(2);
    });
  }

  String _ghs(num n) => 'GHS ${n.toDouble().toStringAsFixed(2)}';

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.body(size: 12, color: AppSurface.muted(context)))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: AppText.body(size: 13, weight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.title, required this.subtitle, required this.onTap, this.icon});

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.sky.withValues(alpha: 0.08) : AppSurface.cardSoft(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: selected ? AppColors.sky : AppSurface.line(context)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: selected ? AppColors.sky : AppColors.slate500),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, weight: FontWeight.w800)),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: AppSurface.muted(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TxnMini extends StatelessWidget {
  const _TxnMini({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sky.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(label, style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.sky)),
        ),
      ),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  const _MoneyTile({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.body(size: 10, weight: FontWeight.w800, color: AppSurface.muted(context))),
          const SizedBox(height: 4),
          Text('GHS ${value.toStringAsFixed(2)}', style: AppText.body(size: 13, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _TxnTableHead extends StatelessWidget {
  const _TxnTableHead();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.slate400);
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('DATE', style: style)),
          Expanded(flex: 2, child: Text('AMOUNT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 3, child: Text('REFERENCE', style: style)),
        ],
      ),
    );
  }
}

class _TxnTableRow extends StatelessWidget {
  const _TxnTableRow({required this.txn, required this.date, required this.ghs, required this.onTap});

  final BillTxn txn;
  final String date;
  final String Function(num) ghs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = txnStatusColor(txn.status);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(date, style: AppText.body(size: 12))),
            Expanded(flex: 2, child: Text(ghs(txn.amount), style: AppText.body(size: 12, weight: FontWeight.w700))),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text(txnStatusLabel(txn.status), style: AppText.body(size: 10, weight: FontWeight.w700, color: color)),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                txnPublicRef(txn),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 11, color: AppColors.slate500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxnBillHead extends StatelessWidget {
  const _TxnBillHead();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.slate400);
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('DATE', style: style)),
          Expanded(flex: 3, child: Text('BILL', style: style)),
          Expanded(flex: 2, child: Text('TOTAL', style: style)),
          Expanded(flex: 2, child: Text('BALANCE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }
}

class _TxnBillRow extends StatelessWidget {
  const _TxnBillRow({required this.bill, required this.date, required this.ghs, required this.onTap});

  final Invoice bill;
  final String date;
  final String Function(num) ghs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = financeStatusColor(bill.status);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(date, style: AppText.body(size: 12))),
            Expanded(
              flex: 3,
              child: Text(
                bill.description.isEmpty ? bill.displayNumber : '${bill.displayNumber} · ${bill.description}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 11, color: AppColors.slate500),
              ),
            ),
            Expanded(flex: 2, child: Text(ghs(bill.amount), style: AppText.body(size: 12, weight: FontWeight.w700))),
            Expanded(flex: 2, child: Text(ghs(bill.dueAmount), style: AppText.body(size: 12))),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text(bill.parentStatus, style: AppText.body(size: 10, weight: FontWeight.w700, color: color)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
