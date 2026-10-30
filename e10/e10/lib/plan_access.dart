import 'models.dart';

/// Website module keys (see `Bt` in the live site) and how they read to users.
const Map<String, String> planModuleLabels = {
  'attendance': 'Attendance',
  'announcements': 'Announcements',
  'school_structure': 'Departments & houses',
  'messages': 'Messages',
  'fees': 'Fees & payments',
  'daily_reports': 'Daily reports',
  'timetable_assignments': 'Timetable & assignments',
  'academics': 'Exams & report cards',
  'operations': 'Buses, library, inventory & leave',
  'audit_logs': 'Audit logs',
  'feeding': 'Feeding',
};

/// The plan module a screen belongs to, or null when every plan has it.
String? planModuleFor(AppScreen screen) => switch (screen) {
      AppScreen.attendance ||
      AppScreen.teacherAttendance ||
      AppScreen.staffAttendance ||
      AppScreen.departmentAttendance ||
      AppScreen.myAttendance =>
        'attendance',
      AppScreen.feedingToday || AppScreen.parentFeeding => 'feeding',
      AppScreen.teacherDailyReports || AppScreen.parentDailyReport => 'daily_reports',
      AppScreen.homework || AppScreen.adminTimetable => 'timetable_assignments',
      AppScreen.teacherExams ||
      AppScreen.teacherReports ||
      AppScreen.teacherMyReports ||
      AppScreen.parentReports ||
      AppScreen.adminAcademics ||
      AppScreen.adminReports =>
        'academics',
      AppScreen.messages => 'messages',
      AppScreen.teacherAnnouncements => 'announcements',
      AppScreen.adminDepartments || AppScreen.departmentHeads => 'school_structure',
      AppScreen.adminFinance || AppScreen.payments || AppScreen.expenses => 'fees',
      AppScreen.auditLog => 'audit_logs',
      AppScreen.library => 'operations',
      _ => null,
    };

/// The module [screen] needs that [user]'s school plan doesn't include.
String? lockedPlanModule(AppUser user, AppScreen screen) {
  final modules = user.schoolModules;
  if (modules == null || user.role == Role.platformAdmin) return null;
  final module = planModuleFor(screen);
  return module == null || modules.contains(module) ? null : module;
}

/// The signed-in user's plan, for widgets that don't get the user passed
/// in. Set by the app whenever the user changes.
class PlanAccess {
  static AppUser? user;

  /// False when [screen] belongs to a module the school's plan leaves out —
  /// links to it are hidden rather than leading to a "not in your plan" page.
  static bool allows(AppScreen screen) {
    final u = user;
    return u == null || lockedPlanModule(u, screen) == null;
  }

  static bool hasModule(String module) {
    final modules = user?.schoolModules;
    return modules == null || user!.role == Role.platformAdmin || modules.contains(module);
  }
}
