import 'package:flutter/material.dart';

import 'models.dart';
import 'plan_access.dart';

const parentNav = [
  NavItem(screen: AppScreen.parentHome, label: 'Home', icon: Icons.home_rounded),
  NavItem(screen: AppScreen.adminTimetable, label: 'Timetable', icon: Icons.calendar_month_outlined),
  NavItem(screen: AppScreen.payments, label: 'Fees', icon: Icons.receipt_long_rounded),
  NavItem(screen: AppScreen.parentFeeding, label: 'Feeding', icon: Icons.restaurant_rounded),
  NavItem(screen: AppScreen.parentReports, label: 'Reports', icon: Icons.description_outlined),
];

const adminNav = [
  NavItem(screen: AppScreen.adminHome, label: 'Home', icon: Icons.home_rounded),
  NavItem(screen: AppScreen.adminStudents, label: 'Students', icon: Icons.groups_outlined),
  NavItem(screen: AppScreen.analytics, label: 'Analytics', icon: Icons.bar_chart_rounded),
  NavItem(screen: AppScreen.adminFinance, label: 'Transactions', icon: Icons.receipt_long_rounded),
];

const teacherNav = [
  NavItem(screen: AppScreen.teacherHome, label: 'Home', icon: Icons.home_rounded),
  NavItem(screen: AppScreen.teacherClasses, label: 'Classes', icon: Icons.school_outlined),
  NavItem(screen: AppScreen.homework, label: 'Homework', icon: Icons.menu_book_outlined),
  NavItem(screen: AppScreen.teacherAttendance, label: 'Attendance', icon: Icons.fact_check_outlined),
];

/// The website's cashier menu in four tabs; Announcements is in the
/// header's comms menu instead.
const cashierNav = [
  NavItem(screen: AppScreen.cashierCounter, label: 'Counter', icon: Icons.point_of_sale_rounded),
  NavItem(screen: AppScreen.feedingToday, label: 'Feeding', icon: Icons.restaurant_rounded),
  NavItem(screen: AppScreen.schoolLife, label: 'Calendar', icon: Icons.calendar_month_outlined),
  NavItem(screen: AppScreen.myAttendance, label: 'Me', icon: Icons.how_to_reg_outlined),
];

/// The website's Finance (bursar) menu, condensed for the bottom bar.
const financeNav = [
  NavItem(screen: AppScreen.staffHome, label: 'Home', icon: Icons.home_rounded),
  NavItem(screen: AppScreen.adminFinance, label: 'Payments', icon: Icons.receipt_long_rounded),
  NavItem(screen: AppScreen.expenses, label: 'Expenses', icon: Icons.account_balance_wallet_outlined),
  NavItem(screen: AppScreen.feedingToday, label: 'Feeding', icon: Icons.restaurant_rounded),
];

const platformNav = [
  NavItem(screen: AppScreen.platformHome, label: 'Home', icon: Icons.home_rounded),
  NavItem(screen: AppScreen.platformSchools, label: 'Schools', icon: Icons.apartment_outlined),
  NavItem(screen: AppScreen.platformSignupRequests, label: 'Signups', icon: Icons.playlist_add_check_rounded),
  NavItem(screen: AppScreen.platformContactMessages, label: 'Messages', icon: Icons.mail_outline_rounded),
];

IconData iconFor(String name) {
  switch (name) {
    case 'home':
      return Icons.home_rounded;
    case 'users':
      return Icons.groups_rounded;
    case 'dollar':
      return Icons.payments_rounded;
    case 'bell':
      return Icons.notifications_rounded;
    case 'megaphone':
      return Icons.campaign_rounded;
    case 'qr':
      return Icons.qr_code_2_rounded;
    case 'book':
      return Icons.menu_book_rounded;
    case 'check':
      return Icons.check_rounded;
    case 'msg':
      return Icons.chat_bubble_rounded;
    case 'chart':
      return Icons.bar_chart_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'calendar':
      return Icons.calendar_month_rounded;
    case 'scan':
      return Icons.qr_code_scanner_rounded;
    case 'add':
      return Icons.add_rounded;
    case 'send':
      return Icons.send_rounded;
    case 'shield':
      return Icons.verified_user_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'logout':
      return Icons.logout_rounded;
    default:
      return Icons.star_rounded;
  }
}

bool navItemActive(AppScreen item, AppScreen active, {bool grouped = true}) {
  if (item == active) return true;
  if (item == AppScreen.teacherClasses &&
      (active == AppScreen.teacherAttendance || active == AppScreen.attendance)) {
    return true;
  }
  return false;
}

String timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 5) return 'Still going';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}

String dashWelcome() {
  final hour = DateTime.now().hour;
  if (hour < 12) return "Let's make today count";
  if (hour < 17) return "Here's the live picture";
  return "Here's how the day is wrapping up";
}

List<NavItem> navFor(Role role) {
  switch (role) {
    case Role.parent:
      return parentNav;
    case Role.teacher:
      return teacherNav;
    case Role.platformAdmin:
      return platformNav;
    case Role.cashier:
      return cashierNav;
    case Role.accountant:
      return financeNav;
    case Role.admin:
    case Role.schoolAdmin:
      return adminNav;
    default:
      return adminNav;
  }
}

AppScreen homeFor(Role role) {
  switch (role) {
    case Role.parent:
      return AppScreen.parentHome;
    case Role.teacher:
      return AppScreen.teacherHome;
    case Role.platformAdmin:
      return AppScreen.platformHome;
    case Role.cashier:
      return AppScreen.cashierCounter;
    case Role.admin:
    case Role.schoolAdmin:
      return AppScreen.adminHome;
    default:
      return AppScreen.staffHome;
  }
}

