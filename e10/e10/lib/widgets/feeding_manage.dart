import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../feeding.dart';
import '../models.dart';
import '../screens/admin_forms.dart' show showSnack;
import '../theme.dart';
import 'feeding_widgets.dart';
import 'popups.dart';

/// The bursar/admin Feeding tabs from the website: Payments (with void),
/// Cash-up, Report and Rates & days. Each is a self-contained card list.

Widget _spinner() => const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
    );

BoxDecoration _rowBox(BuildContext context) => BoxDecoration(
      color: AppSurface.cardSoft(context),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppSurface.line(context)),
    );

Future<String?> _askReason(BuildContext context, {required String title, required String summary, required String note, required String action}) {
  final reason = TextEditingController();
  return showAppSheet<String>(
    context: context,
    title: title,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(summary, style: AppText.body(size: 13.5, color: AppColors.slate700)),
          const SizedBox(height: 12),
          const AppFieldLabel('Reason', required: true),
          TextField(
            controller: reason,
            maxLength: 255,
            decoration: appFieldDecoration(ctx, hint: 'e.g. Recorded for the wrong child'),
            onChanged: (_) => setState(() {}),
          ),
          Text(note, style: AppText.body(size: 12, color: AppColors.slate500)),
          const SizedBox(height: 14),
          AppModalButton(
            label: action,
            onPressed: reason.text.trim().length < 3 ? null : () => closeRoute(ctx, reason.text.trim()),
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────────── Payments ─────────────────────────────

class FeedingPaymentsTab extends StatefulWidget {
  const FeedingPaymentsTab({super.key, required this.user, required this.currency});

  final AppUser user;
  final String currency;

  @override
  State<FeedingPaymentsTab> createState() => _FeedingPaymentsTabState();
}

class _FeedingPaymentsTabState extends State<FeedingPaymentsTab> {
  final _search = TextEditingController();
  String _method = '';
  String _status = 'all';
  String _cashier = '';
  final List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _cashiers = const [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  Timer? _debounce;
  int _seq = 0;

  bool get _seeAll => FeedingAccess.seeAllFeeding(widget.user);
  String _money(dynamic v) => money(v, widget.currency);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final seq = ++_seq;
    final page = more ? _page + 1 : 1;
    setState(() => _loading = true);
    try {
      final body = await FeedingApi.feedingPayments({
        'page': '$page',
        'per_page': '25',
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        if (_method.isNotEmpty) 'method': _method,
        if (_cashier.isNotEmpty) 'cashier_id': _cashier,
        'status': _status,
      });
      if (!mounted || seq != _seq) return;
      final meta = body['meta'] is Map ? body['meta'] as Map : const {};
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(FeedingApi.rows(body['data']));
        _cashiers = FeedingApi.rows(body['cashiers']);
        _page = page;
        _lastPage = intOf(meta['last_page']) > 0 ? intOf(meta['last_page']) : page;
      });
    } catch (e) {
      if (mounted && seq == _seq) showSnack(context, 'Could not load feeding payments. $e');
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  Future<void> _void(Map<String, dynamic> p) async {
    final reason = await _askReason(
      context,
      title: 'Void this feeding payment?',
      summary: '${_money(p['amount'])} · ${p['student'] ?? ''} · ${p['paid_for'] ?? ''} · ${p['receipt_number'] ?? ''}',
      note: 'Unpaid days it paid for become unpaid again and the days paid ahead are taken back. '
          'It stays on record, marked voided. This cannot be undone.',
      action: 'Void payment',
    );
    if (reason == null || !mounted) return;
    try {
      await FeedingApi.voidFeedingPayment('${p['id']}', reason);
      if (mounted) showSnack(context, 'Receipt ${p['receipt_number'] ?? ''} voided');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not void the payment. $e');
    }
  }

  Widget _filter(String label, String value, List<(String, String)> options, ValueChanged<String> onChanged) {
    return SizedBox(
      width: 170,
      child: AppSelect(
        label: label,
        value: options.firstWhere((o) => o.$1 == value, orElse: () => options.first).$2,
        items: [for (final o in options) o.$2],
        onChanged: (picked) {
          onChanged(options.firstWhere((o) => o.$2 == picked).$1);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CounterSection(
      title: 'Feeding payments',
      action: SmallAction(label: 'Refresh', icon: Icons.refresh_rounded, onTap: _load),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _load);
            },
            decoration: appFieldDecoration(context, hint: 'Search child or receipt…')
                .copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 18)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              _filter('Method', _method, const [('', 'Cash and MoMo'), ('cash', 'Cash'), ('mobile_money', 'Mobile money')],
                  (v) => _method = v),
              if (_seeAll && _cashiers.isNotEmpty)
                _filter('Cashier', _cashier, [('', 'Every cashier'), for (final c in _cashiers) ('${c['id']}', '${c['name'] ?? ''}')],
                    (v) => _cashier = v),
              _filter('Status', _status, const [('all', 'All'), ('counted', 'Counted only'), ('voided', 'Voided only')],
                  (v) => _status = v),
            ],
          ),
          if (_rows.isEmpty && !_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Center(child: MutedText('No feeding payments to show.'))),
          for (final p in _rows) _row(p),
          if (_loading)
            _spinner()
          else if (_page < _lastPage)
            Center(child: TextButton(onPressed: () => _load(more: true), child: const Text('Show more'))),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> p) {
    final voided = p['voided'] == true;
    return Opacity(
      opacity: voided ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: _rowBox(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    textOf(p['student']) ?? '—',
                    style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context)),
                  ),
                ),
                Text(
                  _money(p['amount']),
                  style: AppText.body(size: 14, weight: FontWeight.w800, color: AppSurface.ink(context))
                      .copyWith(decoration: voided ? TextDecoration.lineThrough : null),
                ),
              ],
            ),
            const SizedBox(height: 2),
            MutedText(
              [
                stampLabel(p['paid_at']),
                'For ${p['paid_for'] ?? ''}',
                p['method'] == 'mobile_money' ? 'MoMo' : 'Cash',
                if (_seeAll && textOf(p['cashier']) != null) 'by ${textOf(p['cashier'])}',
                '${p['receipt_number'] ?? ''}',
              ].join(' · '),
              size: 12,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                voided ? const FeedBadge('Voided') : const FeedBadge('Counted', tone: 'green'),
                if (voided && textOf(p['void_reason']) != null) MutedText(textOf(p['void_reason'])!, size: 12),
                ReceiptButton(paymentId: '${p['id'] ?? ''}', receiptNumber: '${p['receipt_number'] ?? ''}'),
                if (!voided && FeedingAccess.voidFeeding(widget.user))
                  OutlinedButton(
                    onPressed: () => _void(p),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Void'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Cash-up ─────────────────────────────

class FeedingCashupTab extends StatefulWidget {
  const FeedingCashupTab({super.key, required this.currency});

  final String currency;

  @override
  State<FeedingCashupTab> createState() => _FeedingCashupTabState();
}

class _FeedingCashupTabState extends State<FeedingCashupTab> {
  DateTime _day = DateTime.now();
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;

  String _money(dynamic v) => money(v, widget.currency);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await FeedingApi.cashups(dateKey(_day));
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not load the cash-up. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2024), lastDate: DateTime.now());
    if (picked == null) return;
    setState(() => _day = picked);
    _load();
  }

  Future<void> _receive(Map<String, dynamic> row) async {
    final amount = TextEditingController(text: numOf(row['received'] ?? row['cash']).toStringAsFixed(2));
    final note = TextEditingController(text: textOf(row['note']) ?? '');
    final save = await showAppSheet<bool>(
      context: context,
      title: 'Cash received from ${textOf(row['cashier']) ?? 'cashier'}',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${dayLabel(dateKey(_day))} · cash collected ${_money(row['cash'])}', style: AppText.body(size: 13.5, color: AppColors.slate700)),
          const SizedBox(height: 12),
          AppFieldLabel('Cash received (${widget.currency})', required: true),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            decoration: appFieldDecoration(ctx),
          ),
          const SizedBox(height: 10),
          const AppFieldLabel('Note'),
          TextField(controller: note, maxLength: 255, decoration: appFieldDecoration(ctx, hint: 'e.g. GHS 5 short, will bring tomorrow')),
          const SizedBox(height: 10),
          AppModalButton(label: 'Save', onPressed: () => closeRoute(ctx, true)),
        ],
      ),
    );
    if (save != true || !mounted) return;
    final value = double.tryParse(amount.text);
    if (value == null || value < 0) {
      showSnack(context, 'Enter the cash received.');
      return;
    }
    try {
      await FeedingApi.saveCashup({
        'cashier_id': row['cashier_id'],
        'date': dateKey(_day),
        'received_amount': value,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      });
      if (mounted) showSnack(context, 'Cash from ${textOf(row['cashier']) ?? 'the cashier'} recorded');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save the cash-up. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CounterSection(
      title: 'Cash-up',
      action: SmallAction(label: dayLabel(dateKey(_day)), icon: Icons.event_rounded, onTap: _pickDay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MutedText(
            'What each cashier collected on the day, and the cash you received from them. '
            'Only cash is counted in the difference: mobile money isn’t handed over.',
            size: 12,
          ),
          const SizedBox(height: 10),
          if (_loading)
            _spinner()
          else if (_rows.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Center(child: MutedText('No money was recorded by a cashier on this day.')))
          else
            for (final r in _rows) _row(r),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final diff = r['difference'] == null ? null : numOf(r['difference']);
    final (diffText, diffColor) = diff == null
        ? ('—', AppSurface.muted(context))
        : diff == 0
            ? ('Balanced', const Color(0xFF15803D))
            : diff < 0
                ? ('Short ${_money(diff.abs())}', const Color(0xFFB91C1C))
                : ('Over ${_money(diff)}', const Color(0xFFB45309));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _rowBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(textOf(r['cashier']) ?? '—',
                    style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.ink(context))),
              ),
              OutlinedButton(
                onPressed: () => _receive(r),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(r['received'] == null ? 'Receive' : 'Change'),
              ),
            ],
          ),
          MutedText('${plural(intOf(r['count']), 'payment')} · cash ${_money(r['cash'])} · MoMo ${_money(r['mobile_money'])}', size: 12),
          if (numOf(r['fees_cash']) > 0)
            MutedText('Cash: fees ${_money(r['fees_cash'])} · feeding ${_money(r['feeding_cash'])}', size: 11.5),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              r['received'] == null
                  ? const FeedBadge('Not received', tone: 'amber')
                  : Text('Received ${_money(r['received'])}', style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppSurface.ink(context))),
              if (textOf(r['received_by']) != null) MutedText('by ${textOf(r['received_by'])}', size: 12),
              Text(diffText, style: AppText.body(size: 12.5, weight: FontWeight.w700, color: diffColor)),
            ],
          ),
          if (textOf(r['note']) != null) MutedText(textOf(r['note'])!, size: 12),
        ],
      ),
    );
  }
}

