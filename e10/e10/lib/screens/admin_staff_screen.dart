import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../core/config/api_config.dart';
import '../feeding.dart' show FeedingApi, textOf;
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';

/// Admin directory of every staff member (teachers, bursars, cashiers,
/// nurses, drivers…) from `/staff`, with search, a category filter and a
/// details page per person: contact, work, classes, subjects and today's
/// clock-in.
class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

const _categoryLabels = {
  'teacher': 'Teacher',
  'admin': 'Administration',
  'accountant': 'Accounts',
  'driver': 'Driver',
  'security': 'Security',
  'cleaner': 'Cleaner',
  'nurse': 'Nurse',
  'other': 'Other',
};

String _titleCase(String s) => s
    .split(RegExp(r'[_\s]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _category(Map<String, dynamic> row) => (textOf(row['category']) ?? 'other').toLowerCase();

String _categoryLabel(String c) => _categoryLabels[c] ?? _titleCase(c);

String _name(Map<String, dynamic> row) => textOf(row['full_name']) ?? 'Staff member';

List<String> _departments(Map<String, dynamic> row) => [
      for (final d in FeedingApi.rows(row['departments'])) textOf(d['name']) ?? '',
      if (row['departments'] is! List && row['department'] is Map) textOf((row['department'] as Map)['name']) ?? '',
    ].where((n) => n.isNotEmpty).toList();

List<String> _roles(Map<String, dynamic> row) => [
      for (final r in FeedingApi.rows(row['roles'])) textOf(r['name']) ?? _titleCase(textOf(r['slug']) ?? ''),
    ].where((n) => n.isNotEmpty).toList();

(String, Color, Color) _statusLook(String? status) => switch ((status ?? 'active').toLowerCase()) {
      'active' => ('Active', const Color(0xFFECFDF5), const Color(0xFF047857)),
      'on_leave' => ('On leave', const Color(0xFFFFFBEB), const Color(0xFFB45309)),
      'inactive' => ('Inactive', const Color(0xFFF1F5F9), AppColors.slate500),
      final s => (_titleCase(s), const Color(0xFFF1F5F9), AppColors.slate500),
    };

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  String _search = '';
  String _filter = 'all';
  Map<String, dynamic>? _open;

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open != null) {
      return _StaffDetails(
        key: ValueKey('staff-${open['id']}'),
        row: open,
        onBack: () => setState(() => _open = null),
      );
    }
    final store = SchoolScope.of(context);
    final all = [...store.tableRows('staff')]..sort((a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));
    final counts = <String, int>{};
    for (final row in all) {
      counts.update(_category(row), (n) => n + 1, ifAbsent: () => 1);
    }
    final q = _search.trim().toLowerCase();
    final shown = [
      for (final row in all)
        if ((_filter == 'all' || _category(row) == _filter) &&
            (q.isEmpty ||
                [_name(row), textOf(row['position']), textOf(row['phone']), textOf(row['email']), ..._departments(row)]
                    .any((v) => (v ?? '').toLowerCase().contains(q))))
          row,
    ];

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Staff',
            subtitle: '${all.length} staff members',
            onBack: widget.onBack,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => store.syncFromApi(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppLayout.page(context),
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search name, position, phone or department',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (key, label) in [
                        ('all', 'All (${all.length})'),
                        for (final c in counts.keys.toList()..sort()) (c, '${_categoryLabel(c)} (${counts[c]})'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _filter == key,
                          onSelected: (_) => setState(() => _filter = key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (shown.isEmpty)
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        all.isEmpty ? 'No staff records yet.' : 'No staff match your search.',
                        style: AppText.body(size: 13, color: AppColors.slate500),
                      ),
                    )
                  else
                    for (final row in shown) ...[
                      _StaffTile(row: row, onTap: () => setState(() => _open = row)),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({required this.row, required this.onTap});

  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (statusText, statusBg, statusFg) = _statusLook(textOf(row['status']));
    final line = [textOf(row['position']) ?? _categoryLabel(_category(row)), ..._departments(row)].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              InitialsAvatar(name: _name(row), tone: Tone.sky),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name(row), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(weight: FontWeight.w800)),
                    Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, color: AppColors.slate400)),
                    if (textOf(row['phone']) != null)
                      Text(textOf(row['phone'])!, style: AppText.body(size: 10, color: AppColors.slate400)),
                  ],
                ),
              ),
              if (statusText != 'Active') ...[
                _Pill(text: statusText, bg: statusBg, fg: statusFg),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: AppText.body(size: 10, weight: FontWeight.w800, color: fg)),
      );
}

