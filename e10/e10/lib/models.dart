import 'package:flutter/material.dart';

enum Role {
  parent,
  teacher,
  admin,
  schoolAdmin,
  accountant,
  cashier,
  examOfficer,
  secretary,
  librarian,
  nurse,
  ictAdmin,
  platformAdmin,
}

extension RoleFields on Role {
  String get label => switch (this) {
        Role.parent => 'Parent',
        Role.teacher => 'Teacher',
        Role.admin => 'Deputy Admin',
        Role.schoolAdmin => 'School Admin',
        Role.accountant => 'Accountant',
        Role.cashier => 'Cashier',
        Role.examOfficer => 'Exam Officer',
        Role.secretary => 'Secretary',
        Role.librarian => 'Librarian',
        Role.nurse => 'Nurse',
        Role.ictAdmin => 'ICT Admin',
        Role.platformAdmin => 'Platform Admin',
      };

  String get portalName => switch (this) {
        Role.parent => 'Parent Portal',
        Role.teacher => 'Teacher Portal',
        Role.admin => 'Deputy Admin Portal',
        Role.schoolAdmin => 'School Admin Portal',
        Role.platformAdmin => 'BeeSoft Hive Platform',
        _ => '$label Portal',
      };

  String get tagline => switch (this) {
        Role.parent => 'Stay close — school, fees, timetable and the little wins.',
        Role.teacher => 'Your class, your roll, your rhythm. Let’s go.',
        Role.admin => 'A clear view of the school. Jump in wherever you need.',
        Role.schoolAdmin => 'The whole school at a glance. Tap anything to dive in.',
        Role.accountant => 'Money in, bills out — keep every cedi moving.',
        Role.cashier => 'Fees and feeding at the counter, with a receipt for every cedi.',
        Role.examOfficer => 'Marks, reports and the timetable, all in one flow.',
        Role.secretary => 'Admissions, parents and the day’s paper trail.',
        Role.librarian => 'Books out, books in — keep the shelves humming.',
        Role.nurse => 'Clinic visits and health notes, ready when you are.',
        Role.ictAdmin => 'Systems, people and classes — keep the hive online.',
        Role.platformAdmin => 'Every school on e10, one dashboard.',
      };

  IconData get icon => switch (this) {
        Role.parent => Icons.family_restroom_rounded,
        Role.teacher => Icons.school_rounded,
        Role.admin => Icons.admin_panel_settings_rounded,
        Role.schoolAdmin => Icons.apartment_rounded,
        Role.accountant => Icons.payments_rounded,
        Role.cashier => Icons.point_of_sale_rounded,
        Role.examOfficer => Icons.assignment_rounded,
        Role.secretary => Icons.badge_rounded,
        Role.librarian => Icons.local_library_rounded,
        Role.nurse => Icons.medical_services_rounded,
        Role.ictAdmin => Icons.computer_rounded,
        Role.platformAdmin => Icons.hub_rounded,
      };

  bool get canSubmitAttendance => this == Role.teacher;
  bool get isAdminPortal => this == Role.schoolAdmin || this == Role.admin;
  bool get isPlatformAdmin => this == Role.platformAdmin;
  bool get canManageRoles => this == Role.schoolAdmin;

  bool canOpen(AppScreen screen) {
    if (departmentScreens.contains(screen)) return false;
    if (this == Role.teacher) {
      return const {
        AppScreen.teacherHome,
        AppScreen.teacherClasses,
        AppScreen.teacherAttendance,
        AppScreen.attendance,
        AppScreen.homework,
        AppScreen.teacherExams,
        AppScreen.teacherAnnouncements,
        AppScreen.teacherDailyReports,
        AppScreen.adminAcademics,
        AppScreen.teacherMyReports,
        AppScreen.messages,
        AppScreen.notifications,
        AppScreen.inbox,
        AppScreen.schoolLife,
        AppScreen.library,
        AppScreen.adminTimetable,
        AppScreen.adminClasses,
        AppScreen.auditLog,
        AppScreen.schoolProfile,
      }.contains(screen);
    }
    if (isPlatformAdmin) {
      return const {
        AppScreen.platformHome,
        AppScreen.platformSchools,
        AppScreen.platformSignupRequests,
        AppScreen.platformContactMessages,
      }.contains(screen);
    }
    // Same pages as the website's cashier menu.
    if (this == Role.cashier) {
      return const {
        AppScreen.cashierCounter,
        AppScreen.feedingToday,
        AppScreen.teacherAnnouncements,
        AppScreen.schoolLife,
        AppScreen.myAttendance,
        AppScreen.notifications,
        // Only offered when the school gives the cashier `messages.view`.
        AppScreen.messages,
        AppScreen.schoolProfile,
      }.contains(screen);
    }
    if (isAdminPortal && screen == AppScreen.adminRoles) return canManageRoles;
    // The school-wide Transactions dashboard is staff-only; parents pay
    // their own child's fees from AppScreen.payments instead.
    if (this == Role.parent) {
      return screen != AppScreen.adminFinance &&
          screen != AppScreen.staffAttendance &&
          screen != AppScreen.cashierCounter &&
          screen != AppScreen.feedingToday &&
          screen != AppScreen.myAttendance &&
          screen != AppScreen.expenses;
    }
    if (screen == AppScreen.parentFeeding) return false;
    return true;
  }
}

