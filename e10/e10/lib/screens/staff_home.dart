import 'package:flutter/material.dart';

import '../feeding.dart';
import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import 'department_screen.dart';
import '../widgets/area_grid.dart';
import '../widgets/dash_cards.dart';
import '../widgets/common.dart';
import '../widgets/home_cards.dart';
import '../widgets/money_dashboard_card.dart';
import '../widgets/motion.dart';

class StaffHome extends StatelessWidget {
  const StaffHome({
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
    final role = user.role;
    return Column(
      children: [
        DashAccountHeader(
          user: user,
          subtitle: '${role.label} · ${store.brandedSchoolName}',
          onLogout: onLogout,
          onTapSchool: () => onNav(AppScreen.schoolProfile),
        ),
        const SyncBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => store.syncFromApi(),
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppLayout.page(context),
            children: dashboardChildren(context, [
              WhiteCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.label, style: AppText.display(size: 18, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(role.tagline, style: AppText.body(size: 14, color: AppSurface.ink(context))),
                  ],
                ),
              ),
              if (user.isDepartmentHead) ...[
                const SizedBox(height: 16),
                DepartmentHeadCard(user: user, onNav: onNav),
              ],
              if (role == Role.accountant && PlanAccess.allows(AppScreen.adminFinance)) ...[
                const SizedBox(height: 16),
                MoneyDashboardCard(user: user),
                const SizedBox(height: 16),
                FinanceDashboardCard(
                  collected: 'GHS ${store.feesCollected().toStringAsFixed(2)}',
                  outstanding: 'GHS ${store.feesOutstanding().toStringAsFixed(2)}',
                  hint: '${store.feesPaymentCount()} landed · ${store.unpaidBillCount()} still open',
                  recent: [
                    for (final row in store.recentFeePayments())
                      FinanceDashRow(
                        name: store.paymentStudentName(row).isEmpty ? 'Fee payment' : store.paymentStudentName(row),
                        amount: 'GHS ${store.paymentAmount(row).toStringAsFixed(2)}',
                        meta: store.paymentMethodLabel(row),
                      ),
                  ],
                  onOpen: () => onNav(AppScreen.adminFinance),
                ),
              ],
              const SizedBox(height: 16),
              const SectionLabel(text: 'Jump in'),
              AreaGrid(
                onOpen: onNav,
                areas: [
                  for (final a in _actions(role))
                    if (PlanAccess.allows(a.screen) &&
                        (a.screen != AppScreen.feedingToday || FeedingAccess.viewFeeding(user)) &&
                        (a.screen != AppScreen.expenses || FeedingAccess.viewExpenses(user)))
                    AreaTileData(
                      label: a.label,
                      hint: 'Open it',
                      icon: a.icon,
                      screen: a.screen,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionLabel(text: 'Latest'),
              if (store.noticesFor(role).isEmpty)
                Text('No new notifications.', style: AppText.body(size: 13, color: AppSurface.ink(context)))
              else
                for (final n in store.noticesFor(role).take(4)) ...[
                  AlertTile(text: n.text, time: n.time, icon: n.icon, color: n.color, unread: n.unread),
                  const SizedBox(height: 8),
                ],
            ]),
            ),
          ),
        ),
      ],
    );
  }

  List<QuickAction> _actions(Role role) {
    switch (role) {
      case Role.accountant:
        return const [
          QuickAction(label: 'Transactions', icon: Icons.receipt_long_rounded, tone: ToneRef.honey, screen: AppScreen.adminFinance),
          QuickAction(label: 'Expenses', icon: Icons.account_balance_wallet_outlined, tone: ToneRef.violet, screen: AppScreen.expenses),
          QuickAction(label: 'Feeding', icon: Icons.restaurant_rounded, tone: ToneRef.rose, screen: AppScreen.feedingToday),
          QuickAction(label: 'Students', icon: Icons.groups_rounded, tone: ToneRef.emerald, screen: AppScreen.adminStudents),
          QuickAction(label: 'Guardians', icon: Icons.family_restroom_rounded, tone: ToneRef.sky, screen: AppScreen.adminParents),
          QuickAction(label: 'My attendance', icon: Icons.how_to_reg_outlined, tone: ToneRef.honey, screen: AppScreen.myAttendance),
          QuickAction(label: 'Reports', icon: Icons.bar_chart_rounded, tone: ToneRef.violet, screen: AppScreen.analytics),
        ];
      case Role.examOfficer:
        return const [
          QuickAction(label: 'Marks', icon: Icons.assignment_rounded, tone: ToneRef.sky, screen: AppScreen.adminAcademics),
          QuickAction(label: 'Reports', icon: Icons.description_rounded, tone: ToneRef.honey, screen: AppScreen.adminReports),
          QuickAction(label: 'Timetable', icon: Icons.calendar_month_rounded, tone: ToneRef.violet, screen: AppScreen.adminTimetable),
          QuickAction(label: 'Students', icon: Icons.groups_rounded, tone: ToneRef.emerald, screen: AppScreen.adminStudents),
        ];
      case Role.secretary:
        return const [
          QuickAction(label: 'Students', icon: Icons.groups_rounded, tone: ToneRef.sky, screen: AppScreen.adminStudents),
          QuickAction(label: 'Parents', icon: Icons.family_restroom_rounded, tone: ToneRef.honey, screen: AppScreen.adminParents),
          QuickAction(label: 'Attendance', icon: Icons.fact_check_rounded, tone: ToneRef.emerald, screen: AppScreen.attendance),
          QuickAction(label: 'Timetable', icon: Icons.calendar_month_rounded, tone: ToneRef.violet, screen: AppScreen.adminTimetable),
        ];
      case Role.librarian:
        return const [
          QuickAction(label: 'Library', icon: Icons.local_library_rounded, tone: ToneRef.honey, screen: AppScreen.library),
          QuickAction(label: 'Students', icon: Icons.groups_rounded, tone: ToneRef.sky, screen: AppScreen.adminStudents),
          QuickAction(label: 'Classes', icon: Icons.class_rounded, tone: ToneRef.emerald, screen: AppScreen.adminClasses),
          QuickAction(label: 'Timetable', icon: Icons.calendar_month_rounded, tone: ToneRef.violet, screen: AppScreen.adminTimetable),
        ];
      case Role.nurse:
        return const [
          QuickAction(label: 'Clinic', icon: Icons.medical_services_rounded, tone: ToneRef.rose, screen: AppScreen.clinic),
          QuickAction(label: 'Students', icon: Icons.groups_rounded, tone: ToneRef.sky, screen: AppScreen.adminStudents),
          QuickAction(label: 'Attendance', icon: Icons.fact_check_rounded, tone: ToneRef.emerald, screen: AppScreen.attendance),
          QuickAction(label: 'Classes', icon: Icons.class_rounded, tone: ToneRef.honey, screen: AppScreen.adminClasses),
        ];
      case Role.ictAdmin:
        return const [
          QuickAction(label: 'School', icon: Icons.apartment_rounded, tone: ToneRef.sky, screen: AppScreen.adminManage),
          QuickAction(label: 'Users', icon: Icons.manage_accounts_rounded, tone: ToneRef.honey, screen: AppScreen.adminTeachers),
          QuickAction(label: 'Classes', icon: Icons.class_rounded, tone: ToneRef.violet, screen: AppScreen.adminClasses),
          QuickAction(label: 'Analytics', icon: Icons.bar_chart_rounded, tone: ToneRef.emerald, screen: AppScreen.analytics),
        ];
      default:
        return const [
          QuickAction(label: 'Students', icon: Icons.groups_rounded, tone: ToneRef.sky, screen: AppScreen.adminStudents),
          QuickAction(label: 'Attendance', icon: Icons.fact_check_rounded, tone: ToneRef.honey, screen: AppScreen.attendance),
        ];
    }
  }
}
