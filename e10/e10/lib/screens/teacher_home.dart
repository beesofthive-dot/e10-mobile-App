import 'package:flutter/material.dart';

import '../models.dart';
import '../plan_access.dart';
import 'department_screen.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/home_cards.dart';
import '../widgets/dash_cards.dart';
import '../widgets/motion.dart';

class TeacherHome extends StatelessWidget {
  const TeacherHome({
    super.key,
    required this.user,
    required this.onNav,
    required this.onLogout,
  });

  final AppUser user;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback onLogout;

  String _caption(SchoolStore store) {
    final me = store.teachers.where((t) {
      return t.name.toLowerCase() == user.displayName.toLowerCase() ||
          (t.email.isNotEmpty && t.email.toLowerCase() == user.email.toLowerCase());
    }).firstOrNull;
    if (store.isKgTeacher(user)) return 'KG teacher · ${store.brandedSchoolName}';
    final subject = (me?.detail ?? me?.extra ?? '').trim();
    if (subject.isEmpty) {
      return store.isClassTeacher(user) ? 'Class teacher · ${store.brandedSchoolName}' : store.brandedSchoolName;
    }
    if (subject.toLowerCase().contains('teacher')) return '$subject · ${store.brandedSchoolName}';
    return '$subject Teacher · ${store.brandedSchoolName}';
  }

  int _pendingMarking(SchoolStore store) {
    var n = 0;
    for (final row in store.tableRows('assignments')) {
      if (!store.isMyClassWork(row)) continue;
      final submissions = row['submissions'];
      if (submissions is! List) continue;
      for (final item in submissions) {
        if (item is Map && '${item['status']}'.toLowerCase() == 'submitted') n++;
      }
    }
    return n;
  }

