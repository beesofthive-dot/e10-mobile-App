import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/popups.dart';
import '../widgets/dash_cards.dart';
import 'admin_forms.dart';

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({
    super.key,
    required this.onBack,
    required this.onLogout,
    this.viewOnly = false,
    this.lockClass,
    this.opensOnToday = false,
    this.teacherView = false,
  });

  final VoidCallback onBack;
  final VoidCallback onLogout;
  final bool viewOnly;
  final String? lockClass;

  /// Teachers and parents land on today's timetable; admins land on the full
  /// week (like the website).
  final bool opensOnToday;

  /// Teachers switch between their own lessons and a class's timetable,
  /// like the website's "mine" / "class" views.
  final bool teacherView;

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  static const _allClasses = 'All classes';
  static const _weekView = 'Full week';

  String _className = '';
  bool _mine = true;
  String _view = '';

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  static String get _today {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[DateTime.now().weekday - 1];
  }

  /// The day a new period is added to: the day being viewed, else today.
  String get _addDay => _days.contains(_view) ? _view : (_days.contains(_today) ? _today : _days.first);

  Widget _chip(String label, bool selected, VoidCallback onTap, {bool dot = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.honey : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.honey : AppColors.slate200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.body(size: 12, weight: FontWeight.w700, color: selected ? Colors.white : AppColors.slate500),
              ),
              if (dot) ...[
                const SizedBox(width: 5),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: selected ? Colors.white : AppColors.honey, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotCard(SchoolStore store, TimeSlot slot, {required bool showClass}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WhiteCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(slot.start, style: AppText.body(size: 12, weight: FontWeight.w800)),
                  Text(slot.end, style: AppText.body(size: 10, color: AppColors.slate400)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 3, height: 36, color: AppColors.honey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.subject, style: AppText.body(weight: FontWeight.w800)),
                  Text(
                    [
                      if (showClass && slot.className.isNotEmpty) slot.className,
                      if (slot.teacher.isNotEmpty) slot.teacher,
                      if (slot.room.isNotEmpty) slot.room,
                    ].join(' · '),
                    style: AppText.body(size: 11, color: AppColors.slate400),
                  ),
                ],
              ),
            ),
            if (!widget.viewOnly)
              ActionMenuButton(
                title: slot.subject,
                actions: [
                  SheetAction(
                    label: 'Edit',
                    icon: Icons.edit_rounded,
                    onTap: () => _edit(context, store, slot),
                  ),
                  SheetAction(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    onTap: () async {
                      if (!await confirmDelete(context, slot.subject)) return;
                      final error = await store.deleteTimetableSlot(slot.id);
                      if (mounted) showSnack(context, error.isEmpty ? 'Period deleted' : error);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final locked = widget.lockClass != null;
    if (_className.isEmpty) {
      _className = widget.lockClass ?? _allClasses;
    }
    if (_view.isEmpty) {
      _view = widget.opensOnToday && _days.contains(_today) ? _today : _weekView;
    }
    final mine = widget.teacherView && _mine;
    final allClasses = mine || (!locked && _className == _allClasses);
    final inClass = mine
        ? store.myTimetable
        : [
            for (final s in store.timetable)
              if (allClasses || (locked && widget.lockClass!.isEmpty) || s.className == _className) s,
          ];
    // Each day's periods in time order, as on the website.
    List<TimeSlot> forDay(String day) => SchoolStore.slotsForDay(inClass, day);
    final classItems = [_allClasses, ...store.classNames];
    final canAdd = !widget.viewOnly && store.classNames.isNotEmpty;
    final week = _view == _weekView;

    return Column(
      children: [
        TopBar(
          title: 'Timetable',
          subtitle: '${mine ? 'My lessons' : allClasses ? _allClasses : _className} · ${week ? _weekView : _view}',
          onBack: widget.onBack,
          onLogout: widget.onLogout,
          onAdd: canAdd ? () => _edit(context, store) : null,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              if (widget.teacherView) ...[
                HoneyPills(
                  items: const ['My lessons', 'Class timetable'],
                  value: _mine ? 'My lessons' : 'Class timetable',
                  onChanged: (v) => setState(() => _mine = v == 'My lessons'),
                ),
                const SizedBox(height: 12),
              ],
              if (store.classNames.isNotEmpty && !locked && !mine)
                AdminDropdown(
                  label: 'Class',
                  value: classItems.contains(_className) ? _className : _allClasses,
                  items: classItems,
                  onChanged: (v) => setState(() => _className = v),
                ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip(_weekView, week, () => setState(() => _view = _weekView)),
                    for (final day in _days)
                      _chip(day.substring(0, 3), _view == day, () => setState(() => _view = day), dot: day == _today),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (week)
                for (final day in _days) ...[
                  GestureDetector(
                    onTap: () => setState(() => _view = day),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
                      child: Row(
                        children: [
                          Text(day, style: AppText.display(size: 16, weight: FontWeight.w700)),
                          if (day == _today) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.honey.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                              child: Text('Today', style: AppText.body(size: 10, weight: FontWeight.w800, color: AppColors.honey)),
                            ),
                          ],
                          const Spacer(),
                          Text('${forDay(day).length} periods', style: AppText.body(size: 11, color: AppColors.slate400)),
                        ],
                      ),
                    ),
                  ),
                  if (forDay(day).isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
                      child: Text('No slots', style: AppText.body(size: 12, color: AppColors.slate400)),
                    )
                  else
                    for (final slot in forDay(day)) _slotCard(store, slot, showClass: allClasses),
                  const SizedBox(height: 6),
                ]
              else if (forDay(_view).isEmpty)
                WhiteCard(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    widget.viewOnly ? 'Nothing scheduled for $_view.' : 'No periods yet. Tap + to add a lesson.',
                    style: AppText.body(color: AppColors.slate500),
                  ),
                )
              else
                for (final slot in forDay(_view)) _slotCard(store, slot, showClass: allClasses),
            ],
          ),
        ),
      ],
    );
  }

  void _edit(BuildContext context, SchoolStore store, [TimeSlot? existing]) {
    final start = TextEditingController(text: existing?.start ?? '');
    final end = TextEditingController(text: existing?.end ?? '');
    final room = TextEditingController(text: existing?.room ?? '');
    // The server needs a real subject from the school's subject list.
    final subjects = [for (final s in store.subjectRecords) s.name];
    var subject = existing?.subject ?? subjects.firstOrNull ?? '';
    var teacher = existing?.teacher ?? store.teacherNames.firstOrNull ?? '';
    var day = existing?.day ?? _addDay;
    var klass = existing?.className ?? (store.classNames.contains(_className) ? _className : (store.classNames.firstOrNull ?? ''));

    showAdminForm(
      context: context,
      title: existing == null ? 'Add period' : 'Edit period',
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          return Column(
            children: [
              AdminDropdown(
                label: 'Class',
                value: klass,
                items: store.classNames,
                onChanged: (v) => setLocal(() => klass = v),
              ),
              AdminDropdown(
                label: 'Day',
                value: day,
                items: _days,
                onChanged: (v) => setLocal(() => day = v),
              ),
              if (subjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('No subjects yet — add them on the school website first.', style: AppText.body(size: 12, color: AppColors.slate500)),
                )
              else
                AdminDropdown(
                  label: 'Subject',
                  value: subjects.contains(subject) ? subject : subjects.first,
                  items: subjects,
                  onChanged: (v) => setLocal(() => subject = v),
                ),
              AdminDropdown(
                label: 'Teacher',
                value: teacher,
                items: store.teacherNames,
                onChanged: (v) => setLocal(() => teacher = v),
              ),
              AdminField(label: 'Starts (e.g. 07:30)', controller: start),
              AdminField(label: 'Ends (e.g. 08:15)', controller: end),
              AdminField(label: 'Room', controller: room),
              HoneyButton(
                label: existing == null ? 'Create' : 'Update',
                onPressed: () async {
                  final error = await store.saveTimetableSlot(
                    TimeSlot(
                      id: existing?.id ?? '',
                      classId: existing != null && existing.className == klass ? existing.classId : '',
                      className: klass,
                      day: day,
                      start: start.text.trim(),
                      end: end.text.trim(),
                      subject: subject,
                      teacher: teacher,
                      room: room.text.trim(),
                    ),
                  );
                  if (!ctx.mounted) return;
                  if (error.isNotEmpty) {
                    showSnack(ctx, error);
                    return;
                  }
                  closeRoute(ctx);
                  showSnack(context, existing == null ? 'Period added' : 'Period updated');
                },
              ),
            ],
          );
        },
      ),
    ).whenComplete(() => disposeAfterClose([start, end, room]));
  }
}
