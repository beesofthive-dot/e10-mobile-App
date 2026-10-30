import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../core/config/api_config.dart';
import '../core/receipt_file.dart';
import '../feeding.dart';
import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/feeding_widgets.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart' show showSnack;

/// A parent's report cards, laid out like the website's "Report cards for my
/// children": search, a child picker, each card's term and status, and View /
/// PDF once the school has published it.
class ParentReportCardsScreen extends StatefulWidget {
  const ParentReportCardsScreen({super.key, required this.user, this.onBack, required this.onLogout});

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<ParentReportCardsScreen> createState() => _ParentReportCardsScreenState();
}

class _ParentReportCardsScreenState extends State<ParentReportCardsScreen> {
  final _search = TextEditingController();
  String _child = '';
  final List<Map<String, dynamic>> _rows = [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  String? _error;
  String? _pdfFor;
  Timer? _debounce;
  int _seq = 0;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await ApiClient.instance.get(ApiConfig.reportCardsPath, query: {
        'per_page': '50',
        'page': '$page',
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        if (_child.isNotEmpty) 'student_id': _child,
      });
      if (!mounted || seq != _seq) return;
      final map = body is Map ? body : const {};
      final meta = map['meta'] is Map ? map['meta'] as Map : const {};
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(FeedingApi.rows(map['data']));
        _page = page;
        _lastPage = intOf(meta['last_page']) > 0 ? intOf(meta['last_page']) : page;
      });
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = 'Could not load report cards. $e');
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  bool _published(Map<String, dynamic> r) => r['published'] == true || textOf(r['published_at']) != null;

  String _student(Map<String, dynamic> r) =>
      textOf(r['student'] is Map ? (r['student'] as Map)['full_name'] : null) ?? textOf(r['student_id']) ?? 'Student';

  String _term(Map<String, dynamic> r) =>
      textOf(r['academic_term'] is Map ? (r['academic_term'] as Map)['name'] : null) ?? textOf(r['academic_term_id']) ?? 'Term';

  Future<void> _pdf(Map<String, dynamic> r) async {
    setState(() => _pdfFor = '${r['id']}');
    try {
      final bytes = await ApiClient.instance.getBytes(ApiConfig.url('report-cards/${r['id']}/pdf'), accept: 'application/pdf');
      await openPdfBytes(bytes, 'report-card-${_student(r)}-${_term(r)}');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the report card PDF. $e');
    } finally {
      if (mounted) setState(() => _pdfFor = null);
    }
  }

  Future<void> _view(Map<String, dynamic> r) async {
    await showAppSheet<void>(
      context: context,
      title: 'Report card',
      subtitle: '${_student(r)} · ${_term(r)}',
      builder: (_) => ReportCardDetail(id: '${r['id']}', onPdf: () => _pdf(r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kids = SchoolScope.of(context).linkedChildren(Role.parent);
    return Column(
      children: [
        AdminPageHeader(
          title: 'Report cards',
          subtitle: 'Report cards for my children',
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
                CounterSection(
                  title: 'Report cards for my children',
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
                        decoration: appFieldDecoration(context, hint: 'Search by student…')
                            .copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 18)),
                      ),
                      if (kids.length > 1) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              label: const Text('All children'),
                              selected: _child.isEmpty,
                              onSelected: (_) {
                                setState(() => _child = '');
                                _load();
                              },
                            ),
                            for (final k in kids)
                              ChoiceChip(
                                label: Text(k.name),
                                selected: _child == k.id,
                                onSelected: (_) {
                                  setState(() => _child = k.id);
                                  _load();
                                },
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_error != null) MutedText(_error!),
                      if (_rows.isEmpty && !_loading && _error == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: MutedText(_search.text.trim().isNotEmpty ? 'No matching report cards' : 'No report cards'),
                          ),
                        ),
                      for (final r in _rows) _row(r),
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

  Widget _row(Map<String, dynamic> r) {
    final published = _published(r);
    final remark = textOf(r['teacher_remark']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              Expanded(
                child: Text(_student(r), style: AppText.body(size: 14.5, weight: FontWeight.w700, color: AppSurface.ink(context))),
              ),
              published
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF1A9E6E)),
                        const SizedBox(width: 4),
                        Text('Published', style: AppText.body(size: 12, weight: FontWeight.w700, color: const Color(0xFF1A9E6E))),
                      ],
                    )
                  : r['submitted'] == true
                      ? const FeedBadge('Ready for review', tone: 'blue')
                      : const FeedBadge('Draft'),
            ],
          ),
          const SizedBox(height: 2),
          MutedText(_term(r), size: 12.5),
          if (remark != null) ...[
            const SizedBox(height: 6),
            Text('“$remark”', style: AppText.body(size: 12.5, color: AppSurface.ink(context)).copyWith(fontStyle: FontStyle.italic)),
          ],
          if (published) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _view(r),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
                OutlinedButton.icon(
                  onPressed: _pdfFor == '${r['id']}' ? null : () => _pdf(r),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: Text(_pdfFor == '${r['id']}' ? 'Opening…' : 'PDF'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            const MutedText('Available once the school publishes it.', size: 12),
          ],
        ],
      ),
    );
  }
}

