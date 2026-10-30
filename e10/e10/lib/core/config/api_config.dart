import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ??
        'https://e10.beesofthive.pro/api';
  }

  static const String loginPath = 'auth/login';
  static const String staffRequestCodePath = 'auth/staff/request-code';
  static const String staffRequestPath = staffRequestCodePath;
  static const String staffVerifyCodePath = 'auth/staff/verify-code';
  static const String staffVerifyPath = staffVerifyCodePath;
  static const String guardianRequestCodePath = 'auth/guardian/request-code';
  static const String guardianRequestPath = guardianRequestCodePath;
  static const String guardianVerifyCodePath = 'auth/guardian/verify-code';
  static const String guardianVerifyPath = guardianVerifyCodePath;
  static const String mePath = 'auth/me';
  static const String logoutPath = 'auth/logout';
  static const String profilePath = 'auth/profile';
  static const String passwordPath = 'auth/password';
  static const String appearancePath = 'auth/appearance';
  static const String passwordForgotPath = 'auth/password/forgot';
  static const String passwordResetPath = 'auth/password/reset';
  static const String guardianEnterSchoolPath = 'auth/guardian/schools';
  static const String guardianExitSchoolPath = 'auth/guardian/schools/exit';

  static const String notificationsPath = 'notifications';
  static const String unreadCountPath = 'notifications/unread-count';
  static String notificationReadPath(String id) => 'notifications/$id/read';
  static const String notificationsReadAllPath = 'notifications/read-all';

  static const String announcementsPath = 'announcements';
  static String announcementPath(String id) => 'announcements/$id';
  static String announcementRepliesPath(String id) => 'announcements/$id/replies';

  static const String messageThreadsPath = 'message-threads';
  static String messageThreadPath(String id) => 'message-threads/$id';
  static String messageThreadMessagesPath(String id) => 'message-threads/$id/messages';

  static const String attendancePath = 'attendance';
  static const String myAttendancePath = 'attendance/me';
  static const String classRegisterPath = 'attendance/class-register';
  static const String manualAttendancePath = 'attendance/manual';

  static const String assignmentsPath = 'assignments';
  static String assignmentPath(String id) => 'assignments/$id';
  static const String assignmentSubmissionsPath = 'assignment-submissions';

  static const String examsPath = 'exams';
  static String examPath(String id) => 'exams/$id';
  static String examPublishPath(String id) => 'exams/$id/publish';
  static const String examResultsPath = 'exam-results';

  static const String reportCardsPath = 'report-cards';
  static String reportCardPath(String id) => 'report-cards/$id';
  static String reportCardSubmitPath(String id) => 'report-cards/$id/submit';
  static String reportCardPublishPath(String id) => 'report-cards/$id/publish';
  static String reportCardEditRequestsPath(String id) => 'report-cards/$id/edit-requests';
  static String editRequestApprovePath(String id) => 'report-card-edit-requests/$id/approve';
  static String editRequestDenyPath(String id) => 'report-card-edit-requests/$id/deny';

  static const String dailyReportsPath = 'daily-reports';
  static String dailyReportPath(String id) => 'daily-reports/$id';
  static String dailyReportPhotoPath(String id) => 'daily-reports/$id/photo';
  static String dailyReportSendPath(String id) => 'daily-reports/$id/send';
  static const String dailyReportsRosterPath = 'daily-reports-roster';

  static const String timetableEntriesPath = 'timetable-entries';

  static const String billsPath = 'bills';
  static String billPath(String id) => 'bills/$id';
  static String billInvoicePath(String id) => 'bills/$id/invoice';
  static const String paymentsPath = 'payments';
  static String paymentReceiptPath(String id) => 'payments/$id/receipt';

  static const String staffPath = 'staff';
  static const String guardiansPath = 'guardians';
  static const String studentsPath = 'students';
  static String studentPath(String id) => 'students/$id';

  static const String leaveRequestsPath = 'leave-requests';
  static String leaveApprovePath(String id) => 'leave-requests/$id/approve';

  static const String schoolPath = 'school';
  static const String schoolProfilePath = 'school/profile';
  static const String schoolLogoPath = 'school/logo';
  static const String subscriptionStatusPath = 'subscription-status';
  static const String schoolUpgradeRequestPath = 'school/upgrade-request';
  static const String academicYearsPath = 'academic-years';
  static const String academicTermsPath = 'academic-terms';
  static const String schoolClassesPath = 'school-classes';
  static const String subjectsPath = 'subjects';
  static const String departmentsPath = 'departments';
  static String departmentHeadsPath(String id) => 'departments/$id/heads';
  static const String dashboardSummaryPath = 'dashboard/summary';
  static const String dashboardMoneyPath = 'dashboard/money';
  static const String housesPath = 'houses';
  static const String rolesPath = 'roles';
  static const String permissionsPath = 'permissions';
  static const String enrollmentsPath = 'enrollments';
  static const String teacherSubjectAssignmentsPath = 'teacher-subject-assignments';

  static const String signupRequestsPath = 'signup-requests';
  static const String contactMessagesPath = 'contact-messages';

  static const String platformOverviewPath = 'platform/overview';
  static const String platformSchoolsPath = 'platform/schools';
  static String platformSchoolPath(String id) => 'platform/schools/$id';
  static String platformSchoolEnterPath(String id) => 'platform/schools/$id/enter';
  static const String platformExitSchoolPath = 'platform/exit-school';
  static String platformSchoolSubscriptionSummaryPath(String id) => 'platform/schools/$id/subscription-summary';
  static const String platformSignupRequestsPath = 'platform/signup-requests';
  static String platformSignupRequestPath(String id) => 'platform/signup-requests/$id';
  static const String platformContactMessagesPath = 'platform/contact-messages';
  static String platformContactMessagePath(String id) => 'platform/contact-messages/$id';
  static const String platformTransactionsPath = 'platform/transactions';
  static const String platformAuditLogsPath = 'platform/audit-logs';

  static String get apiRoot => stripSlash(baseUrl);
  static String get apiBaseUrl => baseUrl;
  static String get teacherBase => apiRoot;

  static String stripSlash(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  static String join(String base, String path) {
    final b = stripSlash(base);
    final p = path.trim().replaceAll(RegExp(r'^/+'), '');
    return '$b/$p';
  }

  static String url(String path) => join(baseUrl, path);

  static Uri endpoint(String path) => Uri.parse(url(path));

  static String? resolved;
  static DateTime? _probedAt;
  static bool _live = false;
  static Future<bool>? _inFlight;

  static Future<bool> probe({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _probedAt != null && now.difference(_probedAt!) < const Duration(seconds: 20)) {
      return _live;
    }
    if (!force && _inFlight != null) return _inFlight!;
    final future = _runProbe();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  static Future<bool> _runProbe() async {
    final base = apiRoot;
    // The profile endpoint is protected, so probing it before sign-in only
    // creates an expected 401 in the browser console.
    markLive(base);
    return true;
  }

  static void markLive(String base) {
    resolved = stripSlash(base);
    _live = true;
    _probedAt = DateTime.now();
  }

  static bool get isLive => _live;
  static String get passwordUpdatePath => passwordPath;
}
