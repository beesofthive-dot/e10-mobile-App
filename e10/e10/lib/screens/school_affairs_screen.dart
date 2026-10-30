import 'package:flutter/material.dart';

import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/area_grid.dart';
import '../widgets/common.dart';

class SchoolAffairsScreen extends StatelessWidget {
  const SchoolAffairsScreen({
    super.key,
    required this.onNav,
    required this.onBack,
    required this.onLogout,
  });

  final ValueChanged<AppScreen> onNav;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final present = store.students.where((s) => store.rollOf(s.id) == 'present').length;
    return Column(
      children: [
        TopBar(
          title: 'School affairs',
          subtitle: 'View only · office creates records',
          onBack: onBack,
          onLogout: onLogout,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              const SectionLabel(text: 'People'),
              MetricGrid(
                tiles: [
                  MetricTile(label: 'Students', value: '${store.students.length}', onTap: () => onNav(AppScreen.adminStudents)),
                  MetricTile(label: 'Teachers', value: '${store.teachers.length}', onTap: () => onNav(AppScreen.adminTeachers)),
                  MetricTile(label: 'Parents', value: '${store.parents.length}', onTap: () => onNav(AppScreen.adminParents)),
                  MetricTile(label: 'Billing staff', value: '${store.accountants.length}', onTap: () => onNav(AppScreen.adminAccountants)),
                ],
              ),
              const SizedBox(height: 16),
              const SectionLabel(text: 'Academics'),
              MetricGrid(
                tiles: [
                  MetricTile(label: 'Classes', value: '${store.classes.length}', onTap: () => onNav(AppScreen.adminClasses)),
                  if (PlanAccess.allows(AppScreen.adminDepartments))
                  MetricTile(label: 'Departments', value: '${store.departments.length}', onTap: () => onNav(AppScreen.adminDepartments)),
                  if (PlanAccess.allows(AppScreen.adminTimetable))
                  MetricTile(label: 'Timetable', value: '${store.timetable.length}', onTap: () => onNav(AppScreen.adminTimetable)),
                  if (PlanAccess.allows(AppScreen.adminAcademics))
                  MetricTile(label: 'Marks', value: '${store.academics.length}', onTap: () => onNav(AppScreen.adminAcademics)),
                  if (PlanAccess.allows(AppScreen.attendance))
                  MetricTile(label: 'Present today', value: '$present', onTap: () => onNav(AppScreen.attendance)),
                  if (PlanAccess.allows(AppScreen.teacherReports))
                  MetricTile(label: 'Reports', value: '${store.academicReports.length}', onTap: () => onNav(AppScreen.teacherReports)),
                  MetricTile(label: 'School life', value: '${store.tableRows('calendar_events').length}', onTap: () => onNav(AppScreen.schoolLife)),
                  if (PlanAccess.allows(AppScreen.adminFinance))
                  MetricTile(label: 'Invoices', value: '${store.invoices.length}', onTap: () => onNav(AppScreen.adminFinance)),
                ],
              ),
              const SizedBox(height: 16),
              SectionLabel(text: 'Classes', action: 'Open', onAction: () => onNav(AppScreen.adminClasses)),
              ActionGrid(
                items: [
                  for (final c in store.classes)
                    ActionGridItem(
                      label: c.name,
                      hint: c.link.isEmpty ? '${store.studentsIn(c.name)} pupils' : c.link,
                      icon: Icons.class_outlined,
                      onTap: () => onNav(AppScreen.adminClasses),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SectionLabel(text: 'Teachers', action: 'Open', onAction: () => onNav(AppScreen.adminTeachers)),
              ActionGrid(
                items: [
                  for (final t in store.teachers)
                    ActionGridItem(
                      label: t.name,
                      hint: t.detail.isEmpty ? 'Teacher' : t.detail,
                      icon: Icons.school_outlined,
                      onTap: () => onNav(AppScreen.adminTeachers),
                    ),
                ],
              ),
              if (PlanAccess.allows(AppScreen.adminDepartments)) ...[
              const SizedBox(height: 16),
              SectionLabel(text: 'Departments', action: 'Open', onAction: () => onNav(AppScreen.adminDepartments)),
              ActionGrid(
                items: [
                  for (final d in store.departments)
                    ActionGridItem(
                      label: d.name,
                      hint: d.detail.isEmpty ? 'Department' : d.detail,
                      icon: Icons.menu_book_outlined,
                      onTap: () => onNav(AppScreen.adminDepartments),
                    ),
                ],
              ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
