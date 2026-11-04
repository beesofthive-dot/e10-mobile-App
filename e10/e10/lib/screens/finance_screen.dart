import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/finance_ui.dart';
import '../widgets/txn_tiles.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen(
      {super.key, this.onBack, required this.onLogout, this.viewOnly = false});

  final VoidCallback? onBack;
  final VoidCallback onLogout;
  final bool viewOnly;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _Txn {
  const _Txn({
    required this.paidAt,
    required this.student,
    required this.amount,
    required this.method,
    required this.source,
    required this.status,
    required this.reference,
    this.kind = 'in',
    this.provider = '',
    this.full,
  });

  final DateTime? paidAt;
  final String student;
  final double amount;
  final String method;
  final String source;
  final String status;
  final String reference;
  final String kind;
  final String provider;

  /// The fully-parsed record (fee/bill line, previous/remaining debt, who
  /// paid, a true transaction number) — only present for real API rows, not
  /// the local `invoices`-derived fallback used when `/payments` is empty.
  final BillTxn? full;
}

class _FinanceScreenState extends State<FinanceScreen> {
  String _status = 'Any';
  String _method = 'Any';
  String _chartPeriod = 'By day';
  String _tab = 'in';
  bool _refreshing = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = SchoolScope.of(context);
      store.loadFinanceWorkspace();
      store.refreshBillsAndPayments();
    });
  }

  String _ghs(num n) => 'GHS ${n.toDouble().toStringAsFixed(2)}';

  DateTime? _parseDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t) ?? DateTime.tryParse(t.replaceAll('/', '-'));
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _val(dynamic v) {
    if (v is Map) return '${v['value'] ?? v['name'] ?? ''}';
    return '$v';
  }

  double _amountOf(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  String _methodGroup(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('momo') || m.contains('telecel') || m.contains('airtel')) {
      return 'momo';
    }
    if (m.contains('card')) return 'card';
    if (m.contains('bank')) return 'bank';
    if (m.contains('cash') || m.contains('wallet')) return 'cash';
    return m;
  }

  String _providerOf(String method, String provider) {
    if (provider.trim().isNotEmpty) return provider;
    return switch (_methodGroup(method)) {
      'momo' when method.contains('telecel') => 'Telecel',
      'momo' when method.contains('airtel') => 'AirtelTigo',
      'momo' => 'MTN',
      'card' => 'Visa',
      'bank' => 'GCB',
      _ => '',
    };
  }

  List<_Txn> _all(SchoolStore store) {
    final fromApi = store.tableRows('payments');
    final rows = [
      for (final p in fromApi)
        _Txn(
          paidAt: _parseDate('${p['paid_at'] ?? p['created_at'] ?? ''}'),
          student: p['student'] is Map
              ? '${(p['student'] as Map)['full_name'] ?? ''}'
              : '${p['student_name'] ?? p['payer'] ?? p['name'] ?? 'Payment'}',
          amount: _amountOf(p['amount']),
          method: _val(p['method']),
          source: _val(p['source']).isEmpty
              ? (_val(p['paid_by']).trim().isEmpty ? 'office' : 'parent')
              : _val(p['source']),
          status: _val(p['status']).isEmpty ? 'successful' : _val(p['status']),
          reference:
              '${p['receipt_number'] ?? p['reference'] ?? p['id'] ?? ''}',
          provider: _providerOf(_val(p['method']), _val(p['provider'])),
          kind: _val(p['kind']).toLowerCase().contains('out') ? 'out' : 'in',
          full: store.billTxnForRow(p),
        ),
    ];
    // Settlements out to the school come from `/payouts`, as on the website.
    for (final p in store.tableRows('payouts')) {
      rows.add(
        _Txn(
          paidAt: _parseDate('${p['settled_at'] ?? p['created_at'] ?? ''}'),
          student: '${p['destination_identifier'] ?? 'Payout'}',
          amount: _amountOf(p['amount']),
          method: _val(p['provider']),
          source: 'payout',
          status: _val(p['status']),
          reference: '${p['reference'] ?? p['id'] ?? ''}',
          provider: _val(p['provider']),
          kind: 'out',
        ),
      );
    }
    return rows;
  }

  bool _matchesSearch(_Txn t) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [
      t.student,
      t.reference,
      t.full?.studentId ?? '',
      t.full?.billNumber ?? '',
      t.full?.billId ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  List<_Txn> _filtered(List<_Txn> rows) {
    return [
      for (final t in rows)
        if ((_status == 'Any' ||
                t.status.toLowerCase() == _status.toLowerCase()) &&
            (_method == 'Any' ||
                _methodGroup(t.method) == _method.toLowerCase()) &&
            _matchesSearch(t))
          t,
    ];
  }

  Future<void> _refresh(SchoolStore store) async {
    setState(() => _refreshing = true);
    await store.syncFromApi();
    await store.refreshBillsAndPayments();
    await store.loadFinanceWorkspace();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Map<String, double> _volume(List<_Txn> rows) {
    final map = <String, double>{};
    for (final t
        in rows.where((r) => r.kind == 'in' && r.status == 'successful')) {
      final d = t.paidAt ?? DateTime.now();
      final key = switch (_chartPeriod) {
        'By week' =>
          '${d.year}-W${((d.difference(DateTime(d.year)).inDays) / 7).floor() + 1}',
        'By month' => '${d.year}-${d.month.toString().padLeft(2, '0')}',
        _ =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      };
      map[key] = (map[key] ?? 0) + t.amount;
    }
    return map;
  }

  Map<String, double> _byMethod(List<_Txn> rows) {
    final map = <String, double>{};
    for (final t
        in rows.where((r) => r.kind == 'in' && r.status == 'successful')) {
      final key = _methodGroup(t.method);
      map[key.isEmpty ? 'other' : key] =
          (map[key.isEmpty ? 'other' : key] ?? 0) + t.amount;
    }
    return map;
  }

  /// Bills created on the office website (synced from `/bills`), filtered by
  /// the same date range and search box as the payment tables.
  List<Widget> _billsTable(SchoolStore store) {
    final q = _search.trim().toLowerCase();
    final bills = [
      for (final b in store.invoices)
        if ((q.isEmpty ||
            [b.student, b.displayNumber, b.studentId, b.description]
                .join(' ')
                .toLowerCase()
                .contains(q)))
          b,
    ];
    if (bills.isEmpty) return [financeEmptyRow('No bills match these filters')];
    return [
      const _BillHead(),
      for (final b in bills.take(60))
        _BillRow(bill: b, date: _dateLabel(_parseDate(b.date)), ghs: _ghs),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final all = _all(store);
    final filtered = _filtered(all);
    final incoming = [
      for (final t in filtered)
        if (t.kind == 'in') t
    ];
    final outgoing = [
      for (final t in filtered)
        if (t.kind == 'out') t
    ];
    final collected = incoming
        .where((t) => t.status == 'successful')
        .fold<double>(0, (s, t) => s + t.amount);
    final disbursed = outgoing
        .where((t) => t.status == 'successful')
        .fold<double>(0, (s, t) => s + t.amount);
    final successCount = incoming.where((t) => t.status == 'successful').length;
    final failed = incoming.where((t) => t.status == 'failed').length;
    final pending = incoming.where((t) => t.status.contains('pend')).length;
    final collectedValue = _ghs(collected);
    final table = incoming;
    final volume = _volume(filtered);
    final methods = _byMethod(filtered);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Transactions',
            subtitle: store.brandedSchoolName,
            onBack: widget.onBack,
            trailing: IconButton(
              onPressed: _refreshing ? null : () => _refresh(store),
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
            ),
          ),
          Expanded(
            child: ListView(
              padding: AppLayout.page(context),
              children: [
                WhiteCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search by student name, ID, or reference',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  icon:
                                      const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(() {
                                    _searchCtrl.clear();
                                    _search = '';
                                  }),
                                ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, box) {
                          final status = FilterDrop(
                              label: 'Status',
                              value: _status,
                              items: const [
                                'Any',
                                'successful',
                                'failed',
                                'pending'
                              ],
                              onChanged: (v) => setState(() => _status = v));
                          final method = FilterDrop(
                              label: 'Method',
                              value: _method,
                              items: const [
                                'Any',
                                'cash',
                                'momo',
                                'card',
                                'bank'
                              ],
                              onChanged: (v) => setState(() => _method = v));
                          final period = FilterDrop(
                              label: 'Chart period',
                              value: _chartPeriod,
                              items: const ['By day', 'By week', 'By month'],
                              onChanged: (v) =>
                                  setState(() => _chartPeriod = v));
                          if (box.maxWidth >= 520) {
                            return Row(children: [
                              Expanded(child: status),
                              const SizedBox(width: 12),
                              Expanded(child: method),
                              const SizedBox(width: 12),
                              Expanded(child: period)
                            ]);
                          }
                          return Column(
                            children: [
                              Row(children: [
                                Expanded(child: status),
                                const SizedBox(width: 12),
                                Expanded(child: method)
                              ]),
                              const SizedBox(height: 12),
                              period,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth >= 900 ? 4 : 2;
                    final w = (box.maxWidth - (10 * (cols - 1))) / cols;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                            width: w,
                            child: StatTile(
                                label: 'Total collected',
                                value: collectedValue,
                                hint: '$successCount successful payments')),
                        SizedBox(
                            width: w,
                            child: StatTile(
                                label: 'Total disbursed',
                                value: _ghs(disbursed),
                                hint:
                                    '${outgoing.where((t) => t.status == 'successful').length} successful payouts')),
                        SizedBox(
                            width: w,
                            child: StatTile(
                                label: 'Successful',
                                value: '$successCount',
                                hint: 'Payment count by status')),
                        SizedBox(
                            width: w,
                            child: StatTile(
                                label: 'Failed / pending',
                                value: '${failed + pending}',
                                hint: '$failed failed · $pending pending')),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: ChartCard(
                              title: 'Volume over time',
                              empty:
                                  'No collection volume in this filter range',
                              points: volume,
                              line: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ChartCard(
                              title: 'By method',
                              empty: 'No method breakdown yet',
                              points: methods)),
                    ],
                  )
                else ...[
                  ChartCard(
                      title: 'Volume over time',
                      empty: 'No collection volume in this filter range',
                      points: volume,
                      line: true),
                  const SizedBox(height: 12),
                  ChartCard(
                      title: 'By method',
                      empty: 'No method breakdown yet',
                      points: methods),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TabChip(
                        label: 'Payments in',
                        selected: _tab == 'in',
                        onTap: () => setState(() => _tab = 'in')),
                    TabChip(
                        label: 'Bills',
                        selected: _tab == 'bills',
                        onTap: () => setState(() => _tab = 'bills')),
                  ],
                ),
                const SizedBox(height: 12),
                WhiteCard(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tab == 'in' ? 'Payments' : 'Bills',
                        style:
                            AppText.display(size: 18, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if (_tab == 'bills')
                        ..._billsTable(store)
                      else if (table.isEmpty)
                        financeEmptyRow('No payments match these filters')
                      else ...[
                        _TableHead(),
                        for (final t in table.take(40))
                          _TableRow(
                            txn: t,
                            date: _dateLabel(t.paidAt),
                            amount: _ghs(t.amount),
                            method: _methodGroup(t.method),
                            onViewHistory: (name) => setState(() {
                              _searchCtrl.text = name;
                              _search = name;
                            }),
                          ),
                      ],
                    ],
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

/// Phone widths get stacked rows (name + details left, amount + status
/// right) instead of a squeezed multi-column table.
bool _compactTable(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 640;

const _headStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.slate400);

String _statusText(String raw) {
  final t = raw.trim().replaceAll('_', ' ');
  if (t.isEmpty) return '—';
  return t[0].toUpperCase() + t.substring(1);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = financeStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(
        _statusText(status),
        maxLines: 1,
        softWrap: false,
        style: AppText.body(size: 10, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (_compactTable(context)) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('PAID AT', style: _headStyle)),
          Expanded(flex: 3, child: Text('STUDENT', style: _headStyle)),
          Expanded(flex: 2, child: Text('AMOUNT', style: _headStyle)),
          Expanded(flex: 2, child: Text('METHOD', style: _headStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: _headStyle)),
          Expanded(flex: 3, child: Text('REFERENCE', style: _headStyle)),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow(
      {required this.txn,
      required this.date,
      required this.amount,
      required this.method,
      this.onViewHistory});

  final _Txn txn;
  final String date;
  final String amount;
  final String method;
  final ValueChanged<String>? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final full = txn.full;
    final student = Text(
      txn.student,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.body(size: 13, weight: FontWeight.w700),
    );
    final history = onViewHistory != null && txn.student.trim().isNotEmpty
        ? InkResponse(
            radius: 16,
            onTap: () => onViewHistory!(txn.student),
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child:
                  Icon(Icons.history_rounded, size: 16, color: AppColors.blue),
            ),
          )
        : null;

    final Widget body;
    if (_compactTable(context)) {
      body = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: student),
                  if (history != null) history
                ]),
                const SizedBox(height: 3),
                Text(
                  [
                    date,
                    if (method.isNotEmpty) method,
                    if (txn.reference.trim().isNotEmpty) txn.reference
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 11, color: AppColors.slate500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: AppText.body(size: 13, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              _StatusPill(status: txn.status),
            ],
          ),
        ],
      );
    } else {
      body = Row(
        children: [
          Expanded(flex: 2, child: Text(date, style: AppText.body(size: 12))),
          Expanded(
              flex: 3,
              child: Row(children: [
                Flexible(child: student),
                if (history != null) history
              ])),
          Expanded(
              flex: 2,
              child: Text(amount,
                  style: AppText.body(size: 12, weight: FontWeight.w700))),
          Expanded(flex: 2, child: Text(method, style: AppText.body(size: 12))),
          Expanded(
              flex: 2,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(status: txn.status))),
          Expanded(
            flex: 3,
            child: Text(txn.reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 11, color: AppColors.slate500)),
          ),
        ],
      );
    }
    return InkWell(
      onTap: full == null
          ? null
          : () =>
              showParentTxnSheet(context, txn: full, childName: txn.student),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppSurface.line(context)))),
        child: body,
      ),
    );
  }
}