  List<TimeSlot> _todaySlots(SchoolStore store) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final today = days[DateTime.now().weekday - 1];
    // Only today: never pad the list with other days' lessons.
    return SchoolStore.slotsForDay(store.myTimetable, today);
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final kind = store.teacherKind(user);
    final kgTeacher = kind == TeacherKind.kg;
    final classTeacher = kgTeacher || kind == TeacherKind.classTeacher;
    final focusRooms = store.teacherFocusClasses(user);
    if (store.focusedClassId.isEmpty && focusRooms.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (store.focusedClassId.isEmpty) store.focusClass(focusRooms.first.id);
      });
    }
    final focusId = store.focusedClassId;
    final focusClass = store.classes.where((c) => c.id == focusId).firstOrNull;
    var slots = _todaySlots(store);
    if (focusClass != null) {
      slots = slots.where((s) => s.className.isEmpty || s.className == focusClass.name).toList();
    }
    final pending = _pendingMarking(store);
    final classStudents = [
      for (final s in store.students)
        if (focusClass == null || s.classId == focusClass.id || s.klass == focusClass.name) s,
    ];
    final present = classStudents.where((s) {
      final st = store.rollOf(s.id).toLowerCase();
      return st == 'present' || st == 'late';
    }).length;
    final homework = [
      // Only the work this teacher set, never another teacher's.
      for (final row in store.tableRows('assignments'))
        if (store.isMyClassWork(row) && (focusClass == null || store.rowMatchesClass(row, focusClass))) row,
    ];
    // One account, functions by real assignment: subjects taught, and the
    // class(es) they are class teacher of.
    final subjects = store.mySubjectAssignments;
    final myClasses = store.homeroomClassesFor(user);
    // Before assignments have loaded, don't hide subject functions.
    final teachesSubjects = subjects.isNotEmpty || store.tableRows('teacher_subject_assignments').isEmpty;

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          DashAccountHeader(
            user: user,
            subtitle: _caption(store),
            onLogout: onLogout,
            onTapSchool: () => onNav(AppScreen.schoolProfile),
          ),
          const SyncBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => store.syncFromApi(),
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: dashboardChildren(context, [
                if (PlanAccess.allows(AppScreen.teacherAttendance)) ...[
                _TeacherTodayCard(user: user, onNav: onNav),
                const SizedBox(height: 14),
                ],
                if (user.isDepartmentHead) ...[
                  DepartmentHeadCard(user: user, onNav: onNav),
                  const SizedBox(height: 14),
                ],
                if (user.department.trim().isNotEmpty) ...[
                  WhiteCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.apartment_rounded, size: 18, color: AppColors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${user.displayName} · ${user.department.trim()} Department',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 13, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (subjects.isNotEmpty || myClasses.isNotEmpty) ...[
                  _RolesCard(
                    subjects: [for (final a in subjects) (subject: a.subjectName, klass: a.className)],
                    classes: [for (final c in myClasses) c.name],
                    onSubjects: PlanAccess.allows(AppScreen.homework) ? () => onNav(AppScreen.homework) : null,
                    onClassRoll: PlanAccess.allows(AppScreen.teacherAttendance) ? () => onNav(AppScreen.teacherAttendance) : null,
                    onClassReport: PlanAccess.allows(AppScreen.teacherMyReports) ? () => onNav(AppScreen.teacherMyReports) : null,
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    MiniStat(value: '${slots.length}', label: "Today's classes", color: AppColors.blue),
                    MiniStat(
                      value: classTeacher ? '$present' : '$pending',
                      label: classTeacher ? 'Students in' : 'To review',
                      color: AppColors.emerald,
                    ),
                    if (PlanAccess.allows(AppScreen.homework))
                      MiniStat(value: '${homework.length}', label: 'Homework', color: AppColors.rose),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Jump in',
                  style: AppText.display(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: classTeacher
                      ? [
                          if (PlanAccess.allows(AppScreen.teacherAttendance))
                          SquareQuickAction(
                            color: AppColors.iconPalette[0],
                            icon: Icons.check_rounded,
                            label: 'Mark roll',
                            onTap: () => onNav(AppScreen.teacherAttendance),
                          ),
                          if (kgTeacher && PlanAccess.allows(AppScreen.teacherDailyReports))
                            SquareQuickAction(
                              color: AppColors.iconPalette[1],
                              icon: Icons.child_care_rounded,
                              label: 'Daily report',
                              onTap: () => onNav(AppScreen.teacherDailyReports),
                            )
                          else if (teachesSubjects && !kgTeacher && PlanAccess.allows(AppScreen.homework))
                            SquareQuickAction(
                              color: AppColors.iconPalette[2],
                              icon: Icons.menu_book_rounded,
                              label: 'Set homework',
                              onTap: () => onNav(AppScreen.homework),
                            ),
                          SquareQuickAction(
                            color: AppColors.iconPalette[3],
                            icon: Icons.school_rounded,
                            label: 'My classes',
                            onTap: () => onNav(AppScreen.teacherClasses),
                          ),
                          if (PlanAccess.allows(AppScreen.teacherMyReports))
                          SquareQuickAction(
                            color: AppColors.iconPalette[4],
                            icon: Icons.description_rounded,
                            label: 'Reports',
                            onTap: () => onNav(AppScreen.teacherMyReports),
                          ),
                        ]
                      : [
                          if (PlanAccess.allows(AppScreen.homework))
                          SquareQuickAction(
                            color: AppColors.iconPalette[5],
                            icon: Icons.menu_book_rounded,
                            label: 'Set homework',
                            onTap: () => onNav(AppScreen.homework),
                          ),
                          SquareQuickAction(
                            color: AppColors.iconPalette[0],
                            icon: Icons.school_rounded,
                            label: 'My classes',
                            onTap: () => onNav(AppScreen.teacherClasses),
                          ),
                          if (PlanAccess.allows(AppScreen.homework))
                          SquareQuickAction(
                            color: AppColors.iconPalette[1],
                            icon: Icons.fact_check_rounded,
                            label: 'Mark work',
                            onTap: () => onNav(AppScreen.homework),
                          ),
                          if (PlanAccess.allows(AppScreen.adminTimetable))
                          SquareQuickAction(
                            color: AppColors.iconPalette[2],
                            icon: Icons.calendar_month_rounded,
                            label: 'Timetable',
                            onTap: () => onNav(AppScreen.adminTimetable),
                          ),
                        ],
                ),
                if (PlanAccess.allows(AppScreen.adminTimetable)) ...[
                const SizedBox(height: 22),
                WeekTimetableCard(
                  title: 'My timetable',
                  slots: store.myTimetable,
                  showClass: true,
                  emptyText: 'No lessons assigned to you yet.',
                  onOpen: () => onNav(AppScreen.adminTimetable),
                ),
                ],
                if (PlanAccess.allows(AppScreen.teacherAnnouncements)) ...[
                const SizedBox(height: 16),
                LatestAnnouncementsCard(onOpen: () => onNav(AppScreen.teacherAnnouncements)),
                ],
                if (PlanAccess.allows(AppScreen.teacherReports)) ...[
                const SizedBox(height: 16),
                ExamsReportsHomeCard(
                  onOpenExams: () => onNav(AppScreen.teacherExams),
                  onOpenReports: () => onNav(AppScreen.teacherReports),
                ),
                ],
                if (homework.isNotEmpty && PlanAccess.allows(AppScreen.homework)) ...[
                  const SizedBox(height: 12),
                  SectionHead(
                    title: 'Waiting on you',
                    action: 'Open',
                    onAction: () => onNav(AppScreen.homework),
                  ),
                  for (final row in homework.take(3)) _HwReviewCard(row: row, store: store),
                ],
                if (PlanAccess.allows(AppScreen.messages)) ...[
                const SizedBox(height: 16),
                SectionHead(
                  title: 'Open chats',
                  action: 'Messages',
                  onAction: () => onNav(AppScreen.messages),
                ),
                for (final message in store.messagesFor(user.role).take(3))
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(child: Text(message.preview.isEmpty ? message.from : message.preview, maxLines: 2, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text(message.unread ? 'Unread' : 'Read', style: AppText.body(size: 11, color: AppSurface.ink(context))),
                      ],
                    ),
                  ),
                ],
              ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HwReviewCard extends StatelessWidget {
  const _HwReviewCard({required this.row, required this.store});

  final Map<String, dynamic> row;
  final SchoolStore store;

  @override
  Widget build(BuildContext context) {
    final submissions = row['submissions'];
    var done = 0;
    var total = store.students.length;
    if (submissions is List) {
      total = submissions.isNotEmpty ? submissions.length : total;
      for (final item in submissions) {
        if (item is Map) {
          final st = '${item['status']}'.toLowerCase();
          if (st == 'submitted' || st == 'marked' || st == 'late') done++;
        }
      }
    }
    final subject = row['subject'] is Map ? '${(row['subject'] as Map)['name'] ?? ''}' : '${row['subject'] ?? ''}';
    final klass = row['class'] is Map ? '${(row['class'] as Map)['name'] ?? ''}' : '${row['class_name'] ?? row['klass'] ?? ''}';
    final due = '${row['deadline'] ?? row['published_date'] ?? ''}';
    final today = DateTime.now();
    final dueDate = DateTime.tryParse(due);
    var dueTag = 'DUE';
    if (dueDate != null) {
      final a = DateTime(today.year, today.month, today.day);
      final b = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (b == a) {
        dueTag = 'TODAY';
      } else if (b == a.add(const Duration(days: 1))) {
        dueTag = 'TOMORROW';
      }
    }
    final pct = total == 0 ? 0.0 : done / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  '${row['title'] ?? 'Assignment'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 14, weight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dueTag == 'TODAY' ? AppColors.accentSoft : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dueTag,
                  style: AppText.body(
                    size: 12,
                    weight: FontWeight.w800,
                    color: AppSurface.ink(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [if (subject.isNotEmpty) subject, if (klass.isNotEmpty) klass].join(' · '),
            style: AppText.body(size: 12, color: AppSurface.ink(context)),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.slate100,
              color: AppColors.honey,
            ),
          ),
          const SizedBox(height: 6),
          Text('$done/$total submitted', style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.ink(context))),
        ],
      ),
    );
  }
}