/// How a teacher's dashboard is shaped, detected from what the admin set up
/// for them (their department and whether they hold a homeroom class) rather
/// than a manual choice at login.
enum TeacherKind { kg, classTeacher, subject }

/// One department this staff member heads (`department_heads` in the
/// login/`auth/me` reply). A main head manages the department's other heads;
/// an assistant only has the permissions the main head ticked.
class DepartmentHeadship {
  const DepartmentHeadship({required this.departmentId, this.departmentName = '', this.isMain = false});

  final String departmentId;
  final String departmentName;
  final bool isMain;
}

class AppUser {
  const AppUser({
    required this.email,
    required this.displayName,
    required this.role,
    required this.subtitle,
    this.password = '',
    this.schoolId = '',
    this.school = '',
    this.schoolCode = '',
    this.permissions = const [],
    this.roleSlugs = const [],
    this.phone = '',
    this.schoolLogoUrl = '',
    this.appearance = 'light',
    this.department = '',
    this.dailyReportsEligible = false,
    this.schoolModules,
    this.planName = '',
    this.planGrade = '',
    this.accessLevel = '',
    this.blockReason = '',
    this.departmentHeads = const [],
  });

  final String email;
  final String password;
  final String schoolId;
  final String displayName;
  final Role role;
  final String subtitle;
  final String school;
  final String schoolCode;
  final List<String> permissions;
  final List<String> roleSlugs;
  final String phone;
  final String schoolLogoUrl;
  final String appearance;

  /// The staff department the admin assigned when registering this user
  /// (e.g. "PreSchool", "Mathematics").
  final String department;

  /// Straight from `daily_reports_eligible` in the login/`auth/me` response —
  /// the API already decides this server-side (based on the teacher's
  /// department having `is_early_years: true`), so it's the authoritative
  /// signal for routing a teacher to the KG dashboard instead of guessing
  /// from the department name on-device.
  final bool dailyReportsEligible;

  /// `school.modules` from the login/`auth/me` reply: the modules the
  /// school's subscription plan (Grade A/B/C, plus any extras switched on
  /// from the website) unlocks. Null when the server doesn't send a list —
  /// then nothing is locked, matching the website.
  final List<String>? schoolModules;
  final String planName;
  final String planGrade;

  /// `subscription_access.access_level` — `none` means the whole school is
  /// locked (unpaid term), with [blockReason] saying why.
  final String accessLevel;
  final String blockReason;

  /// The departments this person heads; empty for everyone else.
  final List<DepartmentHeadship> departmentHeads;

  /// School admins already see the whole school, and a guardian login has no
  /// staff pages, so "My department" is only for other staff (as on the
  /// website).
  bool get isDepartmentHead =>
      departmentHeads.isNotEmpty && !role.isAdminPortal && !role.isPlatformAdmin && role != Role.parent;

  bool get isMainDepartmentHead => isDepartmentHead && departmentHeads.any((h) => h.isMain);

  /// [Role.canOpen], plus the "My department" pages, which also need the
  /// same permission the website asks for each one.
  bool canOpen(AppScreen screen) => switch (screen) {
        AppScreen.departmentHome => isDepartmentHead,
        AppScreen.departmentStudents => isDepartmentHead && permissions.contains('students.view'),
        AppScreen.departmentStaff => isDepartmentHead && permissions.contains('staff.view'),
        AppScreen.departmentClasses => isDepartmentHead && permissions.contains('classes.view'),
        AppScreen.departmentAttendance => isDepartmentHead && permissions.contains('attendance.view'),
        AppScreen.departmentHeads => isMainDepartmentHead,
        _ => role.canOpen(screen),
      };

  bool get canManageRoles => permissions.contains('roles.manage') || role == Role.schoolAdmin;

  /// True when the admin set this teacher up under an early-years/KG
  /// department.
  bool get isKgDepartment => role == Role.teacher && dailyReportsEligible;
}

