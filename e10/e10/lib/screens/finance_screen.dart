import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../feeding.dart' show schoolCurrency;
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/finance_ui.dart';
import '../widgets/txn_charts.dart';
import '../widgets/txn_tiles.dart';
import 'admin_forms.dart' show showSnack;

/// Admin Transactions, the same page as the website's: every figure comes
/// from the server so it tallies with the records — the tiles and both
/// charts from `GET /transactions-summary`, the table from `GET /payments`
/// (25 a page) — and the same filters (status, method, chart period,
/// recorded by, search) apply to all of them.
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
    this.recordedBy = '',
    this.confirmedLate = false,
    this.full,
  });

  final DateTime? paidAt;
  final String student;
  final double amount;
  final String method;
  final String source;
  final String status;
  final String reference;
  final String recordedBy;
  final bool confirmedLate;

  /// The fully-parsed record (fee/bill line, previous/remaining debt, who
  /// paid, a true transaction number) for the receipt sheet.
  final BillTxn? full;
}

/// Method names exactly as the website writes them.
const _methodLabels = {
  'mtn_momo': 'MTN MoMo',
  'telecel_cash': 'Telecel Cash',
  'airteltigo_money': 'AirtelTigo Money',
  'card': 'Card',
  'bank_transfer': 'Bank transfer',
  'cash': 'Cash',
};

String _methodLabel(String raw) =>
    raw.isEmpty ? '—' : (_methodLabels[raw] ?? raw.replaceAll('_', ' '));

class _FinanceScreenState extends State<FinanceScreen> {
  // Filters, with the website's choices (value, label).
  static const _statuses = [('', 'Any'), ('successful', 'Successful'), ('pending', 'Pending'), ('processing', 'Processing'), ('failed', 'Failed')];
  static const _methods = [('', 'Any'), ('cash', 'Cash'), ('mtn_momo', 'MTN MoMo'), ('telecel_cash', 'Telecel Cash'), ('airteltigo_money', 'AirtelTigo'), ('bank_transfer', 'Bank transfer')];
  static const _periods = [('day', 'By day'), ('week', 'By week')];

