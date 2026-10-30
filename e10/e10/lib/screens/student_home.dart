import 'package:flutter/material.dart';

import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/home_cards.dart';
import '../widgets/motion.dart';

class StudentHome extends StatelessWidget {
  const StudentHome({
    super.key,
    required this.user,
    required this.onNav,
    required this.onLogout,
  });

  final AppUser user;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final homeworkDue = store.tableRows('assignments').length;
    final alerts = store.unreadNoticeCount(user.role);
    final self = store.students.length == 1 ? store.students.first : null;

    final present = store.tableRows('attendance').where((row) {
      final status = '${row['status'] ?? ''}'.toLowerCase();
      return status.contains('present') || status == 'in' || status == 'checked_in';
    }).length;
    final attendanceTotal = store.tableRows('attendance').length;
    final attendancePct = attendanceTotal == 0 ? '—' : '${((present / attendanceTotal) * 100).round()}%';

    return Column(
      children: [
        DashAccountHeader(
          user: user,
          subtitle: store.brandedSchoolName,
          onLogout: onLogout,
        ),
        const SyncBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => store.syncFromApi(),
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppLayout.page(context),
            children: dashboardChildren(context, [
              if (self != null) ...[
                WhiteCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 18, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Student ID: ${store.studentDisplayId(self)}${self.klass.isEmpty ? '' : ' · ${self.klass}'}',
                          style: AppText.body(size: 13, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  _Tile(label: 'Attendance', value: attendancePct),
                  const SizedBox(width: 8),
                  _Tile(label: 'Homework', value: homeworkDue == 0 ? 'None' : '$homeworkDue due'),
                  const SizedBox(width: 8),
                  _Tile(label: 'Alerts', value: '$alerts'),
                ],
              ),
              const SizedBox(height: 20),
              const SectionLabel(text: 'Jump in'),
              Row(
                children: [
                  if (PlanAccess.allows(AppScreen.homework))
                  SquareQuickAction(
                    color: AppColors.jumpA,
                    icon: Icons.menu_book_rounded,
                    label: 'Homework',
                    onTap: () => onNav(AppScreen.homework),
                  ),
                  SquareQuickAction(
                    color: AppColors.jumpB,
                    icon: Icons.dashboard_customize_rounded,
                    label: 'School life',
                    onTap: () => onNav(AppScreen.schoolLife),
                  ),
                  if (PlanAccess.allows(AppScreen.adminAcademics))
                  SquareQuickAction(
                    color: AppColors.jumpC,
                    icon: Icons.workspace_premium_rounded,
                    label: 'Results',
                    onTap: () => onNav(AppScreen.adminAcademics),
                  ),
                  if (PlanAccess.allows(AppScreen.adminTimetable))
                  SquareQuickAction(
                    color: AppColors.jumpD,
                    icon: Icons.calendar_month_rounded,
                    label: 'Timetable',
                    onTap: () => onNav(AppScreen.adminTimetable),
                  ),
                ],
              ),
              if (PlanAccess.allows(AppScreen.adminTimetable)) ...[
              const SizedBox(height: 20),
              WeekTimetableCard(
                slots: store.timetable,
                emptyText: 'No timetable yet from the school.',
                onOpen: () => onNav(AppScreen.adminTimetable),
              ),
              ],
            ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: WhiteCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          children: [
            Text(value, style: AppType.number),
            Text(label, style: AppType.caption),
          ],
        ),
      ),
    );
  }
}
