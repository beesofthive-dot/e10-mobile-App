import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import 'common.dart';
import 'popups.dart';

/// Receipt number, else payment reference, else a real transaction number —
/// never the payment's database id.
String txnPublicRef(BillTxn txn) {
  for (final v in [txn.receiptNumber, txn.reference, txn.transactionNumber]) {
    final t = v.trim();
    if (t.isNotEmpty && t != txn.id && !SchoolStore.looksMachineId(t)) return t;
  }
  return '—';
}

String txnDateLabel(String raw) {
  final label = formatStamp(raw);
  return label.isEmpty ? '—' : label;
}

Color txnStatusColor(String status) {
  final key = status.toLowerCase();
  if (key.contains('success') || key == 'paid' || key == 'completed') return AppColors.emerald;
  if (key.contains('pend') || key.contains('process') || key == 'created') return AppColors.sky;
  if (key.contains('fail') || key.contains('void') || key.contains('cancel')) return AppColors.rose;
  return AppColors.slate500;
}

String txnStatusLabel(String status) {
  final key = status.toLowerCase();
  if (key.contains('success') || key == 'paid' || key == 'completed') return 'Successful';
  if (key.contains('process')) return 'Processing';
  if (key.contains('pend') || key == 'created') return 'Pending';
  if (key.contains('fail')) return 'Failed';
  if (key.contains('cancel')) return 'Cancelled';
  if (key.contains('refund')) return 'Refund';
  return status.isEmpty ? 'Pending' : status;
}

String _money(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$whole.${parts[1]}';
}

/// The bill a payment was made against, as the store currently has it, so
/// "Total paid" / "Balance remaining" include this payment once synced.
Invoice? billForTxn(SchoolStore store, BillTxn txn) {
  if (txn.billId.trim().isEmpty && txn.billNumber.trim().isEmpty) return null;
  for (final bill in store.invoices) {
    if ((txn.billId.isNotEmpty && bill.id == txn.billId) ||
        (txn.billNumber.isNotEmpty && bill.invoiceNumber == txn.billNumber)) {
      return bill;
    }
  }
  return null;
}

/// Payment fields in the same order and wording as the website's receipt.
List<(String, String)> _paymentRows(BillTxn txn, {String childName = '', Invoice? bill}) {
  final student = (childName.isNotEmpty ? childName : txn.studentName).trim();
  final billTitle = txn.feeLabel.trim().isNotEmpty ? txn.feeLabel.trim() : (bill?.description.trim() ?? '');
  final invoice = txn.billNumber.trim().isNotEmpty ? txn.billNumber.trim() : (bill?.invoiceNumber.trim() ?? '');
  final ref = txn.reference.trim();
  final txnId = txn.transactionNumber.trim();
  return [
    ('Receipt no.', txn.receiptNumber.trim().isEmpty ? 'Pending' : txn.receiptNumber.trim()),
    ('Student', student.isEmpty ? '—' : student),
    if (billTitle.isNotEmpty) ('Bill', billTitle),
    if (invoice.isNotEmpty) ('Invoice', invoice),
    if (ref.isNotEmpty) ('Payment ref.', ref),
    if (txnId.isNotEmpty && txnId != ref && txnId != txn.id && !SchoolStore.looksMachineId(txnId)) ('Transaction ID', txnId),
    ('Method', txn.method.isEmpty ? '—' : txn.method),
    if (txn.paidBy.trim().isNotEmpty) ('Paid by', txn.paidBy.trim()),
    ('Paid at', txnDateLabel(txn.paidAt)),
    ('Status', txnStatusLabel(txn.status)),
  ];
}

List<(String, String)> _billTotals(BillTxn txn, Invoice? bill) {
  if (bill != null) {
    return [
      ('Bill total', _money(bill.amount)),
      ('Total paid', _money(bill.amountPaid)),
      ('Balance remaining', _money(bill.dueAmount)),
    ];
  }
  return [
    if (txn.previousDebt.trim().isNotEmpty) ('Previous balance', txn.previousDebt.trim()),
    if (txn.remainingDebt.trim().isNotEmpty) ('Balance remaining', txn.remainingDebt.trim()),
  ];
}

List<(String, String)> txnDetailRows(BillTxn txn, {String childName = '', String schoolName = '', Invoice? bill}) {
  return [
    ..._paymentRows(txn, childName: childName, bill: bill),
    ('Amount received', 'GHS ${_money(txn.amount)}'),
    for (final row in _billTotals(txn, bill)) (row.$1, 'GHS ${row.$2}'),
  ];
}

/// The payment receipt laid out like the website's printable one: school
/// header, "PAYMENT RECEIPT", payment fields, the amount received and the
/// bill's totals after this payment. Paper colours in both themes.
class PaymentReceipt extends StatelessWidget {
  const PaymentReceipt({super.key, required this.txn, this.childName = '', this.store});

  final BillTxn txn;
  final String childName;

  /// Pass it when showing the receipt in a popup: the popup's own route can
  /// sit outside [SchoolScope].
  final SchoolStore? store;