// ───────────────────────────── Report ─────────────────────────────

class FeedingReportTab extends StatefulWidget {
  const FeedingReportTab({super.key, required this.currency});

  final String currency;

  @override
  State<FeedingReportTab> createState() => _FeedingReportTabState();
}

class _FeedingReportTabState extends State<FeedingReportTab> {
  Map<String, dynamic>? _data;
  String? _error;

  String _money(dynamic v) => money(v, widget.currency);

  @override
  void initState() {
    super.initState();
    FeedingApi.report().then((d) {
      if (mounted) setState(() => _data = d);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = 'Could not load the report. $e');
    });
  }

  Widget _childRow(String name, String meta, String trailing, {bool owed = false}) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: _rowBox(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context))),
                  MutedText(meta, size: 12),
                ],
              ),
            ),
            Text(trailing,
                style: AppText.body(size: 13, weight: FontWeight.w700, color: owed ? const Color(0xFFB91C1C) : AppSurface.ink(context))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return _error != null ? MutedText(_error!) : _spinner();
    final periods = FeedingApi.rows(d['periods']);
    final notPaid = FeedingApi.rows(d['not_paid_today']);
    final unpaid = FeedingApi.rows(d['unpaid']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CounterSection(
          title: 'Feeding money collected',
          child: TileGrid(
            minWidth: 150,
            children: [
              for (final p in periods)
                TakingsTile(
                  label: '${p['label'] ?? ''}',
                  value: _money(p['total']),
                  sub: 'Cash ${_money(p['cash'])} · MoMo ${_money(p['mobile_money'])} · ${plural(intOf(p['count']), 'payment')}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CounterSection(
          title: 'Present today and not paid (${notPaid.length})',
          child: notPaid.isEmpty
              ? const MutedText('Everyone present today is covered.')
              : Column(children: [
                  for (final c in notPaid)
                    _childRow(
                      '${c['full_name'] ?? ''}',
                      '${textOf(c['class_name']) ?? '—'} · ${_money(c['rate'])}/day',
                      intOf(c['unpaid_days']) > 0 ? '${plural(intOf(c['unpaid_days']), 'day')} · ${_money(c['unpaid_amount'])}' : 'None',
                      owed: intOf(c['unpaid_days']) > 0,
                    ),
                ]),
        ),
        const SizedBox(height: 14),
        CounterSection(
          title: 'Unpaid days · ${_money(d['unpaid_total'])} owed',
          child: unpaid.isEmpty
              ? const MutedText('No unpaid feeding days.')
              : Column(children: [
                  for (final c in unpaid)
                    _childRow(
                      '${c['full_name'] ?? ''}',
                      [textOf(c['admission_number']), textOf(c['class_name']), '${plural(intOf(c['days']), 'day')} since ${dayLabel(c['since'])}']
                          .whereType<String>()
                          .join(' · '),
                      _money(c['amount']),
                      owed: true,
                    ),
                ]),
        ),
      ],
    );
  }
}

// ───────────────────────────── Rates & days ─────────────────────────────

class FeedingSettingsTab extends StatefulWidget {
  const FeedingSettingsTab({super.key, required this.currency});

  final String currency;

  @override
  State<FeedingSettingsTab> createState() => _FeedingSettingsTabState();
}

class _RateRow {
  _RateRow({required this.scope, this.scopeId = '', String daily = '', String week = '', String month = ''})
      : daily = TextEditingController(text: daily),
        week = TextEditingController(text: week),
        month = TextEditingController(text: month);

  final String scope;
  String scopeId;
  final TextEditingController daily;
  final TextEditingController week;
  final TextEditingController month;

  void dispose() {
    daily.dispose();
    week.dispose();
    month.dispose();
  }
}

class _FeedingSettingsTabState extends State<FeedingSettingsTab> {
  static const _weekdays = [(1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'), (5, 'Fri'), (6, 'Sat'), (7, 'Sun')];

  Map<String, dynamic>? _data;
  DateTime? _start;
  List<int> _days = [];
  List<_RateRow> _rates = [];
  String? _saving;
  String? _error;

  @override
  void initState() {
    super.initState();
    FeedingApi.settings().then(_apply).catchError((Object e) {
      if (mounted) setState(() => _error = 'Could not load the feeding settings. $e');
    });
  }

  @override
  void dispose() {
    for (final r in _rates) {
      r.dispose();
    }
    super.dispose();
  }

  String _num(dynamic v) => v == null ? '' : numOf(v).toString().replaceAll(RegExp(r'\.0$'), '');

  void _apply(Map<String, dynamic> d) {
    if (!mounted) return;
    for (final r in _rates) {
      r.dispose();
    }
    final rates = [
      for (final r in FeedingApi.rows(d['rates']))
        _RateRow(
          scope: '${r['scope']}',
          scopeId: '${r['scope_id'] ?? ''}',
          daily: _num(r['daily_rate']),
          week: _num(r['week_price']),
          month: _num(r['month_price']),
        ),
    ];
    if (!rates.any((r) => r.scope == 'school')) rates.insert(0, _RateRow(scope: 'school'));
    setState(() {
      _data = d;
      _start = DateTime.tryParse('${d['start_date'] ?? ''}');
      _days = [for (final x in (d['feeding_days'] as List? ?? const [])) intOf(x)]..sort();
      _rates = rates;
    });
  }

  Future<void> _saveDays() async {
    setState(() => _saving = 'days');
    try {
      _apply(await FeedingApi.saveSettings({'start_date': dateKey(_start!), 'feeding_days': _days}));
      if (mounted) showSnack(context, 'Feeding days saved');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save the feeding days. $e');
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  bool get _ratesValid =>
      _rates.every((r) => r.scope == 'school' || (r.scopeId.isNotEmpty && (double.tryParse(r.daily.text) ?? 0) > 0));

  Future<void> _saveRates() async {
    setState(() => _saving = 'rates');
    try {
      final body = [
        for (final r in _rates)
          if (r.daily.text.trim().isNotEmpty || r.scope != 'school')
            {
              'scope': r.scope,
              'scope_id': r.scope == 'school' ? null : r.scopeId,
              'daily_rate': r.daily.text.trim(),
              'week_price': r.week.text.trim().isEmpty ? null : r.week.text.trim(),
              'month_price': r.month.text.trim().isEmpty ? null : r.month.text.trim(),
            },
      ];
      _apply(await FeedingApi.saveRates(body));
      if (mounted) showSnack(context, 'Rates saved');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save the rates. $e');
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Widget _money(TextEditingController c, String hint) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          decoration: appFieldDecoration(context, hint: hint),
          onChanged: (_) => setState(() {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return _error != null ? MutedText(_error!) : _spinner();
    final departments = FeedingApi.rows(d['departments']);
    final classes = FeedingApi.rows(d['classes']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CounterSection(
          title: 'Feeding days',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Days children are fed', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (value, label) in _weekdays)
                    FilterChip(
                      label: Text(label),
                      selected: _days.contains(value),
                      onSelected: (on) => setState(() => on ? (_days = [..._days, value]..sort()) : _days.remove(value)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const MutedText('Holidays on the School Calendar are skipped. A day on which no attendance was taken at all is skipped too.',
                  size: 12),
              const SizedBox(height: 12),
              Text('Start counting from', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _start ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _start = picked);
                },
                icon: const Icon(Icons.event_rounded, size: 16),
                label: Text(_start == null ? 'Pick a date' : dayLabel(dateKey(_start!))),
              ),
              const MutedText('Nobody owes for days before this.', size: 12),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving != null || _days.isEmpty || _start == null ? null : _saveDays,
                child: Text(_saving == 'days' ? 'Saving…' : 'Save feeding days'),
              ),
              if (d['saved'] != true)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Not saved yet: unpaid days are only counted once you save.',
                      style: TextStyle(color: Color(0xFFB45309), fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CounterSection(
          title: 'Rates',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MutedText(
                'A class rate is used before a department rate, which is used before the school rate. '
                'Week and month prices are optional (a discount for paying at once); without one it is the daily rate × '
                '${d['week_days'] ?? 5} days a week or × the feeding days in the month (${d['month_days'] ?? '—'} this month).',
                size: 12,
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _rates.length; i++) _rateRow(i, departments, classes),
              Wrap(
                spacing: 8,
                children: [
                  if (departments.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _rates.add(_RateRow(scope: 'department'))),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Department rate'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _rates.add(_RateRow(scope: 'class'))),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Class rate'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const MutedText(
                'Leave the whole-school rate empty if only some classes pay for feeding. Children in a class with no rate are not charged.',
                size: 12,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving != null || !_ratesValid ? null : _saveRates,
                child: Text(_saving == 'rates' ? 'Saving…' : 'Save rates'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rateRow(int i, List<Map<String, dynamic>> departments, List<Map<String, dynamic>> classes) {
    final r = _rates[i];
    final options = r.scope == 'department' ? departments : classes;
    final taken = {
      for (var j = 0; j < _rates.length; j++)
        if (j != i && _rates[j].scope == r.scope) _rates[j].scopeId,
    };
    final placeholder = r.scope == 'department' ? 'Pick a department…' : 'Pick a class…';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: _rowBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: r.scope == 'school'
                    ? Text('Whole school', style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context)))
                    : AppSelect(
                        label: r.scope == 'department' ? 'Department' : 'Class',
                        value: options.firstWhere((o) => '${o['id']}' == r.scopeId, orElse: () => const {})['name']?.toString() ??
                            placeholder,
                        items: [
                          placeholder,
                          for (final o in options)
                            if (!taken.contains('${o['id']}')) '${o['name'] ?? ''}',
                        ],
                        onChanged: (name) => setState(() {
                          r.scopeId = '${options.firstWhere((o) => '${o['name']}' == name, orElse: () => const {})['id'] ?? ''}';
                        }),
                      ),
              ),
              if (r.scope != 'school')
                IconButton(
                  tooltip: 'Remove rate',
                  onPressed: () => setState(() {
                    _rates.removeAt(i).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _money(r.daily, r.scope == 'school' ? 'Daily · not charged' : 'Daily rate'),
              const SizedBox(width: 8),
              _money(r.week, 'Week (optional)'),
              const SizedBox(width: 8),
              _money(r.month, 'Month (optional)'),
            ],
          ),
        ],
      ),
    );
  }
}
