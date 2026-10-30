import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/receipt_file.dart';
import '../feeding.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/feeding_widgets.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart' show showSnack;

/// School spending, as on the website's Expenses page: totals by category,
/// a filtered list, and record / edit / void with an optional receipt photo.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.user, this.onBack, required this.onLogout});

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

const _methods = [('cash', 'Cash'), ('mobile_money', 'Mobile money'), ('bank_transfer', 'Bank transfer'), ('cheque', 'Cheque')];

String _methodLabel(dynamic m) => _methods.firstWhere((x) => x.$1 == '$m', orElse: () => ('', '$m')).$2;

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _currency = schoolCurrency();
  final _search = TextEditingController();
  String _term = '';
  String _category = '';
  String _method = '';
  String _status = 'all';
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _terms = const [];
  final List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _totals;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  int _seq = 0;

  String _money(dynamic v) => money(v, _currency);
  List<Map<String, dynamic>> get _active => [for (final c in _categories) if (c['is_active'] != false) c];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    FeedingApi.academicTerms().then((t) {
      if (mounted) setState(() => _terms = t);
    }).catchError((_) {});
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final c = await FeedingApi.expenseCategories();
      if (mounted) setState(() => _categories = c);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the expense categories. $e');
    }
  }

  Future<void> _load({bool more = false}) async {
    final seq = ++_seq;
    final page = more ? _page + 1 : 1;
    setState(() => _loading = true);
    try {
      final body = await FeedingApi.expenses({
        'page': '$page',
        'per_page': '25',
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        if (_term.isNotEmpty) 'academic_term_id': _term,
        if (_category.isNotEmpty) 'expense_category_id': _category,
        if (_method.isNotEmpty) 'payment_method': _method,
        'status': _status,
      });
      if (!mounted || seq != _seq) return;
      final meta = body['meta'] is Map ? body['meta'] as Map : const {};
      setState(() {
        _error = null;
        if (!more) _rows.clear();
        _rows.addAll(FeedingApi.rows(body['data']));
        _totals = body['totals'] is Map ? Map<String, dynamic>.from(body['totals'] as Map) : null;
        _page = page;
        _lastPage = intOf(meta['last_page']) > 0 ? intOf(meta['last_page']) : page;
      });
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = 'Could not load expenses. $e');
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  Widget _filter(String label, String value, List<(String, String)> options, ValueChanged<String> onChanged) {
    return SizedBox(
      width: 165,
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

  Future<void> _edit([Map<String, dynamic>? expense]) async {
    final saved = await showAppSheet<bool>(
      context: context,
      title: expense == null ? 'Record expense' : 'Edit expense',
      builder: (_) => _ExpenseForm(expense: expense, categories: _categories, currency: _currency),
    );
    if (saved == true) await _load();
  }

  Future<void> _void(Map<String, dynamic> e) async {
    final reason = TextEditingController();
    final ok = await showAppSheet<bool>(
      context: context,
      title: 'Void this expense?',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [_money(e['amount']), textOf(e['category']), textOf(e['paid_to']), dayLabel(e['spent_on'])].whereType<String>().join(' · '),
              style: AppText.body(size: 13.5, color: AppColors.slate700),
            ),
            const SizedBox(height: 12),
            const AppFieldLabel('Reason', required: true),
            TextField(
              controller: reason,
              maxLength: 255,
              decoration: appFieldDecoration(ctx, hint: 'e.g. Entered twice'),
              onChanged: (_) => setState(() {}),
            ),
            Text('It stays on record, marked voided, and no longer counts in totals. This cannot be undone.',
                style: AppText.body(size: 12, color: AppColors.slate500)),
            const SizedBox(height: 14),
            AppModalButton(label: 'Void expense', onPressed: reason.text.trim().length < 3 ? null : () => closeRoute(ctx, true)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FeedingApi.voidExpense('${e['id']}', reason.text.trim());
      if (mounted) showSnack(context, 'Expense voided');
      await _load();
    } catch (err) {
      if (mounted) showSnack(context, 'Could not void the expense. $err');
    }
  }

  Future<void> _openReceipt(Map<String, dynamic> e) async {
    try {
      final bytes = await FeedingApi.expenseReceipt('${e['id']}');
      await openPdfBytes(bytes, 'expense-${e['id']}', mime: receiptMime(bytes));
    } catch (err) {
      if (mounted) showSnack(context, 'Could not open the receipt. $err');
    }
  }

  Future<void> _manageCategories() async {
    await showAppSheet<void>(
      context: context,
      title: 'Expense categories',
      builder: (_) => _CategoriesEditor(initial: _categories),
    );
    await _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    final filtered = _term.isNotEmpty || _category.isNotEmpty || _method.isNotEmpty || _status != 'all' || _search.text.trim().isNotEmpty;
    final u = widget.user;
    return Column(
      children: [
        AdminPageHeader(
          title: 'Expenses',
          subtitle: 'What the school spends',
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
                if (_error != null) ...[
                  MutedText(_error!),
                  const SizedBox(height: 12),
                ],
                TileGrid(
                  minWidth: 150,
                  children: [
                    TakingsTile(
                      label: 'Total spent',
                      value: _money(t?['amount']),
                      sub: '${plural(intOf(t?['count']), 'expense')}${filtered ? ' (filtered)' : ''}',
                    ),
                    for (final c in FeedingApi.rows(t?['by_category']))
                      TakingsTile(label: '${c['name'] ?? ''}', value: _money(c['amount']), sub: plural(intOf(c['count']), 'expense')),
                  ],
                ),
                const SizedBox(height: 14),
                CounterSection(
                  title: 'Expenses',
                  action: Wrap(
                    spacing: 6,
                    children: [
                      if (FeedingAccess.expenseCategories(u)) SmallAction(label: 'Categories', icon: Icons.label_outline_rounded, onTap: _manageCategories),
                      SmallAction(label: 'Refresh', icon: Icons.refresh_rounded, onTap: _load),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (FeedingAccess.createExpense(u)) ...[
                        FilledButton.icon(
                          onPressed: _active.isEmpty ? null : () => _edit(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Record expense'),
                        ),
                        if (_active.isEmpty && _categories.isNotEmpty)
                          const MutedText('Switch on a category first.', size: 12),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: _search,
                        onChanged: (_) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 300), _load);
                        },
                        decoration: appFieldDecoration(context, hint: 'Search paid to, description…')
                            .copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 18)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          if (_terms.isNotEmpty)
                            _filter('Term', _term, [
                              ('', 'All terms'),
                              for (final term in _terms)
                                ('${term['id']}', '${term['name'] ?? ''}${term['status'] == 'current' ? ' (current)' : ''}'),
                            ], (v) => _term = v),
                          _filter('Category', _category, [('', 'All categories'), for (final c in _categories) ('${c['id']}', '${c['name'] ?? ''}')],
                              (v) => _category = v),
                          _filter('Method', _method, [('', 'Any method'), ..._methods], (v) => _method = v),
                          _filter('Status', _status, const [('all', 'All'), ('counted', 'Counted only'), ('voided', 'Voided only')],
                              (v) => _status = v),
                        ],
                      ),
                      if (_rows.isEmpty && !_loading && _error == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(child: MutedText(filtered ? 'No expenses match these filters.' : 'No expenses recorded yet.')),
                        ),
                      for (final e in _rows) _row(e),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
                        )
                      else if (_page < _lastPage)
                        Center(child: TextButton(onPressed: () => _load(more: true), child: const Text('Show more'))),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> e) {
    final voided = textOf(e['voided_at']) != null;
    final u = widget.user;
    return Opacity(
      opacity: voided ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppSurface.cardSoft(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppSurface.line(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(textOf(e['paid_to']) ?? '—',
                      style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppSurface.ink(context))),
                ),
                Text(
                  _money(e['amount']),
                  style: AppText.body(size: 14, weight: FontWeight.w800, color: AppSurface.ink(context))
                      .copyWith(decoration: voided ? TextDecoration.lineThrough : null),
                ),
              ],
            ),
            MutedText(
              [dayLabel(e['spent_on']), textOf(e['category']), _methodLabel(e['payment_method']), if (textOf(e['recorded_by']) != null) 'by ${textOf(e['recorded_by'])}']
                  .whereType<String>()
                  .join(' · '),
              size: 12,
            ),
            if (textOf(e['description']) != null) MutedText(textOf(e['description'])!, size: 12),
            if (textOf(e['reference']) != null) MutedText('Ref ${textOf(e['reference'])}', size: 11.5),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                voided ? const FeedBadge('Voided') : const FeedBadge('Counted', tone: 'green'),
                if (voided && textOf(e['void_reason']) != null) MutedText(textOf(e['void_reason'])!, size: 12),
                if (textOf(e['receipt_url']) != null)
                  OutlinedButton.icon(
                    onPressed: () => _openReceipt(e),
                    icon: const Icon(Icons.receipt_long_rounded, size: 14),
                    label: const Text('Receipt'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                if (!voided && FeedingAccess.updateExpense(u))
                  OutlinedButton(
                    onPressed: () => _edit(e),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Edit'),
                  ),
                if (!voided && FeedingAccess.voidExpense(u))
                  OutlinedButton(
                    onPressed: () => _void(e),
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

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({this.expense, required this.categories, required this.currency});

  final Map<String, dynamic>? expense;
  final List<Map<String, dynamic>> categories;
  final String currency;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late final Map<String, dynamic> _e = widget.expense ?? const {};
  late DateTime _date = DateTime.tryParse('${_e['spent_on'] ?? ''}') ?? DateTime.now();
  late final _amount = TextEditingController(text: _e['amount'] == null ? '' : numOf(_e['amount']).toStringAsFixed(2));
  late final _paidTo = TextEditingController(text: textOf(_e['paid_to']) ?? '');
  late final _description = TextEditingController(text: textOf(_e['description']) ?? '');
  late final _reference = TextEditingController(text: textOf(_e['reference']) ?? '');
  late String _category = '${_e['expense_category_id'] ?? (_options.isEmpty ? '' : _options.first['id'])}';
  late String _method = '${_e['payment_method'] ?? 'cash'}';
  ({List<int> bytes, String filename})? _receipt;
  bool _removeReceipt = false;
  bool _saving = false;

  List<Map<String, dynamic>> get _options => [
        for (final c in widget.categories)
          if (c['is_active'] != false || '${c['id']}' == '${widget.expense?['expense_category_id']}') c,
      ];

  @override
  void dispose() {
    _amount.dispose();
    _paidTo.dispose();
    _description.dispose();
    _reference.dispose();
    super.dispose();
  }

  bool get _valid => _category.isNotEmpty && (double.tryParse(_amount.text) ?? 0) > 0;

  Future<void> _pickReceipt() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'That photo is over 5 MB.');
      return;
    }
    setState(() {
      _receipt = (bytes: bytes, filename: file.name);
      _removeReceipt = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FeedingApi.saveExpense(
        id: widget.expense == null ? null : '${widget.expense!['id']}',
        receipt: _receipt,
        fields: {
          'expense_category_id': _category,
          'spent_on': dateKey(_date),
          'amount': _amount.text.trim(),
          'payment_method': _method,
          'paid_to': _paidTo.text.trim(),
          'description': _description.text.trim(),
          'reference': _reference.text.trim(),
          if (_removeReceipt) 'remove_receipt': '1',
        },
      );
      if (!mounted) return;
      showSnack(context, widget.expense == null ? 'Expense recorded' : 'Expense updated');
      closeRoute(context, true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save the expense. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppFieldLabel('Date', required: true),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (picked != null) setState(() => _date = picked);
          },
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(dayLabel(dateKey(_date))),
        ),
        const SizedBox(height: 10),
        AppFieldLabel('Amount (${widget.currency})', required: true),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          decoration: appFieldDecoration(context),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        AppSelect(
          label: 'Category *',
          value: options.firstWhere((c) => '${c['id']}' == _category, orElse: () => const {})['name']?.toString() ?? '',
          items: [for (final c in options) '${c['name'] ?? ''}'],
          onChanged: (name) => setState(() => _category = '${options.firstWhere((c) => '${c['name']}' == name)['id']}'),
        ),
        AppSelect(
          label: 'How it was paid *',
          value: _methodLabel(_method),
          items: [for (final m in _methods) m.$2],
          onChanged: (label) => setState(() => _method = _methods.firstWhere((m) => m.$2 == label).$1),
        ),
        const AppFieldLabel('Paid to'),
        TextField(controller: _paidTo, maxLength: 150, decoration: appFieldDecoration(context, hint: 'e.g. ECG, Kofi the carpenter')),
        const AppFieldLabel('Description'),
        TextField(controller: _description, maxLength: 500, decoration: appFieldDecoration(context, hint: 'e.g. Electricity for October')),
        const AppFieldLabel('Reference'),
        TextField(controller: _reference, maxLength: 100, decoration: appFieldDecoration(context, hint: 'MoMo or bank reference, cheque number…')),
        const AppFieldLabel('Receipt photo (optional, up to 5 MB)'),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: const Icon(Icons.photo_outlined, size: 16),
              label: Text(_receipt == null ? 'Add photo' : 'Change photo'),
            ),
            const SizedBox(width: 8),
            if (_receipt != null) Expanded(child: Text(_receipt!.filename, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: AppColors.slate600))),
          ],
        ),
        if (widget.expense != null && textOf(widget.expense!['receipt_url']) != null && _receipt == null)
          CheckboxListTile(
            value: _removeReceipt,
            onChanged: (v) => setState(() => _removeReceipt = v ?? false),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Remove the current receipt (${textOf(widget.expense!['receipt_name']) ?? 'file'})'),
          ),
        const SizedBox(height: 14),
        AppModalButton(
          label: _saving ? 'Saving…' : (widget.expense == null ? 'Record expense' : 'Save changes'),
          onPressed: _saving || !_valid ? null : _save,
        ),
      ],
    );
  }
}