/// One report card, laid out like the website's "Report card" window.
class ReportCardDetail extends StatefulWidget {
  const ReportCardDetail({super.key, required this.id, required this.onPdf});

  final String id;
  final VoidCallback onPdf;

  @override
  State<ReportCardDetail> createState() => _ReportCardDetailState();
}

class _ReportCardDetailState extends State<ReportCardDetail> {
  Map<String, dynamic>? _card;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.get('${ApiConfig.reportCardsPath}/${widget.id}').then((body) {
      final data = body is Map ? body['data'] : null;
      if (mounted) setState(() => _card = data is Map ? Map<String, dynamic>.from(data) : const {});
    }).catchError((Object e) {
      if (mounted) setState(() => _error = 'Could not load the report card. $e');
    });
  }

  String _score(dynamic v) {
    if (v == null || '$v'.trim().isEmpty) return '—';
    final n = num.tryParse('$v');
    if (n == null) return '$v';
    return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
  }

  String _attendance(Map<String, dynamic> c) {
    final summary = textOf(c['attendance_summary']);
    final rate = num.tryParse('${c['attendance_rate'] ?? ''}');
    if (summary != null) return rate == null ? summary : '$summary (${(rate * 100).round()}%)';
    if (c['attendance_days_available'] != null) return '${intOf(c['attendance_days_attended'])}/${intOf(c['attendance_days_available'])}';
    if (rate == null) return '—';
    return rate <= 1 ? '${(rate * 100).round()}%' : '$rate%';
  }

  Widget _fact(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.slate500, letterSpacing: 0.5)),
              const SizedBox(height: 3),
              Text(value, style: AppText.body(size: 13.5, weight: FontWeight.w700, color: AppColors.slate800)),
            ],
          ),
        ),
      );

  Widget _remark(String label, String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.slate500, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(text, style: AppText.body(size: 13.5, color: AppColors.slate800)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = _card;
    if (c == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _error != null
            ? Text(_error!, style: AppText.body(size: 13, color: AppColors.slate600))
            : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    final lines = FeedingApi.rows(c['lines']);
    final head = AppText.body(size: 11.5, weight: FontWeight.w700, color: AppColors.slate600);
    final cell = AppText.body(size: 12.5, color: AppColors.slate800);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: widget.onPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('Open PDF'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _fact('Issued', dayLabel(c['issued_date'])),
            const SizedBox(width: 8),
            _fact('Attendance', _attendance(c)),
            const SizedBox(width: 8),
            _fact('Promotion', (textOf(c['promotion_status']) ?? '—').replaceAll('_', ' ')),
          ],
        ),
        const SizedBox(height: 12),
        if (textOf(c['teacher_remark']) != null) _remark('Teacher remark', textOf(c['teacher_remark'])!),
        if (textOf(c['headteacher_remark']) != null) _remark('Headteacher remark', textOf(c['headteacher_remark'])!),
        Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(AppColors.slate50),
              headingRowHeight: 38,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 18,
              columns: [
                for (final h in ['Subject', 'Class score', 'Exam score', 'Total', 'Grade', 'Remark']) DataColumn(label: Text(h, style: head)),
              ],
              rows: lines.isEmpty
                  ? [
                      DataRow(cells: [
                        DataCell(Text('No subject results recorded', style: cell.copyWith(color: AppColors.slate500))),
                        for (var i = 0; i < 5; i++) const DataCell(SizedBox.shrink()),
                      ]),
                    ]
                  : [
                      for (final l in lines)
                        DataRow(cells: [
                          DataCell(Text(
                            textOf(l['subject'] is Map ? (l['subject'] as Map)['name'] : null) ?? textOf(l['subject_id']) ?? '—',
                            style: cell.copyWith(fontWeight: FontWeight.w600),
                          )),
                          DataCell(Text(_score(l['class_score']), style: cell)),
                          DataCell(Text(_score(l['exam_score']), style: cell)),
                          DataCell(Text(_score(l['score']), style: cell.copyWith(fontWeight: FontWeight.w700))),
                          DataCell(Text(textOf(l['grade']) ?? '—', style: cell.copyWith(fontWeight: FontWeight.w700))),
                          DataCell(Text(textOf(l['remark']) ?? '—', style: cell)),
                        ]),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}