/// "My Subjects" and "My Class" on the teacher dashboard: what this one
/// account is assigned to, with the matching functions under each.
class _RolesCard extends StatelessWidget {
  const _RolesCard({
    required this.subjects,
    required this.classes,
    required this.onSubjects,
    required this.onClassRoll,
    required this.onClassReport,
  });

  final List<({String subject, String klass})> subjects;
  final List<String> classes;
  // Null when the school's plan leaves that module out.
  final VoidCallback? onSubjects;
  final VoidCallback? onClassRoll;
  final VoidCallback? onClassReport;

  @override
  Widget build(BuildContext context) {
    Widget heading(IconData icon, Color color, String text) => Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(text, style: AppText.display(size: 15, weight: FontWeight.w700)),
          ],
        );
    Widget action(String label, VoidCallback? onTap) => onTap == null ? const SizedBox.shrink() : Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(label, style: AppText.body(size: 12.5, weight: FontWeight.w700)),
          ),
        );
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subjects.isNotEmpty) ...[
            heading(Icons.menu_book_rounded, AppColors.iconPalette[0], 'My Subjects'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in subjects)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${a.subject} · ${a.klass}', style: AppText.body(size: 12, weight: FontWeight.w600)),
                  ),
              ],
            ),
            action('Homework, tests & marking', onSubjects),
          ],
          if (subjects.isNotEmpty && classes.isNotEmpty) const Divider(height: 24),
          if (classes.isNotEmpty) ...[
            heading(Icons.groups_rounded, AppColors.iconPalette[1], 'My Class'),
            const SizedBox(height: 6),
            for (final c in classes)
              Text('$c — Class Teacher', style: AppText.body(size: 13.5, weight: FontWeight.w700)),
            Wrap(
              children: [
                action('Attendance', onClassRoll),
                action('Class report', onClassReport),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


/// Today's palm-scan picture for a teacher: their own check-in, and for a
/// class teacher, which day students have scanned in and how many boarders
/// still need marking by hand.
class _TeacherTodayCard extends StatefulWidget {
  const _TeacherTodayCard({required this.user, required this.onNav});

  final AppUser user;
  final ValueChanged<AppScreen> onNav;

  @override
  State<_TeacherTodayCard> createState() => _TeacherTodayCardState();
}

class _TeacherTodayCardState extends State<_TeacherTodayCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SchoolScope.of(context).refreshTeacherToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final me = store.myAttendanceToday;
    final inAt = SchoolStore.clockOf(me?['check_in_at']);
    final outAt = SchoolStore.clockOf(me?['check_out_at']);
    final late = '${me?['status'] ?? ''}'.toLowerCase() == 'late';
    final loaded = store.teacherTodayLoadedAt != null;

    final homeroom = {for (final k in store.homeroomClassesFor(widget.user)) k.id};
    final classKids = [for (final s in store.students) if (homeroom.contains(s.classId)) s];
    final dayKids = classKids.where((s) => !s.boarder).toList();
    final boarders = classKids.where((s) => s.boarder).toList();
    final arrived = <({String name, String at})>[];
    for (final kid in dayKids) {
      final row = store.todayRecordFor(kid.id);
      final at = SchoolStore.clockOf(row?['check_in_at']);
      if (at.isNotEmpty) arrived.add((name: kid.name, at: at));
    }
    arrived.sort((a, b) => b.at.compareTo(a.at));
    final boardersMarked = boarders.where((b) => store.todayRecordFor(b.id) != null).length;

    final String myLine;
    if (!loaded) {
      myLine = 'Checking today\'s scan…';
    } else if (inAt.isEmpty) {
      myLine = 'Not scanned yet · scan your palm at the school scanner';
    } else if (outAt.isEmpty) {
      myLine = 'Checked in $inAt${late ? ' (late)' : ''}${SchoolStore.isPalmRecord(me) ? ' by palm' : ''}';
    } else {
      myLine = 'In $inAt · out $outAt';
    }

    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.back_hand_rounded, size: 18, color: inAt.isEmpty ? AppColors.slate400 : AppColors.emerald),
              const SizedBox(width: 8),
              Text('Today', style: AppText.display(size: 16, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text('MY ATTENDANCE', style: AppText.body(size: 10, weight: FontWeight.w800, color: AppColors.slate400, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(
            myLine,
            style: AppText.body(
              size: 14,
              weight: FontWeight.w700,
              color: inAt.isEmpty ? AppSurface.muted(context) : (late ? AppColors.honeyDark : AppColors.emerald),
            ),
          ),
          if (homeroom.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('MY CLASS', style: AppText.body(size: 10, weight: FontWeight.w800, color: AppColors.slate400, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            Text(
              '${arrived.length} of ${dayKids.length} day students scanned in',
              style: AppText.body(size: 14, weight: FontWeight.w700),
            ),
            if (arrived.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                arrived.take(3).map((a) => '${a.name} ${a.at}').join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 12, color: AppSurface.muted(context)),
              ),
            ],
            if (boarders.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      boardersMarked >= boarders.length
                          ? 'Boarders marked (${boarders.length})'
                          : '${boarders.length - boardersMarked} of ${boarders.length} boarders to mark',
                      style: AppText.body(size: 13, weight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNav(AppScreen.teacherAttendance),
                    child: Text('Mark boarders', style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.blue)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