enum AppScreen {
  staffAttendance,
  splash,
  landing,
  login,
  parentHome,
  adminHome,
  teacherHome,
  staffHome,
  payments,
  studentDetail,
  attendance,
  homework,
  teacherDailyReports,
  messages,
  notifications,
  inbox,
  adminStudents,
  adminFinance,
  teacherAttendance,
  teacherClasses,
  teacherExams,
  teacherAnnouncements,
  analytics,
  teacherReports,
  teacherMyReports,
  parentReports,
  adminManage,
  adminRoles,
  adminTeachers,
  adminAccountants,
  adminParents,
  adminClasses,
  adminDepartments,
  adminTimetable,
  adminAcademics,
  schoolAffairs,
  schoolLife,
  parentDailyReport,
  adminReports,
  library,
  clinic,
  catalog,
  auditLog,
  schoolSignup,
  schoolProfile,
  platformHome,
  platformSchools,
  platformSignupRequests,
  platformContactMessages,
  cashierCounter,
  feedingToday,
  myAttendance,
  parentFeeding,
  expenses,
  departmentHome,
  departmentStudents,
  departmentStaff,
  departmentClasses,
  departmentAttendance,
  departmentHeads,
}

/// The "My department" pages. Who may open them depends on the signed-in
/// person ([AppUser.canOpen]), not on their role.
const departmentScreens = {
  AppScreen.departmentHome,
  AppScreen.departmentStudents,
  AppScreen.departmentStaff,
  AppScreen.departmentClasses,
  AppScreen.departmentAttendance,
  AppScreen.departmentHeads,
};

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.klass,
    required this.avatar,
    required this.attendance,
    required this.fees,
    required this.outstanding,
    required this.status,
    this.boarder = false,
    this.classId = '',
    this.userId = '',
    this.palmCredentialId = '',
    this.cardNumber = '',
    this.studentNumber = '',
    this.schoolId = '',
    this.schoolName = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.emergencyContactPhone = '',
    this.allergies = '',
    this.medicalNotes = '',
    this.admissionDate = '',
    this.guardianName = '',
    this.guardianPhone = '',
    this.guardianRelationship = '',
  });

  final String id;
  final String name;
  final String klass;
  final String avatar;
  final int attendance;
  final int fees;
  final int outstanding;
  final String status;
  final bool boarder;
  final String classId;
  final String userId;
  final String palmCredentialId;
  final String cardNumber;
  final String studentNumber;
  final String schoolId;
  final String schoolName;

  // The API returns all of these on every /students response but the app
  // never read them past the initial student list — surfaced now so
  // nothing from the record is silently dropped.
  final String dateOfBirth;
  final String gender;
  final String emergencyContactPhone;
  final String allergies;
  final String medicalNotes;
  final String admissionDate;
  final String guardianName;
  final String guardianPhone;
  final String guardianRelationship;
}

/// Total/present/absent/late/excused day counts for a child, used by the
/// parent dashboard's attendance grid and the full attendance screen.
class AttendanceTermSummary {
  const AttendanceTermSummary({
    required this.onTime,
    required this.late,
    required this.absent,
    required this.excused,
    required this.totalDays,
  });

  final int onTime;
  final int late;
  final int absent;
  final int excused;
  final int totalDays;

  /// Total days marked present, whether on time or late.
  int get present => onTime + late;

  double get presentPercent => totalDays == 0 ? 0 : (present / totalDays) * 100;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.text,
    required this.time,
    required this.icon,
    required this.color,
    this.audience = const [],
    this.unread = true,
    this.title = '',
  });

  final String id;
  final String type;
  final String text;

  /// Headline as the website shows it above [text]; empty for alerts that
  /// only have one line.
  final String title;
  final String time;
  final String icon;
  final String color;
  final List<Role> audience;
  bool unread;
}

class AdminStat {
  const AdminStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
  });

  final String label;
  final String value;
  final String icon;
  final String color;
  final String? trend;
}

class Period {
  const Period({
    required this.time,
    required this.end,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.active,
  });

  final String time;
  final String end;
  final String subject;
  final String teacher;
  final String room;
  final bool active;
}

class ChatLine {
  ChatLine({
    required this.from,
    required this.body,
    required this.time,
    required this.role,
    this.id = '',
    this.senderId = '',
    this.edited = false,
    this.system = false,
    this.category = '',
  });

  final String id;
  final String senderId;

  /// Automatic message from the school system (no human sender).
  final bool system;

  /// Machine-readable kind of a system message, e.g. `attendance_late`.
  final String category;
  final String from;
  String body;
  final String time;
  final Role role;
  bool edited;
}