/// One staff member's full details.
class _StaffDetails extends StatefulWidget {
  const _StaffDetails({super.key, required this.row, required this.onBack});

  final Map<String, dynamic> row;
  final VoidCallback onBack;

  @override
  State<_StaffDetails> createState() => _StaffDetailsState();
}

class _StaffDetailsState extends State<_StaffDetails> {
  List<Map<String, dynamic>>? _assignments;
  Map<String, dynamic>? _today;
  bool _todayLoaded = false;

  String get _id => '${widget.row['id'] ?? ''}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final store = SchoolScope.of(context);
    final now = DateTime.now();
    final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await Future.wait([
      () async {
        try {
          final rows = <Map<String, dynamic>>[];
          for (var page = 1; page <= 20; page++) {
            final body = await ApiClient.instance.get(ApiConfig.teacherSubjectAssignmentsPath,
                query: {'staff_id': _id, 'per_page': '100', 'page': '$page'});
            rows.addAll(FeedingApi.rows(body is Map ? body['data'] : body));
            final meta = body is Map ? body['meta'] : null;
            final last = meta is Map ? int.tryParse('${meta['last_page'] ?? 1}') ?? 1 : 1;
            if (page >= last) break;
          }
          if (mounted) setState(() => _assignments = [for (final r in rows) if (_staffIdOf(r) == _id) r]);
        } catch (_) {
          if (mounted) setState(() => _assignments = const []);
        }
      }(),
      () async {
        final rows = await store.staffAttendanceFor(day);
        if (!mounted) return;
        setState(() {
          _todayLoaded = true;
          _today = rows?.where((r) => _staffIdOf(r) == _id).firstOrNull;
        });
      }(),
    ]);
  }

  static String _staffIdOf(Map<String, dynamic> r) =>
      '${r['staff_id'] ?? (r['staff'] is Map ? (r['staff'] as Map)['id'] : '')}';

  List<String> _homerooms(SchoolStore store) {
    final name = _name(widget.row).toLowerCase();
    final out = <String>{};
    for (final c in store.tableRows('school_classes')) {
      final label = [textOf(c['name']), textOf(c['stream'])].whereType<String>().join(' · ');
      final ids = [
        if (textOf(c['class_teacher_id']) != null) textOf(c['class_teacher_id'])!,
        if (c['teacher_ids'] is List) for (final id in c['teacher_ids'] as List) '$id',
        for (final t in FeedingApi.rows(c['teachers'])) '${t['id']}',
      ];
      if (ids.contains(_id)) out.add(label);
    }
    for (final c in store.classes) {
      if (c.link.trim().toLowerCase() == name && name.isNotEmpty) out.add(c.name);
    }
    return out.where((s) => s.isNotEmpty).toList()..sort();
  }

  static String _clock(dynamic raw) {
    final t = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (t == null) return '';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
  }

  static String _date(dynamic raw) {
    final t = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (t == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${months[t.month - 1]} ${t.year}';
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final row = widget.row;
    final phone = textOf(row['phone']);
    final email = textOf(row['email']);
    final (statusText, statusBg, statusFg) = _statusLook(textOf(row['status']));
    final homerooms = _homerooms(store);
    final subjects = <String, Set<String>>{};
    for (final a in _assignments ?? const <Map<String, dynamic>>[]) {
      final subject = (a['subject'] is Map ? textOf((a['subject'] as Map)['name']) : null) ?? 'Subject';
      final klass = a['class'] ?? a['school_class'];
      final className = klass is Map
          ? [textOf(klass['name']), textOf(klass['stream'])].whereType<String>().join(' · ')
          : store.classes.where((c) => c.id == '${a['class_id']}').firstOrNull?.name ?? '';
      subjects.putIfAbsent(subject, () => <String>{});
      if (className.isNotEmpty) subjects[subject]!.add(className);
    }

    final today = _today;
    final String todayText;
    if (!_todayLoaded) {
      todayText = 'Loading…';
    } else if (today == null) {
      todayText = 'No clock-in recorded today';
    } else {
      final status = _titleCase(textOf(today['status']) ?? '');
      final inAt = _clock(today['check_in_at']);
      final outAt = _clock(today['check_out_at']);
      todayText = [
        if (status.isNotEmpty) status,
        if (inAt.isNotEmpty) 'In $inAt',
        if (outAt.isNotEmpty) 'Out $outAt',
      ].join(' · ');
    }

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(title: _name(row), subtitle: 'Staff details', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: AppLayout.page(context),
              children: [
                WhiteCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      InitialsAvatar(name: _name(row), tone: Tone.sky, size: AvatarSize.lg),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_name(row), style: AppText.body(size: 17, weight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(textOf(row['position']) ?? _categoryLabel(_category(row)),
                                style: AppText.body(size: 12, color: AppColors.slate500)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _Pill(text: _categoryLabel(_category(row)), bg: const Color(0xFFEFF6FF), fg: AppColors.blue),
                                _Pill(text: statusText, bg: statusBg, fg: statusFg),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (phone != null || email != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (phone != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launch(Uri(scheme: 'tel', path: phone)),
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text('Call'),
                          ),
                        ),
                      if (phone != null && email != null) const SizedBox(width: 10),
                      if (email != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launch(Uri(scheme: 'mailto', path: email)),
                            icon: const Icon(Icons.mail_outline_rounded, size: 18),
                            label: const Text('Email'),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const SectionLabel(text: 'Contact'),
                _FactsCard(facts: [('Phone', phone), ('Email', email)]),
                const SizedBox(height: 16),
                const SectionLabel(text: 'Work'),
                _FactsCard(facts: [
                  ('Position', textOf(row['position'])),
                  ('Category', _categoryLabel(_category(row))),
                  ('Department', _departments(row).join(', ')),
                  ('Roles', _roles(row).join(', ')),
                  ('Status', statusText),
                  ('Card number', textOf(row['card_number']) ?? (row['active_card'] is Map ? textOf((row['active_card'] as Map)['card_number']) : null)),
                  ('On file since', _date(row['created_at'])),
                ]),
                const SizedBox(height: 16),
                const SectionLabel(text: 'Today'),
                _FactsCard(facts: [('Attendance', todayText)]),
                const SizedBox(height: 16),
                const SectionLabel(text: 'Classes'),
                _FactsCard(
                  facts: [('Class teacher of', homerooms.isEmpty ? 'None' : homerooms.join(', '))],
                ),
                const SizedBox(height: 16),
                const SectionLabel(text: 'Subjects taught'),
                WhiteCard(
                  padding: const EdgeInsets.all(14),
                  child: _assignments == null
                      ? Text('Loading…', style: AppText.body(size: 13, color: AppColors.slate500))
                      : subjects.isEmpty
                          ? Text('No subjects assigned.', style: AppText.body(size: 13, color: AppColors.slate500))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final e in (subjects.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.key, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.slate800)),
                                        if (e.value.isNotEmpty)
                                          Text((e.value.toList()..sort()).join(', '),
                                              style: AppText.body(size: 12, color: AppColors.slate500)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.facts});

  final List<(String, String?)> facts;

  @override
  Widget build(BuildContext context) {
    final shown = [for (final f in facts) if (f.$2 != null && f.$2!.isNotEmpty) f];
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: shown.isEmpty
          ? Text('Nothing on file.', style: AppText.body(size: 13, color: AppColors.slate500))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(shown[i].$1, style: AppText.body(size: 12, color: AppColors.slate500)),
                      ),
                      Expanded(
                        child: Text(shown[i].$2!,
                            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.slate800)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