class _BillHead extends StatelessWidget {
  const _BillHead();

  @override
  Widget build(BuildContext context) {
    if (_compactTable(context)) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('DATE', style: _headStyle)),
          Expanded(flex: 3, child: Text('STUDENT', style: _headStyle)),
          Expanded(flex: 3, child: Text('BILL', style: _headStyle)),
          Expanded(flex: 2, child: Text('TOTAL', style: _headStyle)),
          Expanded(flex: 2, child: Text('BALANCE', style: _headStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: _headStyle)),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.date, required this.ghs});

  final Invoice bill;
  final String date;
  final String Function(num) ghs;

  @override
  Widget build(BuildContext context) {
    final billLabel = bill.description.isEmpty
        ? bill.displayNumber
        : '${bill.displayNumber} · ${bill.description}';
    final Widget body;
    if (_compactTable(context)) {
      body = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.student,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  '$date  ·  $billLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 11, color: AppColors.slate500),
                ),
                const SizedBox(height: 2),
                Text('Total ${ghs(bill.amount)}',
                    style: AppText.body(size: 11, color: AppColors.slate500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ghs(bill.dueAmount),
                  style: AppText.body(size: 13, weight: FontWeight.w800)),
              Text('balance',
                  style: AppText.body(size: 10, color: AppColors.slate400)),
              const SizedBox(height: 4),
              _StatusPill(status: bill.status),
            ],
          ),
        ],
      );
    } else {
      body = Row(
        children: [
          Expanded(flex: 2, child: Text(date, style: AppText.body(size: 12))),
          Expanded(
            flex: 3,
            child: Text(bill.student,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 12, weight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(billLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 11, color: AppColors.slate500)),
          ),
          Expanded(
              flex: 2,
              child: Text(ghs(bill.amount),
                  style: AppText.body(size: 12, weight: FontWeight.w700))),
          Expanded(
              flex: 2,
              child: Text(ghs(bill.dueAmount), style: AppText.body(size: 12))),
          Expanded(
              flex: 2,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(status: bill.status))),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppSurface.line(context)))),
      child: body,
    );
  }
}
