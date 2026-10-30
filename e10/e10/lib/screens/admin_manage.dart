import 'package:flutter/material.dart';

import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/area_grid.dart';
import '../widgets/common.dart';

class AdminManageScreen extends StatelessWidget {
  const AdminManageScreen({
    super.key,
    required this.role,
    required this.onNav,
    required this.onLogout,
    this.onBack,
    this.canManageRoles,
  });

  final Role role;
  final bool? canManageRoles;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback onLogout;
  final VoidCallback? onBack;

  static const _groups = [
    (
      'School affairs',
      [
        _Module('Overview', 'All records', Icons.account_balance_outlined, AppScreen.schoolAffairs),
        _Module('School life', 'Calendar & leave', Icons.dashboard_customize_outlined, AppScreen.schoolLife),
        _Module('Announcements', 'Post & browse notices', Icons.campaign_outlined, AppScreen.teacherAnnouncements),
        _Module('Reports', 'Class tables', Icons.table_chart_outlined, AppScreen.teacherReports),
        _Module('Other reports', 'Incoming files', Icons.article_outlined, AppScreen.adminReports),
        _Module('Analytics', 'Performance', Icons.bar_chart_outlined, AppScreen.analytics),
      ],
    ),
    (
      'People',
      [
        _Module('Teachers', 'Staff directory', Icons.school_outlined, AppScreen.adminTeachers),
        _Module('Staff', 'Billing staff', Icons.badge_outlined, AppScreen.adminAccountants),
        _Module('Parents', 'Guardians', Icons.family_restroom_outlined, AppScreen.adminParents),
        _Module('Students', 'Pupils', Icons.groups_outlined, AppScreen.adminStudents),
      ],
    ),
    (
      'Academics',
      [
        _Module('Classes', 'Class list', Icons.class_outlined, AppScreen.adminClasses),
        _Module('Departments', 'Departments', Icons.menu_book_outlined, AppScreen.adminDepartments),
        _Module('Timetable', 'Schedules', Icons.calendar_month_outlined, AppScreen.adminTimetable),
        _Module('Attendance', 'Class roll', Icons.fact_check_outlined, AppScreen.attendance),
        _Module('Examinations', 'Marks', Icons.assignment_outlined, AppScreen.adminAcademics),
      ],
    ),
    (
      'Transactions',
      [
        _Module('Billing', 'Fees, invoices & payouts', Icons.receipt_long_outlined, AppScreen.adminFinance),
      ],
    ),
    (
      'Records',
      [
        _Module('Academic years', 'Year records', Icons.timeline_outlined, AppScreen.catalog, 'academic_years'),
        _Module('Terms', 'Term records', Icons.date_range_outlined, AppScreen.catalog, 'academic_terms'),
        _Module('Exams', 'Exam papers', Icons.quiz_outlined, AppScreen.catalog, 'exams'),
        _Module('Attendance log', 'Daily marks', Icons.fact_check_outlined, AppScreen.catalog, 'attendance'),
        _Module('Book loans', 'Borrowed titles', Icons.menu_book_outlined, AppScreen.catalog, 'book_loans'),
        _Module('Staff rows', 'All staff', Icons.badge_outlined, AppScreen.catalog, 'staff'),
      ],
    ),
    (
      'Services',
      [
        _Module('Payments', 'Fee receipts', Icons.receipt_long_outlined, AppScreen.catalog, 'payments'),
        _Module('Library', 'Books & loans', Icons.local_library_outlined, AppScreen.library),
        _Module('Clinic', 'Nurse desk', Icons.medical_services_outlined, AppScreen.clinic),
        _Module('Houses', 'Boarding', Icons.home_work_outlined, AppScreen.catalog, 'houses'),
        _Module('Subjects', 'Subjects', Icons.auto_stories_outlined, AppScreen.catalog, 'subjects'),
        _Module('Enrollments', 'Placements', Icons.how_to_reg_outlined, AppScreen.catalog, 'enrollments'),
        _Module('Inventory', 'Stores', Icons.inventory_2_outlined, AppScreen.catalog, 'inventory_items'),
        _Module('Leave', 'Staff leave', Icons.event_busy_outlined, AppScreen.catalog, 'leave_requests'),
        _Module('Transport', 'Buses', Icons.directions_bus_outlined, AppScreen.catalog, 'buses'),
        _Module('Routes', 'Bus routes', Icons.alt_route_outlined, AppScreen.catalog, 'bus_routes'),
        _Module('Calendar', 'Events', Icons.event_outlined, AppScreen.catalog, 'calendar_events'),
      ],
    ),
  ];

  /// Plan module behind each catalog table, matching the website's pages.
  static const _catalogModule = {
    'exams': 'academics',
    'attendance': 'attendance',
    'payments': 'fees',
    'houses': 'school_structure',
    'subjects': 'timetable_assignments',
    'book_loans': 'operations',
    'inventory_items': 'operations',
    'leave_requests': 'operations',
    'buses': 'operations',
    'bus_routes': 'operations',
  };

  List<(String, List<_Module>)> get _visible {
    final allowRoles = canManageRoles ?? role.canManageRoles;
    return [
      for (final group in _groups)
        (
          group.$1,
          [
            for (final m in group.$2)
              if ((m.screen != AppScreen.adminRoles || allowRoles) &&
                  (m.tableKey != 'permissions' || allowRoles) &&
                  role.canOpen(m.screen) &&
                  PlanAccess.allows(m.screen) &&
                  (_catalogModule[m.tableKey] == null || PlanAccess.hasModule(_catalogModule[m.tableKey]!)))
                m,
          ],
        ),
    ].where((group) => group.$2.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopBar(
          title: 'School modules',
          subtitle: 'Tap a card to open',
          onBack: onBack,
          onLogout: onLogout,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              for (final group in _visible) ...[
                SectionLabel(text: group.$1),
                ActionGrid(
                  items: [
                    for (final module in group.$2)
                      ActionGridItem(
                        label: module.title,
                        hint: module.subtitle,
                        icon: module.icon,
                        onTap: () {
                          if (module.tableKey != null) {
                            SchoolScope.of(context).openCatalog(module.tableKey!, module.title);
                          }
                          onNav(module.screen);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Module {
  const _Module(this.title, this.subtitle, this.icon, this.screen, [this.tableKey]);
  final String title;
  final String subtitle;
  final IconData icon;
  final AppScreen screen;
  final String? tableKey;
}