class ChatPreview {
  ChatPreview({
    required this.from,
    required this.role,
    required this.time,
    required this.preview,
    required this.unread,
    required this.avatar,
    this.unreadCount = 0,
    this.id = '',
    String? threadId,
    this.kind = 'message',
    this.toLabel = '',
    this.audience = const [],
    this.sentByRole,
    this.viewerUserId = '',
    List<ChatLine>? lines,
  })  : threadId = threadId ?? id,
        lines = lines ?? [];

  final String id;
  final String threadId;
  final String from;
  final String role;
  String time;
  String preview;
  bool unread;
  final String avatar;
  int unreadCount;
  final String kind;
  final String toLabel;
  final List<Role> audience;
  final Role? sentByRole;
  /// When set, only this signed-in user (or demo `local-{role}`) can see the thread.
  final String viewerUserId;
  final List<ChatLine> lines;

  int get badgeCount => unread ? (unreadCount > 0 ? unreadCount : 1) : 0;
  bool get isAnnouncement => kind == 'announcement';
  bool get isSystem => kind == 'system';

  List<ChatLine> get timeline => lines.isNotEmpty
      ? lines
      : [
          ChatLine(
            from: from,
            body: preview,
            time: time,
            role: sentByRole ?? Role.parent,
          ),
        ];
}

class NavItem {
  const NavItem({
    required this.screen,
    required this.label,
    required this.icon,
  });

  final AppScreen screen;
  final String label;
  final IconData icon;
}

class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.tone,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final ToneRef tone;
  final AppScreen screen;
}

enum ToneRef { honey, sky, emerald, rose, violet }

enum DelegateStatus { pending, authorised, rejected, revoked, used }

class PickupDelegate {
  PickupDelegate({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.klass,
    required this.name,
    required this.relation,
    required this.phone,
    required this.until,
    required this.requestedBy,
    this.status = DelegateStatus.pending,
    this.confirmPayload,
    this.confirmOtc,
    this.pickupDate,
    this.pickupTime,
    this.schoolName = '',
    this.payload,
    this.usedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String klass;
  final String name;
  final String relation;
  final String phone;
  final String until;
  final String requestedBy;
  DelegateStatus status;
  final String? confirmPayload;
  final String? confirmOtc;
  final String? pickupDate;
  final String? pickupTime;
  final String schoolName;
  final String? payload;
  final String? usedAt;
}

class PickupPass {
  PickupPass({
    required this.token,
    required this.studentId,
    required this.studentName,
    required this.klass,
    required this.parentName,
    required this.pickerName,
    required this.pickerRole,
    required this.kind,
    required this.expiresAt,
    this.delegateId,
    this.used = false,
    this.apiPayload,
    this.palmCredentialId,
    this.cardNumber,
    this.otc,
  });

  final String token;
  final String studentId;
  final String studentName;
  final String klass;
  final String parentName;
  final String pickerName;
  final String pickerRole;
  final String kind;
  final DateTime expiresAt;
  final String? delegateId;
  final String? apiPayload;
  final String? palmCredentialId;
  final String? cardNumber;
  final String? otc;
  bool used;

  bool get expired => DateTime.now().isAfter(expiresAt);
  bool get live => !used && !expired;

  String get payload =>
      apiPayload ??
      'e10://pickup?sid=$studentId'
          '&child=${Uri.encodeComponent(studentName)}'
          '&klass=${Uri.encodeComponent(klass)}'
          '&parent=${Uri.encodeComponent(parentName)}'
          '&picker=${Uri.encodeComponent(pickerName)}'
          '&role=${Uri.encodeComponent(pickerRole)}'
          '&kind=$kind'
          '&token=$token'
          '${otc == null || otc!.isEmpty ? '' : '&otc=$otc'}'
          '&exp=${expiresAt.toUtc().toIso8601String()}'
          '${delegateId == null ? '' : '&did=$delegateId'}'
          '${palmCredentialId == null || palmCredentialId!.isEmpty ? '' : '&palm=$palmCredentialId'}'
          '${cardNumber == null || cardNumber!.isEmpty ? '' : '&card=${Uri.encodeComponent(cardNumber!)}'}';
}

class PickupLog {
  const PickupLog({
    required this.id,
    required this.studentName,
    required this.klass,
    required this.pickerName,
    required this.pickerRole,
    required this.kind,
    required this.gate,
    required this.officer,
    required this.time,
    this.schoolName = '',
  });

  final String id;
  final String studentName;
  final String klass;
  final String pickerName;
  final String pickerRole;
  final String kind;
  final String gate;
  final String officer;
  final String time;
  final String schoolName;
}