class _CategoriesEditor extends StatefulWidget {
  const _CategoriesEditor({required this.initial});

  final List<Map<String, dynamic>> initial;

  @override
  State<_CategoriesEditor> createState() => _CategoriesEditorState();
}

class _CategoriesEditorState extends State<_CategoriesEditor> {
  late List<Map<String, dynamic>> _items = widget.initial;
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final c = await FeedingApi.expenseCategories();
    if (mounted) setState(() => _items = c);
  }

  Future<void> _update(Map<String, dynamic> c, {String? name, bool? active}) async {
    try {
      await FeedingApi.updateExpenseCategory('${c['id']}', {'name': name ?? c['name'], 'is_active': active ?? c['is_active']});
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save the category. $e');
    }
  }

  Future<void> _create() async {
    final name = _add.text.trim();
    if (name.isEmpty) return;
    try {
      await FeedingApi.createExpenseCategory(name);
      _add.clear();
      if (mounted) showSnack(context, '“$name” added');
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not add the category. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('cat-${c['id']}-${c['name']}'),
                    initialValue: '${c['name'] ?? ''}',
                    maxLength: 80,
                    decoration: appFieldDecoration(context).copyWith(counterText: ''),
                    onFieldSubmitted: (v) {
                      if (v.trim().isNotEmpty && v.trim() != c['name']) _update(c, name: v.trim());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('In use', style: AppText.body(size: 12, color: AppColors.slate600)),
                Switch(value: c['is_active'] != false, onChanged: (on) => _update(c, active: on)),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(controller: _add, maxLength: 80, decoration: appFieldDecoration(context, hint: 'New category, e.g. Security').copyWith(counterText: '')),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _create, child: const Text('Add')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Rename a category and press Enter. Switch off “In use” to stop using it for new expenses — expenses already recorded under it are kept and still count.',
          style: AppText.body(size: 12, color: AppColors.slate500),
        ),
      ],
    );
  }
}