  String _status = '';
  String _method = '';
  String _period = 'day';
  String _recordedBy = '';
  String _tab = 'in';
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _recorders = const [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      // Bills tab still reads the store's synced bills.
      final store = SchoolScope.of(context);
      store.loadFinanceWorkspace();
      store.refreshBillsAndPayments();
    });
  }

  String get _currency => schoolCurrency();

  String _money(num n) {
    final fixed = n.toDouble().toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '$_currency $whole.${parts[1]}';
  }

  /// The filters as the website sends them (empty ones left out).
  Map<String, String> get _query => {
        'period': _period,
        if (_status.isNotEmpty) 'status': _status,
        if (_method.isNotEmpty) 'method': _method,
      };

  static Map<String, dynamic>? _unwrap(dynamic body) {
    if (body is! Map) return null;
    final data = body['data'];
    return Map<String, dynamic>.from(data is Map ? data : body);
  }

  static List<Map<String, dynamic>> _rows(dynamic v) =>
      v is List ? [for (final r in v) if (r is Map) Map<String, dynamic>.from(r)] : const [];

  Future<void> _load({int page = 1}) async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final query = _query;
    try {
      final results = await Future.wait([
        ApiClient.instance.get('payments', query: {
          ...query,
          if (_recordedBy.isNotEmpty) 'recorded_by': _recordedBy,
          if (_search.trim().isNotEmpty) 'search': _search.trim(),
          'page': '$page',
          'per_page': '25',
        }),
        ApiClient.instance.get('transactions-summary', query: {...query, 'per_page': '100'}),
      ]);
      if (!mounted || seq != _seq) return;
      final pay = results[0];
      final meta = pay is Map && pay['meta'] is Map ? pay['meta'] as Map : const {};
      setState(() {
        _payments = _rows(pay is Map ? pay['data'] : pay);
        _recorders = _rows(pay is Map ? pay['recorders'] : null);
        _page = page;
        _lastPage = int.tryParse('${meta['last_page'] ?? 1}') ?? 1;
        _total = int.tryParse('${meta['total'] ?? _payments.length}') ?? _payments.length;
        _summary = _unwrap(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = 'Could not load transactions. Pull down or tap refresh to try again.';
      });
    }
  }

  void _setFilter(VoidCallback change) {
    setState(change);
    _load();
  }

  Future<void> _refresh(SchoolStore store) async {
    await Future.wait([_load(page: _page), store.refreshBillsAndPayments()]);
    if (mounted && _error == null) showSnack(context, 'Transactions refreshed');
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _val(dynamic v) => v is Map ? '${v['value'] ?? v['name'] ?? ''}' : '${v ?? ''}';

  _Txn _txn(SchoolStore store, Map<String, dynamic> p) {
    final student = p['student'] is Map
        ? '${(p['student'] as Map)['full_name'] ?? ''}'
        : (p['bill'] is Map && (p['bill'] as Map)['student'] is Map
            ? '${((p['bill'] as Map)['student'] as Map)['full_name'] ?? ''}'
            : '');
    final source = _val(p['source']);
    return _Txn(
      paidAt: DateTime.tryParse('${p['paid_at'] ?? ''}')?.toLocal(),
      student: student.isEmpty ? '—' : student,
      amount: double.tryParse('${p['amount'] ?? 0}') ?? 0,
      method: _val(p['method']),
      source: source.isEmpty ? '—' : source,
      status: _val(p['status']),
      reference: '${p['receipt_number'] ?? p['reference'] ?? ''}',
      recordedBy: '${p['recorded_by_name'] ?? (source == 'gateway' ? 'Online' : '—')}',
      confirmedLate: p['confirmed_late'] == true,
      full: store.billTxnForRow(p),
    );
  }

  /// Bills created on the office website (synced from `/bills`), filtered by
  /// the search box.
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
        _BillRow(bill: b, date: _dateLabel(DateTime.tryParse(b.date)), ghs: _money),
    ];
  }

  Widget _drop(String label, String value, List<(String, String)> items, ValueChanged<String> onChanged) {
    final labels = [for (final i in items) i.$2];
    final current = items.firstWhere((i) => i.$1 == value, orElse: () => items.first).$2;
    return FilterDrop(
      label: label,
      value: current,
      items: labels,
      onChanged: (l) => onChanged(items.firstWhere((i) => i.$2 == l).$1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final summary = _summary;
    final totals = summary?['totals'] is Map ? summary!['totals'] as Map : const {};
    final byStatus = totals['by_status'] is Map ? totals['by_status'] as Map : const {};
    int count(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
    double amount(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;
    final failed = count(byStatus['failed']);
    final pending = count(byStatus['pending']);
    final volume = [
      for (final r in _rows(summary?['volume_over_time']))
        ChartPoint('${r['period'] ?? ''}', amount(r['amount']), count(r['count'])),
    ];
    final methods = [
      for (final r in _rows(summary?['by_method']))
        ChartPoint('${r['method'] ?? ''}'.replaceAll('_', ' '), amount(r['amount']), count(r['count'])),
    ];
    final table = [for (final p in _payments) _txn(store, p)];
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final volumeChart = TxnChartCard(
      title: 'Volume over time',
      empty: 'No collection volume in this filter range',
      points: volume,
      format: _money,
    );
    final methodChart = TxnChartCard(
      title: 'By method',
      empty: 'No method breakdown yet',
      points: methods,
      format: _money,
      bars: true,
    );

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Transactions',
            subtitle: store.brandedSchoolName,
            onBack: widget.onBack,
            trailing: IconButton(
              onPressed: _loading ? null : () => _refresh(store),
              icon: _loading
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
            child: RefreshIndicator(
              onRefresh: () => _refresh(store),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppLayout.page(context),
                children: [
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) {
                            setState(() => _search = v);
                            _debounce?.cancel();
                            _debounce = Timer(const Duration(milliseconds: 350), _load);
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search by student name, ID, or reference',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _search.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () => _setFilter(() {
                                      _searchCtrl.clear();
                                      _search = '';
                                    }),
                                  ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, box) {
                            final status = _drop('Status', _status, _statuses, (v) => _setFilter(() => _status = v));
                            final method = _drop('Method', _method, _methods, (v) => _setFilter(() => _method = v));
                            final period = _drop('Chart period', _period, _periods, (v) => _setFilter(() => _period = v));
                            if (box.maxWidth >= 520) {
                              return Row(children: [
                                Expanded(child: status),
                                const SizedBox(width: 12),
                                Expanded(child: method),
                                const SizedBox(width: 12),
                                Expanded(child: period),
                              ]);
                            }
                            return Column(
                              children: [
                                Row(children: [
                                  Expanded(child: status),
                                  const SizedBox(width: 12),
                                  Expanded(child: method),
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: AppText.body(size: 13, color: AppColors.rose)),
                  ],
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, box) {
                      final cols = box.maxWidth >= 720 ? 3 : 2;
                      final w = (box.maxWidth - (10 * (cols - 1))) / cols;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                              width: cols == 2 ? box.maxWidth : w,
                              child: StatTile(
                                  label: 'Total collected',
                                  value: summary == null ? '—' : _money(amount(totals['collected'])),
                                  hint: '${count(totals['collected_count'])} successful payments')),
                          SizedBox(
                              width: w,
                              child: StatTile(
                                  label: 'Successful',
                                  value: summary == null ? '—' : '${count(byStatus['successful'])}',
                                  hint: 'Payment count by status')),
                          SizedBox(
                              width: w,
                              child: StatTile(
                                  label: 'Failed / pending',
                                  value: summary == null ? '—' : '${failed + pending}',
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
                        Expanded(flex: 3, child: volumeChart),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: methodChart),
                      ],
                    )
                  else ...[
                    volumeChart,
                    const SizedBox(height: 12),
                    methodChart,
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TabChip(label: 'Payments', selected: _tab == 'in', onTap: () => setState(() => _tab = 'in')),
                      TabChip(label: 'Bills', selected: _tab == 'bills', onTap: () => setState(() => _tab = 'bills')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WhiteCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _tab == 'in' ? 'Payments' : 'Bills',
                                style: AppText.display(size: 18, weight: FontWeight.w700),
                              ),
                            ),
                            if (_tab == 'in' && _recorders.isNotEmpty)
                              Flexible(
                                child: DropdownButton<String>(
                                  value: _recordedBy,
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  style: AppText.body(size: 12, color: AppColors.slate600),
                                  items: [
                                    const DropdownMenuItem(value: '', child: Text('Recorded by: anyone')),
                                    for (final r in _recorders)
                                      DropdownMenuItem(value: '${r['id']}', child: Text('${r['name'] ?? ''}', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (v) => _setFilter(() => _recordedBy = v ?? ''),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_tab == 'bills')
                          ..._billsTable(store)
                        else if (_loading && table.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                          )
                        else if (table.isEmpty)
                          financeEmptyRow('No payments match these filters')
                        else ...[
                          _TableHead(),
                          for (final t in table)
                            _TableRow(
                              txn: t,
                              date: _dateLabel(t.paidAt),
                              amount: _money(t.amount),
                              method: _methodLabel(t.method),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _lastPage <= 1
                                ? Text('Showing all $_total', style: AppText.body(size: 12, color: AppColors.slate500))
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Showing ${(_page - 1) * 25 + 1}–${(_page - 1) * 25 + table.length} of $_total · page $_page of $_lastPage',
                                          style: AppText.body(size: 12, color: AppColors.slate500),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _loading || _page <= 1 ? null : () => _load(page: _page - 1),
                                        child: const Text('Previous'),
                                      ),
                                      TextButton(
                                        onPressed: _loading || _page >= _lastPage ? null : () => _load(page: _page + 1),
                                        child: const Text('Next'),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
          Expanded(flex: 2, child: Text('SOURCE', style: _headStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: _headStyle)),
          Expanded(flex: 3, child: Text('REFERENCE', style: _headStyle)),
          Expanded(flex: 2, child: Text('RECORDED BY', style: _headStyle)),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final color = source == 'gateway' ? AppColors.blue : AppColors.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(source, maxLines: 1, softWrap: false, style: AppText.body(size: 10, weight: FontWeight.w700, color: color)),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.txn, required this.date, required this.amount, required this.method});

  final _Txn txn;
  final String date;
  final String amount;
  final String method;

  @override
  Widget build(BuildContext context) {
    final full = txn.full;
    final student = Text(
      txn.student,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.body(size: 13, weight: FontWeight.w700),
    );
    final status = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _StatusPill(status: txn.status),
        // The network confirmed this MoMo payment after the app had stopped
        // waiting; it was credited when it came through.
        if (txn.confirmedLate) const _StatusPill(status: 'confirmed late'),
      ],
    );

    final Widget body;
    if (_compactTable(context)) {
      body = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                student,
                const SizedBox(height: 3),
                Text(
                  [date, method, if (txn.reference.trim().isNotEmpty) txn.reference].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 11, color: AppColors.slate500),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _SourcePill(source: txn.source),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('by ${txn.recordedBy}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, color: AppColors.slate500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: AppText.body(size: 13, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              status,
            ],
          ),
        ],
      );
    } else {
      body = Row(
        children: [
          Expanded(flex: 2, child: Text(date, style: AppText.body(size: 12))),
          Expanded(flex: 3, child: student),
          Expanded(flex: 2, child: Text(amount, style: AppText.body(size: 12, weight: FontWeight.w700))),
          Expanded(flex: 2, child: Text(method, style: AppText.body(size: 12))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _SourcePill(source: txn.source))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: status)),
          Expanded(
            flex: 3,
            child: Text(txn.reference,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, color: AppColors.slate500)),
          ),
          Expanded(
            flex: 2,
            child: Text(txn.recordedBy, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12)),
          ),
        ],
      );
    }
    return InkWell(
      onTap: full == null ? null : () => showParentTxnSheet(context, txn: full, childName: txn.student),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppSurface.line(context)))),
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
