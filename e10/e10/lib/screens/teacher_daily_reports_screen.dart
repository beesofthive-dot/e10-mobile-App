import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import '../widgets/report_photos.dart';
import 'admin_forms.dart';

/// Daily reports for KG/Nursery classes — one record per child per day
/// (mood, meals, nap, notes), created via POST /daily-reports and shared
/// with the parent via POST /daily-reports/{id}/send.
class TeacherDailyReportsScreen extends StatefulWidget {
  const TeacherDailyReportsScreen({
    super.key,
    required this.user,
    this.onBack,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<TeacherDailyReportsScreen> createState() => _TeacherDailyReportsScreenState();
}

class _RosterRow {
  _RosterRow({required this.student, this.reportId = '', this.status = 'not_started', this.fields = const {}});

  final Student student;
  String reportId;
  String status; // not_started | draft | sent
  Map<String, dynamic> fields;
}

/// Not a real class — the "All students" pick in the class switcher, for a
/// caregiver (e.g. after-school care/crèche staff) whose kids span several
/// homerooms rather than belonging to one class the way a KG class teacher's
/// pupils do. A fresh instance each time since [NamedRecord] fields are
/// mutable and this one must never be shared/mutated.
NamedRecord _allStudentsOption() => NamedRecord(id: '', name: 'All students');

class _TeacherDailyReportsScreenState extends State<TeacherDailyReportsScreen> {
  NamedRecord? _klass;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _ready = false;
  List<_RosterRow> _rows = [];
  final _search = TextEditingController();

  String get _dateKey {
    final month = _date.month.toString().padLeft(2, '0');
    final day = _date.day.toString().padLeft(2, '0');
    return '${_date.year}-$month-$day';
  }

  bool get _isToday {
    final now = DateTime.now();
    return now.year == _date.year && now.month == _date.month && now.day == _date.day;
  }

  bool get _allStudents => _klass?.id.isEmpty ?? false;

  List<NamedRecord> _classOptions(SchoolStore store) => [_allStudentsOption(), ...store.classes];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final store = SchoolScope.of(context);
    final rooms = store.homeroomClassesFor(widget.user);
    // A homeroom class teacher lands on their own class by default.
    // `teacherFocusClasses` isn't used here — it falls back to returning
    // *every* class in the school when a teacher has no specific match,
    // which would silently pick "the first class" for someone with no real
    // assignment. Anyone without an actual homeroom (an after-school/crèche
    // caregiver covering several classes, for instance) starts on "All
    // students" instead — an honest starting point, not a guess.
    _klass = rooms.isNotEmpty ? rooms.first : _allStudentsOption();
    _load();
  }

  Future<void> _load() async {
    final klass = _klass;
    final store = SchoolScope.of(context);
    if (klass == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);

    // The live website asks for the teacher's roster by date alone and the
    // server returns their own early-years class with each child's report;
    // do the same so both show exactly the same children and reports.
    final byDate = await store.fetchTeacherDailyRoster(_dateKey);
    List<Map<String, dynamic>> roster;
    List<Student> students;
    if (byDate != null && byDate.isNotEmpty) {
      roster = byDate;
      students = [for (final row in byDate) store.studentFromRosterRow(row)];
    } else {
      final classes = _allStudents ? store.classes : [klass];
      final rosters = await Future.wait([
        for (final c in classes) store.fetchDailyReportsRoster(classId: c.id, date: _dateKey),
      ]);
      roster = [for (final list in rosters) ...list];
      students = _allStudents
          ? store.students
          : store.students.where((s) => s.classId == klass.id || s.klass == klass.name).toList();
    }

    Map<String, dynamic>? entryFor(Student s) {
      for (final item in roster) {
        final studentJson = item['student'];
        final sid = studentJson is Map ? '${studentJson['id'] ?? ''}' : '${item['student_id'] ?? ''}';
        if (sid == s.id) return item;
      }
      return null;
    }

    final rows = [
      for (final s in students)
        () {
          final entry = entryFor(s);
          final reportJson = entry?['daily_report'] ?? entry?['report'];
          final report = reportJson is Map ? Map<String, dynamic>.from(reportJson) : (entry != null && entry['id'] != null ? entry : null);
          final id = '${report?['id'] ?? ''}';
          // Confirmed live: a report row has `is_sent` (bool) + `sent_at`,
          // not a `status` string.
          final sentFlag = report?['is_sent'];
          final status = id.isEmpty
              ? 'not_started'
              : (sentFlag == true || sentFlag == 1 || '$sentFlag' == '1' ? 'sent' : 'draft');
          return _RosterRow(
            student: s,
            reportId: id,
            status: status,
            fields: report ?? const {},
          );
        }(),
    ];

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  void _shiftDate(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _load();
  }

  Future<void> _openCompose(_RosterRow row) async {
    final klass = _klass;
    if (klass == null) return;
    final store = SchoolScope.of(context);
    final saved = await showAppDialog<bool>(
      context: context,
      builder: (sheetContext) => _DailyReportSheet(
        student: row.student,
        initial: row.fields,
        store: store,
        onSave: ({required Map<String, dynamic> fields, required bool send}) async {
          final result = await store.saveDailyReport(
            reportId: row.reportId.isEmpty ? null : row.reportId,
            studentId: row.student.id,
            // In "All students" mode there's no single class in view — use
            // the student's own homeroom class rather than sending nothing.
            classId: _allStudents ? row.student.classId : klass.id,
            date: _dateKey,
            fields: fields,
          );
          if (result.error.isNotEmpty) return (error: result.error, id: '');
          row.reportId = result.id;
          row.fields = fields;
          if (send) {
            final sendError = await store.sendDailyReport(result.id);
            if (sendError.isNotEmpty) return (error: sendError, id: result.id);
            row.status = 'sent';
          } else {
            row.status = 'draft';
          }
          return (error: '', id: result.id);
        },
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _pickClass(SchoolStore store) async {
    final options = _classOptions(store);
    final picked = await showAppPicker(
      context: context,
      title: 'Class',
      items: [for (final c in options) c.name],
      selected: _klass?.name ?? '',
    );
    if (picked == null) return;
    final match = options.where((c) => c.name == picked).firstOrNull;
    if (match == null || match.name == _klass?.name) return;
    setState(() => _klass = match);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final klass = _klass;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateLabel = _isToday ? 'Today' : '${_date.day} ${months[_date.month - 1]} ${_date.year}';

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Daily Reports',
            subtitle: klass == null ? 'No class assigned yet' : '${klass.name} · $dateLabel',
            onBack: widget.onBack,
          ),
          if (klass == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "No classes are set up for this school yet.",
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, color: AppSurface.muted(context)),
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: AppSurface.card(context),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _pickClass(store),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppSurface.line(context))),
                    child: Row(
                      children: [
                        Icon(
                          _allStudents ? Icons.groups_rounded : Icons.class_rounded,
                          size: 18,
                          color: AppColors.icon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            klass.name,
                            style: AppText.body(size: 14, weight: FontWeight.w700, color: AppSurface.text(context)),
                          ),
                        ),
                        Icon(Icons.expand_more_rounded, color: AppSurface.muted(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _shiftDate(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.slate500),
                          const SizedBox(width: 6),
                          Text(dateLabel, style: AppText.body(size: 14, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isToday ? null : () => _shiftDate(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            if (_allStudents)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search a student by name',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: AppSurface.cardSoft(context),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: Builder(builder: (context) {
                  final query = _allStudents ? _search.text.trim().toLowerCase() : '';
                  final visibleRows = query.isEmpty ? _rows : [for (final r in _rows) if (r.student.name.toLowerCase().contains(query)) r];
                  return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppLayout.page(context),
                  children: [
                    if (!_loading && visibleRows.isEmpty)
                      WhiteCard(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          query.isNotEmpty
                              ? 'No student matches "$query".'
                              : _allStudents
                                  ? 'No students enrolled yet.'
                                  : 'No students in this class yet.',
                          style: AppText.body(size: 13, color: AppColors.slate500),
                        ),
                      )
                    else
                      for (final row in visibleRows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: WhiteCard(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: InkWell(
                              onTap: () => _openCompose(row),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  InitialsAvatar(name: row.student.name, size: AvatarSize.sm),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      row.student.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.body(size: 14, weight: FontWeight.w700),
                                    ),
                                  ),
                                  _statusChip(row.status),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return switch (status) {
      'sent' => const StatusDot(label: 'Sent', color: AppColors.emerald),
      'draft' => const StatusDot(label: 'Draft', color: AppColors.honeyDark),
      _ => const StatusDot(label: 'Not started', color: AppColors.slate400),
    };
  }
}

class _DailyReportSheet extends StatefulWidget {
  const _DailyReportSheet({required this.student, required this.initial, required this.store, required this.onSave});

  final Student student;
  final Map<String, dynamic> initial;
  final SchoolStore store;
  final Future<({String error, String id})> Function({required Map<String, dynamic> fields, required bool send}) onSave;

  @override
  State<_DailyReportSheet> createState() => _DailyReportSheetState();
}

class _DailyReportSheetState extends State<_DailyReportSheet> {
  // Same moods the live website offers (and the API accepts).
  static const _moods = ['Happy', 'Calm', 'Fussy', 'Tired'];
  // Confirmed live against POST/PUT /daily-reports: breakfast_status,
  // lunch_status and snack_status only accept these four values.
  static const _mealLevels = ['all', 'most', 'some', 'none', 'skipped'];
  static const _mealLevelLabels = {'all': 'Ate it all', 'most': 'Most of it', 'some': 'Some of it', 'none': "Didn't eat", 'skipped': 'Skipped'};
  // `activities` is free-text server-side, but these are the values already
  // in use on this school's existing reports — offered as quick picks.
  static const _activityOptions = [
    'Outdoor play',
    'Story time',
    'Tummy time',
    'Sensory play',
    'Building blocks',
    'Arts & crafts',
    'Circle time',
    'Music & dance',
  ];

  late String _mood;
  String? _breakfast;
  String? _lunch;
  String? _snack;
  late final TextEditingController _napMinutes;
  late final TextEditingController _note;
  late Set<String> _activities;
  // Same three counters as the website's report form.
  late final Map<String, int> _diapers;
  bool _saving = false;

  /// Most photos a teacher attaches to one report.
  static const _maxPhotos = 3;

  // Photos already on the server for this report, and ones picked on this
  // device that upload when the report is saved or sent.
  List<({String id, String url})> _existing = [];
  final List<({String name, Uint8List bytes})> _picked = [];
  bool _uploadingPhoto = false;

  String get _reportId => '${widget.initial['id'] ?? ''}';
  int get _photoCount => _existing.length + _picked.length;

  List<ReportPhoto> get _allPhotos => [
        for (final p in _existing) ReportPhoto(id: p.id, url: p.url),
        for (final p in _picked) ReportPhoto(bytes: p.bytes),
      ];

  @override
  void initState() {
    super.initState();
    final mood = '${widget.initial['mood'] ?? ''}';
    _mood = _moods.any((m) => m.toLowerCase() == mood) ? _moods.firstWhere((m) => m.toLowerCase() == mood) : _moods.first;
    _breakfast = _mealLevels.contains(widget.initial['breakfast_status']) ? '${widget.initial['breakfast_status']}' : null;
    _lunch = _mealLevels.contains(widget.initial['lunch_status']) ? '${widget.initial['lunch_status']}' : null;
    _snack = _mealLevels.contains(widget.initial['snack_status']) ? '${widget.initial['snack_status']}' : null;
    _napMinutes = TextEditingController(
      text: widget.initial['nap_minutes'] == null ? '' : '${widget.initial['nap_minutes']}',
    );
    _note = TextEditingController(text: '${widget.initial['note'] ?? ''}');
    final initialActivities = widget.initial['activities'];
    _activities = initialActivities is List ? {for (final a in initialActivities) '$a'} : {};
    int count(String key) {
      final v = widget.initial[key];
      return v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    }

    _diapers = {
      for (final key in const ['diaper_count', 'diaper_wet_count', 'diaper_soiled_count']) key: count(key),
    };
    _existing = widget.store.dailyReportPhotos(widget.initial);
  }

  @override
  void dispose() {
    _napMinutes.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final room = _maxPhotos - _photoCount;
    if (room <= 0) return;
    final picked = room == 1
        ? [if (await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85) case final one?) one]
        : await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85, limit: room);
    if (picked.isEmpty) return;
    final added = <({String name, Uint8List bytes})>[];
    for (final file in picked.take(room)) {
      added.add((name: file.name, bytes: await file.readAsBytes()));
    }
    if (!mounted) return;
    setState(() => _picked.addAll(added));
  }

  Future<void> _removeExisting(int i) async {
    final photo = _existing[i];
    setState(() => _uploadingPhoto = true);
    final err = await widget.store.deleteDailyReportPhoto(reportId: _reportId, mediaId: photo.id);
    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (err.isEmpty) _existing = [..._existing]..removeAt(i);
    });
    if (err.isNotEmpty) showSnack(context, err);
  }

  Widget _thumb({required Widget image, required VoidCallback onRemove, required VoidCallback onOpen}) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onOpen,
              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: image),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPicker(BuildContext context) {
    final photos = _allPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview exactly as the parent will see it: full photo, "+N" in the
        // bottom-right corner, tap to open full screen.
        if (photos.isNotEmpty) ...[
          ReportPhotoGallery(photos: photos, height: 200),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _existing.length; i++)
              _thumb(
                image: AuthImage(url: _existing[i].url),
                onOpen: () => showReportPhotoViewer(context, photos, initialIndex: i),
                onRemove: () => _removeExisting(i),
              ),
            for (var i = 0; i < _picked.length; i++)
              _thumb(
                image: Image.memory(_picked[i].bytes, fit: BoxFit.cover),
                onOpen: () => showReportPhotoViewer(context, photos, initialIndex: _existing.length + i),
                onRemove: () => setState(() => _picked.removeAt(i)),
              ),
            if (_photoCount < _maxPhotos)
              InkWell(
                onTap: _uploadingPhoto ? null : _pickPhotos,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_outlined, size: 20, color: AppColors.slate500),
                      const SizedBox(height: 2),
                      Text('Add', style: AppText.body(size: 11, color: AppColors.slate500)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$_photoCount of $_maxPhotos photos'
          '${_picked.isNotEmpty ? ' · new ones upload when you save or send' : ''}',
          style: AppText.body(size: 11, color: AppColors.slate400),
        ),
      ],
    );
  }

  Map<String, dynamic> get _fields => {
        'mood': _mood.toLowerCase(),
        if (_breakfast != null) 'breakfast_status': _breakfast,
        if (_lunch != null) 'lunch_status': _lunch,
        if (_snack != null) 'snack_status': _snack,
        if (_napMinutes.text.trim().isNotEmpty) 'nap_minutes': int.tryParse(_napMinutes.text.trim()),
        'activities': _activities.toList(),
        ..._diapers,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      };

  Widget _diaperCounter(String key, String title) {
    final value = _diapers[key] ?? 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(title, style: AppText.body(size: 11, color: AppColors.slate500)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  onPressed: value <= 0 ? null : () => setState(() => _diapers[key] = value - 1),
                ),
                Text('$value', style: AppText.body(size: 16, weight: FontWeight.w800)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => setState(() => _diapers[key] = value + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit({required bool send}) async {
    setState(() => _saving = true);
    // Save first, attach the photos, and only then send — so the parent's
    // "report ready" alert never arrives before the photos are there.
    final saved = await widget.onSave(fields: _fields, send: false);
    if (!mounted) return;
    if (saved.error.isNotEmpty) {
      setState(() => _saving = false);
      showSnack(context, saved.error);
      return;
    }

    var photoError = '';
    if (_picked.isNotEmpty && saved.id.isNotEmpty) {
      setState(() => _uploadingPhoto = true);
      photoError = await widget.store.uploadDailyReportPhotos(
        reportId: saved.id,
        files: [for (final p in _picked) (bytes: p.bytes, filename: p.name.isEmpty ? 'photo.jpg' : p.name)],
      );
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
    }

    if (send) {
      final sent = await widget.onSave(fields: _fields, send: true);
      if (!mounted) return;
      if (sent.error.isNotEmpty) {
        setState(() => _saving = false);
        showSnack(context, sent.error);
        return;
      }
    }

    setState(() => _saving = false);
    closeRoute(context, true);
    showSnack(
      context,
      photoError.isNotEmpty
          ? 'Report ${send ? 'sent' : 'saved'}, but the photos did not attach: $photoError'
          : send
              ? 'Report sent to the parent.'
              : 'Report saved as a draft.',
    );
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.slate50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.slate200),
          ),
        );
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t.toUpperCase(), style: AppText.label()),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppModalHeader(title: widget.student.name, subtitle: 'Daily report'),
              label('Mood today'),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in _moods)
                    ChoiceChip(
                      label: Text(m),
                      selected: _mood == m,
                      onSelected: (_) => setState(() => _mood = m),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              for (final meal in const [('Breakfast', 'breakfast'), ('Lunch', 'lunch'), ('Snack', 'snack')]) ...[
                label(meal.$1),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final level in _mealLevels)
                      ChoiceChip(
                        label: Text(_mealLevelLabels[level]!),
                        selected: (meal.$2 == 'breakfast' ? _breakfast : meal.$2 == 'lunch' ? _lunch : _snack) == level,
                        onSelected: (_) => setState(() {
                          if (meal.$2 == 'breakfast') {
                            _breakfast = level;
                          } else if (meal.$2 == 'lunch') {
                            _lunch = level;
                          } else {
                            _snack = level;
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              label('Nap (minutes)'),
              TextField(
                controller: _napMinutes,
                keyboardType: TextInputType.number,
                decoration: deco('e.g. 45'),
              ),
              const SizedBox(height: 14),
              label('Diapers'),
              Row(
                children: [
                  _diaperCounter('diaper_count', 'Total'),
                  const SizedBox(width: 8),
                  _diaperCounter('diaper_wet_count', 'Wet'),
                  const SizedBox(width: 8),
                  _diaperCounter('diaper_soiled_count', 'Soiled'),
                ],
              ),
              const SizedBox(height: 14),
              label('Activities'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final activity in _activityOptions)
                    FilterChip(
                      label: Text(activity),
                      selected: _activities.contains(activity),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _activities.add(activity);
                        } else {
                          _activities.remove(activity);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              label('Photos of the day'),
              _photoPicker(context),
              const SizedBox(height: 14),
              label('Note for parent'),
              TextField(controller: _note, maxLines: 3, decoration: deco('How was their day?')),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _submit(send: false),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(_saving ? 'Saving...' : 'Save draft'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HoneyButton(
                      label: _saving ? 'Sending...' : 'Send to parent',
                      loading: _saving,
                      onPressed: _saving ? null : () => _submit(send: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