  @override
  Widget build(BuildContext context) {
    final store = this.store ?? SchoolScope.of(context);
    final bill = billForTxn(store, txn);
    const ink = Color(0xFF111827);
    const muted = Color(0xFF4B5563);
    final school = txn.schoolName.trim().isNotEmpty ? txn.schoolName.trim() : store.brandedSchoolName;
    final address = (store.schoolAddress ?? '').trim();
    final phone = (store.schoolPhone ?? '').trim();
    final email = (store.schoolEmail ?? '').trim();

    Widget line(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 128, child: Text(label, style: AppText.body(size: 13, color: muted))),
              Expanded(
                child: Text(value, style: AppText.body(size: 13, weight: strong ? FontWeight.w800 : FontWeight.w500, color: ink)),
              ),
            ],
          ),
        );

    final rows = _paymentRows(txn, childName: childName, bill: bill);
    final totals = _billTotals(txn, bill);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SchoolMark(size: 56, light: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(school, style: AppText.display(size: 18, weight: FontWeight.w800, color: ink)),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(address, style: AppText.body(size: 13, color: ink)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (phone.isNotEmpty) Text('Phone: $phone', style: AppText.body(size: 13, color: ink)),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Email: $email', style: AppText.body(size: 13, color: ink)),
          ],
          const SizedBox(height: 16),
          Text('PAYMENT RECEIPT', style: AppText.body(size: 15, weight: FontWeight.w900, color: ink, letterSpacing: 0.5)),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1.5, color: ink),
          const SizedBox(height: 16),
          for (final (i, row) in rows.indexed) line(row.$1, row.$2, strong: i == 0),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: Border.all(color: ink, width: 1.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Amount received (GHS)', style: AppText.body(size: 13, color: ink)),
                const SizedBox(height: 4),
                Text(_money(txn.amount), style: AppText.display(size: 26, weight: FontWeight.w900, color: ink)),
              ],
            ),
          ),
          if (totals.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final row in totals) line(row.$1, row.$2, strong: row.$1 == 'Balance remaining'),
          ],
        ],
      ),
    );
  }
}

class TxnInfoCard extends StatelessWidget {
  const TxnInfoCard({super.key, required this.rows, this.title});

  final List<(String, String)> rows;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.sky)),
            const SizedBox(height: 8),
          ],
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(row.$1, style: AppText.body(size: 12, color: AppSurface.muted(context)))),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: AppText.body(size: 13, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ChildTxnCard extends StatelessWidget {
  const ChildTxnCard({
    super.key,
    required this.txn,
    this.childName,
    this.schoolName,
    this.onDetails,
    this.onReceipt,
  });

  final BillTxn txn;
  final String? childName;
  final String? schoolName;
  final VoidCallback? onDetails;
  final VoidCallback? onReceipt;

  @override
  Widget build(BuildContext context) {
    final color = txnStatusColor(txn.status);
    final title = txn.feeLabel.trim().isEmpty ? (txn.method.isEmpty ? 'Payment' : txn.method) : txn.feeLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppSurface.card(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppSurface.line(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.body(size: 14, weight: FontWeight.w800)),
                      Text(
                        'GHS ${txn.amount.toStringAsFixed(2)}',
                        style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.sky),
                      ),
                    ],
                  ),
                ),
                Text(
                  txnStatusLabel(txn.status),
                  style: AppText.body(size: 12, weight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reference: ${txnPublicRef(txn)}',
              style: AppText.body(size: 12, color: AppSurface.muted(context)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _TxnLink(
                  label: 'View Details',
                  onTap: onDetails ??
                      () => showParentTxnSheet(
                            context,
                            txn: txn,
                            childName: childName ?? '',
                            schoolName: schoolName ?? '',
                          ),
                ),
                const SizedBox(width: 8),
                _TxnLink(
                  label: 'View Receipt',
                  onTap: onReceipt ??
                      () => showParentTxnSheet(
                            context,
                            txn: txn,
                            childName: childName ?? '',
                            schoolName: schoolName ?? '',
                            receipt: true,
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxnLink extends StatelessWidget {
  const _TxnLink({required this.label, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.sky)),
        ),
      ),
    );
  }
}

Future<void> showParentTxnSheet(
  BuildContext context, {
  required BillTxn txn,
  String childName = '',
  String schoolName = '',
  bool receipt = false,
}) {
  final store = SchoolScope.maybeOf(context);
  return showAppSheet<void>(
    context: context,
    title: receipt ? 'Receipt' : 'Payment details',
    builder: (sheet) {
      if (receipt && store != null) return PaymentReceipt(txn: txn, childName: childName, store: store);
      final bill = store == null ? null : billForTxn(store, txn);
      if (receipt) return TxnInfoCard(rows: txnDetailRows(txn, childName: childName, schoolName: schoolName));
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TxnInfoCard(rows: txnDetailRows(txn, childName: childName, schoolName: schoolName, bill: bill)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              closeRoute(sheet);
              showParentTxnSheet(context, txn: txn, childName: childName, schoolName: schoolName, receipt: true);
            },
            child: Text('View receipt', style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.sky)),
          ),
        ],
      );
    },
  );
}