class SidebarGroup {
  const SidebarGroup({this.title, required this.items});

  final String? title;
  final List<NavItem> items;
}

List<SidebarGroup> sidebarFor(Role role, [Set<AppScreen>? allowed]) {
  final groups = switch (role) {
    Role.parent => [
        const SidebarGroup(items: parentNav),
        const SidebarGroup(
          title: 'School',
          items: [
            NavItem(screen: AppScreen.adminStudents, label: 'My children', icon: Icons.family_restroom_outlined),
            NavItem(screen: AppScreen.adminClasses, label: 'Class details', icon: Icons.class_outlined),
            NavItem(screen: AppScreen.adminTimetable, label: 'Timetable', icon: Icons.calendar_month_outlined),
            NavItem(screen: AppScreen.homework, label: 'Assignments', icon: Icons.menu_book_outlined),
            NavItem(screen: AppScreen.adminAcademics, label: 'Exams', icon: Icons.assignment_outlined),
            NavItem(screen: AppScreen.attendance, label: 'Attendance', icon: Icons.fact_check_outlined),
            NavItem(screen: AppScreen.parentReports, label: 'Reports', icon: Icons.description_outlined),
            NavItem(screen: AppScreen.payments, label: 'Fees', icon: Icons.receipt_long_outlined),
            NavItem(screen: AppScreen.teacherAnnouncements, label: 'Announcements', icon: Icons.campaign_outlined),
            NavItem(screen: AppScreen.messages, label: 'Messages', icon: Icons.chat_bubble_outline_rounded),
            NavItem(screen: AppScreen.schoolLife, label: 'School life', icon: Icons.dashboard_customize_outlined),
            NavItem(screen: AppScreen.library, label: 'Library', icon: Icons.local_library_outlined),
          ],
        ),
      ],
    Role.teacher => [
        const SidebarGroup(items: teacherNav),
        const SidebarGroup(
          title: 'Class work',
          items: [
            NavItem(screen: AppScreen.adminClasses, label: 'Class details', icon: Icons.class_outlined),
            NavItem(screen: AppScreen.adminAcademics, label: 'Academics', icon: Icons.assignment_outlined),
            NavItem(screen: AppScreen.teacherMyReports, label: 'My reports', icon: Icons.description_outlined),
            NavItem(screen: AppScreen.adminTimetable, label: 'Timetable', icon: Icons.calendar_month_outlined),
            NavItem(screen: AppScreen.schoolLife, label: 'School life', icon: Icons.dashboard_customize_outlined),
          ],
        ),
      ],
    _ => [
        const SidebarGroup(
          items: [
            NavItem(screen: AppScreen.adminHome, label: 'Home', icon: Icons.home_rounded),
          ],
        ),
        SidebarGroup(
          title: 'People',
          items: [
            if (role.canManageRoles)
              const NavItem(screen: AppScreen.adminRoles, label: 'Roles', icon: Icons.manage_accounts_outlined),
            const NavItem(screen: AppScreen.adminTeachers, label: 'Teachers', icon: Icons.school_outlined),
            const NavItem(screen: AppScreen.subjectAssignments, label: 'Subject assignments', icon: Icons.assignment_ind_outlined),
            const NavItem(screen: AppScreen.adminParents, label: 'Parents', icon: Icons.family_restroom_outlined),
            const NavItem(screen: AppScreen.adminStudents, label: 'Students', icon: Icons.groups_rounded),
          ],
        ),
        const SidebarGroup(
          title: 'School',
          items: [
            NavItem(screen: AppScreen.adminTimetable, label: 'Timetable', icon: Icons.calendar_month_outlined),
            NavItem(screen: AppScreen.adminClasses, label: 'Class details', icon: Icons.class_outlined),
            NavItem(screen: AppScreen.attendance, label: 'Attendance', icon: Icons.front_hand_outlined),
            NavItem(screen: AppScreen.staffAttendance, label: 'Teacher attendance', icon: Icons.badge_outlined),
            NavItem(screen: AppScreen.schoolAffairs, label: 'School affairs', icon: Icons.account_balance_outlined),
            NavItem(screen: AppScreen.teacherAnnouncements, label: 'Announcements', icon: Icons.campaign_outlined),
            NavItem(screen: AppScreen.adminManage, label: 'Browse records', icon: Icons.grid_view_outlined),
            NavItem(screen: AppScreen.adminFinance, label: 'Transactions', icon: Icons.receipt_long_rounded),
            NavItem(screen: AppScreen.teacherReports, label: 'Reports', icon: Icons.description_outlined),
            NavItem(screen: AppScreen.analytics, label: 'Analytics', icon: Icons.bar_chart_rounded),
          ],
        ),
      ],
  };
  // Modules the school's plan leaves out aren't listed at all.
  final planned = [
    for (final group in groups)
      SidebarGroup(
        title: group.title,
        items: [for (final item in group.items) if (PlanAccess.allows(item.screen)) item],
      ),
  ];
  if (allowed == null || allowed.isEmpty) return planned;
  return [
    for (final group in planned)
      if (group.items.any((item) => allowed.contains(item.screen)))
        SidebarGroup(
          title: group.title,
          items: [for (final item in group.items) if (allowed.contains(item.screen)) item],
        ),
  ];
}
