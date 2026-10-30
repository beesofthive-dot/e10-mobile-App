import 'package:flutter/material.dart';

import '../app_prefs.dart';
import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import 'common.dart';

/// The teacher's single navigation surface — everything (every screen, plus
/// account/settings/log out) lives here now instead of being split across a
/// header menu icon, a separate account sheet, and the bottom nav. Open it
/// by swiping in from the left edge (Flutter's Scaffold does this for any
/// `drawer:` automatically — no header button needed).
class TeacherDrawer extends StatelessWidget {
  const TeacherDrawer({
    super.key,
    required this.user,
    required this.active,
    required this.onNav,
    required this.onLogout,
  });

  final AppUser user;
  final AppScreen active;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback onLogout;

  static const _main = [
    (screen: AppScreen.teacherHome, label: 'Dashboard', icon: Icons.dashboard_rounded),
    (screen: AppScreen.teacherClasses, label: 'My Classes', icon: Icons.groups_rounded),
    (screen: AppScreen.teacherAttendance, label: 'Attendance', icon: Icons.fact_check_rounded),
    (screen: AppScreen.homework, label: 'Assignments', icon: Icons.assignment_rounded),
  ];

  static const _more = [
    (screen: AppScreen.adminTimetable, label: 'Timetable', icon: Icons.event_note_rounded),
    (screen: AppScreen.teacherExams, label: 'Exams', icon: Icons.quiz_rounded),
    (screen: AppScreen.teacherMyReports, label: 'Report cards', icon: Icons.bar_chart_rounded),
    (screen: AppScreen.schoolLife, label: 'School Calendar', icon: Icons.calendar_month_rounded),
    (screen: AppScreen.teacherAnnouncements, label: 'Announcements', icon: Icons.campaign_rounded),
    (screen: AppScreen.messages, label: 'Messages', icon: Icons.mail_rounded),
  ];

  /// A department head's menu: "My department" replaces "My Classes", as on
  /// the website, and each page needs its own permission.
  List<({AppScreen screen, String label, IconData icon})> get _department => [
        (screen: AppScreen.departmentHome, label: 'Overview', icon: Icons.apartment_rounded),
        (screen: AppScreen.departmentStudents, label: 'Students', icon: Icons.school_rounded),
        (screen: AppScreen.departmentStaff, label: 'Staff', icon: Icons.badge_rounded),
        (screen: AppScreen.departmentClasses, label: 'Classes', icon: Icons.groups_rounded),
        (screen: AppScreen.departmentAttendance, label: 'Department attendance', icon: Icons.how_to_reg_rounded),
        (screen: AppScreen.departmentHeads, label: 'Department heads', icon: Icons.manage_accounts_rounded),
      ].where((item) => user.canOpen(item.screen)).toList();

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.maybeOf(context);
    return Drawer(
      backgroundColor: AppColors.navy,
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  const SchoolMark(size: 44, light: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.display(size: 16, weight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          store?.brandedSchoolName ?? user.role.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  for (final item in _main)
                    if (PlanAccess.allows(item.screen) && !(user.isDepartmentHead && item.screen == AppScreen.teacherClasses)) _tile(context, item),
                  if (user.isDepartmentHead) ...[
                    _sectionLabel('My department'),
                    for (final item in _department)
                      if (PlanAccess.allows(item.screen)) _tile(context, item),
                  ],
                  _sectionLabel('More'),
                  for (final item in _more)
                    if (PlanAccess.allows(item.screen)) _tile(context, item),
                  _sectionLabel('Settings'),
                  _darkModeTile(context),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () async {
                    final ok = await confirmLogout(context);
                    if (!ok || !context.mounted) return;
                    Scaffold.maybeOf(context)?.closeDrawer();
                    onLogout();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFFCA5A5)),
                        const SizedBox(width: 14),
                        Text(
                          'Log out',
                          style: AppText.body(size: 14, weight: FontWeight.w600, color: const Color(0xFFFCA5A5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
      child: Text(
        text.toUpperCase(),
        style: AppText.body(size: 11, weight: FontWeight.w700, color: Colors.white38, letterSpacing: 0.6),
      ),
    );
  }

  Widget _darkModeTile(BuildContext context) {
    final prefs = AppPrefs.of(context);
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        return SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          value: prefs.dark,
          onChanged: (v) => prefs.setDark(v),
          title: Text('Dark mode', style: AppText.body(size: 14, weight: FontWeight.w600, color: Colors.white)),
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.white38,
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    ({AppScreen screen, String label, IconData icon}) item,
  ) {
    final isActive = item.screen == active;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            Scaffold.maybeOf(context)?.closeDrawer();
            onNav(item.screen);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: isActive ? Colors.white : Colors.white70),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: AppText.body(
                    size: 14,
                    weight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
