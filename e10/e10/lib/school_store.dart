import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'package:e10/core/config/api_config.dart';
import 'api/api_exception.dart';
import 'api/api_session.dart';
import 'message_read_prefs.dart';
import 'models.dart';
import 'theme.dart';

enum TeacherReportStatus { draft, submitted, reviewed, approved, returned }

enum TeacherReportType { classReport, examReport, subjectRecord }

class Invoice {
  const Invoice({
    required this.id,
    required this.student,
    required this.amount,
    required this.date,
    required this.status,
    required this.description,
    this.studentId = '',
    this.balance = -1,
    this.amountPaid = 0,
    this.invoiceNumber = '',
    this.dueDate = '',
    this.lineItems = const [],
    this.payments = const [],
    this.schoolId = '',
    this.parentId = '',
    this.academicYear = '',
    this.term = '',
  });

  final String id;
  final String student;
  final double amount;
  final String date;
  final String status;
  final String description;
  final String studentId;
  final double balance;
  final double amountPaid;
  final String invoiceNumber;
  final String dueDate;
  final List<BillLine> lineItems;
  final List<BillTxn> payments;
  final String schoolId;
  final String parentId;
  final String academicYear;
  final String term;

  String get statusKey => status.toLowerCase();
  bool get isPaid => statusKey == 'paid';
  bool get isOverdue => statusKey == 'overdue';
  bool get isPartial => statusKey == 'partial' || (statusKey == 'due' && amountPaid > 0.009);
  bool get isCancelled => statusKey == 'cancelled';
  bool get isDraft => statusKey == 'draft';
  double get dueAmount => isPaid || isCancelled ? 0 : (balance >= 0 ? balance : amount);
  /// The invoice number people see; never the bill's database id.
  String get displayNumber => invoiceNumber.trim().isEmpty ? 'Bill' : invoiceNumber;
  String get parentStatus {
    if (isCancelled) return 'Cancelled';
    if (isPaid) return 'Paid';
    if (isOverdue) return 'Overdue';
    if (isDraft) return 'Draft';
    if (amountPaid > 0.009 || statusKey == 'partial') return 'Partially paid';
    return 'Issued';
  }
}

class BillLine {
  const BillLine({required this.label, required this.amount, this.category = ''});

  final String label;
  final double amount;
  final String category;
}

class BillTxn {
  const BillTxn({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    this.reference = '',
    this.receiptNumber = '',
    this.transactionNumber = '',
    this.paidAt = '',
    this.studentName = '',
    this.studentId = '',
    this.previousDebt = '',
    this.remainingDebt = '',
    this.paidBy = '',
    this.billId = '',
    this.billNumber = '',
    this.schoolName = '',
    this.feeLabel = '',
    this.billCategory = '',
    this.academicTerm = '',
  });

  final String id;
  final double amount;
  final String method;
  final String status;
  final String reference;
  final String receiptNumber;
  final String transactionNumber;
  final String paidAt;
  final String studentName;
  final String studentId;
  final String previousDebt;
  final String remainingDebt;
  final String paidBy;
  final String billId;
  final String billNumber;
  final String schoolName;
  final String feeLabel;
  final String billCategory;
  final String academicTerm;
}

class FeePaymentResult {
  const FeePaymentResult({
    this.error = '',
    this.status = '',
    this.receiptNumber = '',
    this.transactionNumber = '',
    this.remaining = '',
    this.previousDebt = '',
    this.reference = '',
    this.parentName = '',
    this.childName = '',
    this.schoolName = '',
    this.method = '',
    this.amount = '',
    this.date = '',
    this.billId = '',
    this.billNumber = '',
    this.feeLabel = '',
    this.paymentId = '',
    this.failureKind = '',
  });

  final String error;
  final String status;
  final String receiptNumber;
  final String transactionNumber;
  final String remaining;
  final String previousDebt;
  final String reference;
  final String parentName;
  final String childName;
  final String schoolName;
  final String method;
  final String amount;
  final String date;
  final String billId;
  final String billNumber;
  final String feeLabel;
  final String paymentId;
  final String failureKind;

  bool get ok => error.isEmpty;
  bool get isPending => status == 'pending' || status == 'processing' || status == 'created';
  bool get isSuccess => status == 'successful' || status == 'paid' || status == 'completed' || status == 'success';
  bool get isFailed => status == 'failed' || status == 'cancelled';
}

class ExamStats {
  const ExamStats({
    required this.wrote,
    required this.passed,
    required this.failed,
    required this.highest,
    required this.lowest,
    required this.average,
  });

  final int wrote;
  final int passed;
  final int failed;
  final int highest;
  final int lowest;
  final double average;

  double get passPercent => wrote == 0 ? 0 : (passed / wrote) * 100;
}

class TeacherReport {
  TeacherReport({
    required this.id,
    required this.teacher,
    required this.subject,
    required this.status,
    this.type = TeacherReportType.classReport,
    this.year = '',
    this.term = '',
    this.klass = '',
    this.section = '',
    this.submittedAt = '',
    this.studentCount = 0,
    this.examName = '',
    this.examDate = '',
    this.performance = '',
    this.progress = '',
    this.participation = '',
    this.attendanceNotes = '',
    this.behaviour = '',
    this.strengths = '',
    this.challenges = '',
    this.topicsDone = '',
    this.topicsPending = '',
    this.recommendations = '',
    this.comments = '',
    this.adminFeedback = '',
  });

  String id;
  TeacherReportType type;
  String year;
  String term;
  String klass;
  String section;
  String teacher;
  String subject;
  TeacherReportStatus status;
  String submittedAt;
  int studentCount;
  String examName;
  String examDate;
  String performance;
  String progress;
  String participation;
  String attendanceNotes;
  String behaviour;
  String strengths;
  String challenges;
  String topicsDone;
  String topicsPending;
  String recommendations;
  String comments;
  String adminFeedback;

  String get typeLabel => switch (type) {
        TeacherReportType.classReport => 'Class Report',
        TeacherReportType.examReport => 'Examination Report',
        TeacherReportType.subjectRecord => 'Subject records',
      };

  String get statusLabel => switch (status) {
        TeacherReportStatus.draft => 'Draft',
        TeacherReportStatus.submitted => type == TeacherReportType.subjectRecord ? 'Sent to class teacher' : 'Submitted',
        TeacherReportStatus.reviewed => 'Reviewed',
        TeacherReportStatus.approved => 'Approved',
        TeacherReportStatus.returned => 'Returned',
      };
}

const gesReportSubjects = [
  'English Lang.',
  'Mathematics',
  'Science',
  'Social Studies',
  'RME',
  'Career Tech',
  'Creative Arts',
  'Computing',
  'Ghanaian Lang.',
];

String gesRemarkFor(int total) {
  if (total >= 80) return 'Excellent';
  if (total >= 70) return 'Very Good';
  if (total >= 60) return 'Good';
  if (total >= 50) return 'Credit';
  if (total >= 40) return 'Pass';
  if (total <= 0) return '';
  return 'Fail';
}

int scoreOutOf50(int value) => value > 50 ? ((value / 2).round()).clamp(0, 50) : value.clamp(0, 50);

class ReportSubjectMark {
  ReportSubjectMark({
    required this.subject,
    this.subjectId = '',
    this.classScore = 0,
    this.examScore = 0,
    this.position = '',
    this.grade = '—',
    this.remark = '',
  });

  String subject;
  String subjectId;
  int classScore;
  int examScore;
  String position;
  String grade;
  String remark;

  int get total => (classScore + examScore).clamp(0, 100);

  void syncRemark() {
    grade = gesRemarkFor(total).isEmpty ? '—' : (total >= 80 ? 'A' : total >= 70 ? 'B' : total >= 60 ? 'C' : total >= 50 ? 'D' : 'F');
    if (remark.isEmpty || {'Excellent', 'Very Good', 'Good', 'Credit', 'Pass', 'Fail'}.contains(remark)) {
      remark = gesRemarkFor(total);
    }
  }
}

class ReportLine {
  ReportLine({
    required this.studentId,
    required this.student,
    this.cardId = '',
    this.published = false,
    this.classScore = 0,
    this.examScore = 0,
    this.grade = '—',
    this.remark = '',
    this.headteacherRemark = '',
    this.bill = '—',
    this.promote,
    this.promotedTo = '',
    this.position = '',
    this.attendanceMade = '',
    this.attendanceOutOf = '',
    this.conduct = '',
    this.interest = '',
    this.attitude = '',
    List<ReportSubjectMark>? subjects,
  }) : subjects = subjects ?? [];

  String studentId;
  String student;
  String cardId;
  bool published;
  int classScore;
  int examScore;
  String grade;
  String remark;
  String headteacherRemark;
  String bill;
  bool? promote;
  String promotedTo;
  String position;
  String attendanceMade;
  String attendanceOutOf;
  String conduct;
  String interest;
  String attitude;
  List<ReportSubjectMark> subjects;

  String get promoteLabel => promote == true ? 'Promote' : '—';
  int get overall {
    if (subjects.isEmpty) return (scoreOutOf50(classScore) + scoreOutOf50(examScore)).clamp(0, 100);
    return (subjects.fold<int>(0, (sum, m) => sum + m.total) / subjects.length).round();
  }

  List<ReportSubjectMark> get subjectRows {
    return subjects;
  }

  void ensureReportSubjects(List<ReportSubjectMark> templates) {
    if (subjects.isNotEmpty || templates.isEmpty) return;
    subjects = [
      for (final item in templates)
        ReportSubjectMark(subject: item.subject, subjectId: item.subjectId),
    ];
  }

  void retakeGrade() {
    if (classScore == 0 && examScore == 0) {
      grade = '—';
      return;
    }
    final avg = (classScore + examScore) / 2;
    grade = avg >= 80
        ? 'A'
        : avg >= 70
            ? 'B'
            : avg >= 60
                ? 'C'
                : avg >= 50
                    ? 'D'
                    : 'F';
  }
}

class AcademicReport {
  AcademicReport({
    required this.id,
    required this.klass,
    required this.term,
    required this.year,
    required this.teacher,
    required this.lines,
    this.status = 'submitted',
    this.submittedAt = '',
    this.vacationDate = '',
    this.nextTermBegins = '',
    this.classId = '',
    this.termId = '',
    this.yearId = '',
  });

  String id;
  String klass;
  String term;
  String year;
  String teacher;
  String status;
  String submittedAt;
  String vacationDate;
  String nextTermBegins;
  String classId;
  String termId;
  String yearId;
  List<ReportLine> lines;

  bool get sentToParent => status == 'sent_to_parent' || status == 'published';
  bool get sentToAdmin => status == 'sent_to_admin' || status == 'submitted' || sentToParent;
  bool get isDraft => status == 'draft';
  String get statusLabel => sentToParent
      ? 'Sent to parents'
      : sentToAdmin
          ? 'With admin'
          : 'Draft';
}

class AcademicMark {
  AcademicMark({
    required this.id,
    required this.student,
    required this.klass,
    required this.subject,
    required this.term,
    required this.score,
    required this.grade,
    this.remark = '',
  });

  String id;
  String student;
  String klass;
  String subject;
  String term;
  int score;
  String grade;
  String remark;
}

class TimeSlot {
  TimeSlot({
    required this.id,
    this.classId = '',
    required this.className,
    required this.day,
    required this.start,
    required this.end,
    required this.subject,
    required this.teacher,
    required this.room,
    this.teacherId = '',
    this.kind = 'lesson',
  });

  String id;
  String teacherId;

  /// lesson | break | lunch (the website shows Break / Lunch by name).
  String kind;
  String classId;
  String className;
  String day;
  String start;
  String end;
  String subject;
  String teacher;
  String room;
}

class SchoolReport {
  SchoolReport({
    required this.id,
    required this.title,
    required this.from,
    required this.body,
    required this.time,
    required this.kind,
    this.received = false,
  });

  String id;
  String title;
  String from;
  String body;
  String time;
  String kind;
  bool received;
}

class AccountRecord {
  const AccountRecord({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
  });

  final String id;
  final String name;
  final String role;
  final String email;
}

/// `GET /dashboard/summary`: the admin dashboard's figures, worked out by the
/// server in one small request.
class DashboardSummary {
  const DashboardSummary({
    required this.students,
    required this.classes,
    required this.clockingStaff,
    required this.studentsIn,
    required this.studentsAway,
    required this.staffIn,
  });

  final int? students;
  final int? classes;
  final int? clockingStaff;
  final int? studentsIn;
  final int? studentsAway;
  final int? staffIn;

  static int? _total(dynamic list) {
    if (list is! Map) return null;
    final meta = list['meta'];
    final total = meta is Map ? meta['total'] : null;
    if (total is num) return total.toInt();
    final data = list['data'];
    return data is List ? data.length : null;
  }

  static int _count(Map summary, String key) => summary[key] is num ? (summary[key] as num).toInt() : 0;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final students = json['student_attendance'] is Map ? (json['student_attendance'] as Map)['summary'] : null;
    final staff = json['staff_attendance'] is Map ? (json['staff_attendance'] as Map)['summary'] : null;
    return DashboardSummary(
      students: _total(json['students']),
      classes: _total(json['classes']),
      clockingStaff: _total(json['clocking_staff']),
      studentsIn: students is Map ? _count(students, 'present') + _count(students, 'late') : null,
      studentsAway: students is Map ? _count(students, 'absent') + _count(students, 'excused') : null,
      staffIn: staff is Map ? _count(staff, 'present') + _count(staff, 'late') + _count(staff, 'early_departure') : null,
    );
  }
}

class NamedRecord {
  NamedRecord({
    required this.id,
    required this.name,
    this.detail = '',
    this.extra = '',
    this.phone = '',
    this.email = '',
    this.link = '',
    this.userId = '',
  });

  String id;
  String name;
  String detail;
  String extra;
  String phone;
  String email;
  String link;
  String userId;
}

class RoleAccount {
  RoleAccount({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    this.phone = '',
    this.title = '',
  });

  String id;
  String name;
  Role role;
  String email;
  String phone;
  String title;
}

/// School data store - holds all school-related data
class SchoolStore extends ChangeNotifier {
  bool loading = false;
  bool reportCardsLoading = false;
  String? syncError;
  String? reportCardsError;
  String? schoolId;
  String? schoolName;
  String? schoolMotto;
  String? schoolLogoUrl;
  String? schoolCode;
  String? schoolPrimaryColor;
  // The API returns all of these on GET /school (confirmed live) but only
  // name/motto/code/logo/colour were ever read into the store — the rest
  // just got fetched and discarded on every sync.
  String? schoolAddress;
  String? schoolPhone;
  String? schoolPhoneSecondary;
  String? schoolEmail;
  String? schoolAccentColor;
  String? schoolCurrencyCode;
  String? schoolTimezone;

  /// Report split set by the admin: class work is out of this, the exam out
  /// of the rest of 100. 30 until the school server provides it.
  int classScoreWeight = 30;
  String? schoolType;
  String? schoolStatus;
  String? academicYearId;
  String? academicTermId;
  String? _activeEmail;
  Role? _activeRole;
  bool _activeDailyReportsEligible = false;

  /// Pause / coalesce notifications so overlays can finish disposing before
  /// [SchoolScope] rebuilds dependents (avoids InheritedElement `_dependents.isEmpty`).
  int _notifyPauseDepth = 0;
  bool _notifyDirty = false;
  bool _notifyScheduled = false;

  @override
  void notifyListeners() {
    _notifyDirty = true;
    if (_notifyPauseDepth > 0) return;
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_notifyPauseDepth > 0) return;
      if (!_notifyDirty) return;
      _notifyDirty = false;
      if (hasListeners) super.notifyListeners();
    });
    // A post-frame callback doesn't ask for a frame: on an idle screen, fresh
    // data would stay hidden until the next touch or animation.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void beginNotifyBatch() => _notifyPauseDepth++;

  void endNotifyBatch() {
    if (_notifyPauseDepth > 0) _notifyPauseDepth--;
    if (_notifyPauseDepth == 0 && _notifyDirty) _scheduleNotify();
  }

  Future<T> runNotifyBatch<T>(Future<T> Function() action) async {
    beginNotifyBatch();
    try {
      return await action();
    } finally {
      endNotifyBatch();
    }
  }

  String get brandedSchoolName {
    final name = schoolName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'School';
  }

  Color? get themeSeed => _parseHexColor(schoolPrimaryColor);

  Color? get accentSeed => _parseHexColor(schoolAccentColor);

  Color? _parseHexColor(String? value) {
    final raw = value?.trim().replaceFirst('#', '');
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.length == 6 ? 'FF$raw' : raw;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  /// Every header/primary-button surface in the app used a hardcoded blue
  /// gradient (`AppGradients.header`) regardless of which school's data was
  /// loaded, even though the API sends a per-school `primary_color` on
  /// every GET /school. This turns that colour into the same dark-to-light
  /// diagonal look the hardcoded gradient already had, so each school is
  /// actually branded with its own colour instead of every school looking
  /// identical. Falls back to the original gradient when no colour is set
  /// yet (e.g. before the first sync completes).
  LinearGradient get brandGradient {
    final seed = themeSeed;
    if (seed == null) return AppGradients.header;
    final hsl = HSLColor.fromColor(seed);
    Color shift(double lightnessDelta) {
      final l = (hsl.lightness + lightnessDelta).clamp(0.0, 1.0);
      return hsl.withLightness(l).toColor();
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [shift(-0.14), seed, shift(0.20)],
    );
  }

  /// Same idea as [brandGradient] but for the accent colour — a lighter
  /// diagonal wash used where a single flat accent (not a header gradient)
  /// reads better, e.g. a highlight badge or a secondary CTA.
  Color get brandAccent => accentSeed ?? themeSeed ?? AppColors.honey;

  /// Four tile colours for the "Jump in" quick actions on every dashboard.
  /// Those were hardcoded to `AppColors.jumpA..D` (four fixed blue shades)
  /// regardless of school, so this school's actual data (its palm-device
  /// icon colour choices) never reached the one part of the dashboard every
  /// role sees first. Blends between the school's primary and accent colour
  /// instead, falling back to the original four shades when neither is set.
  ///
  /// A school's `accent_color` is often a near-white neutral (e.g. a pale
  /// UI-chrome grey picked for the website, not an icon colour), so this
  /// clamps lightness/saturation on every derived shade — otherwise the
  /// icon on its white tile background reads as invisible.
  List<Color> get brandTiles {
    final primary = themeSeed;
    final accent = accentSeed ?? primary;
    if (primary == null && accent == null) {
      return const [AppColors.jumpA, AppColors.jumpB, AppColors.jumpC, AppColors.jumpD];
    }
    final p = primary ?? accent!;
    final a = accent ?? primary!;
    HSLColor legible(Color c) {
      final hsl = HSLColor.fromColor(c);
      return hsl.withLightness(hsl.lightness.clamp(0.28, 0.6)).withSaturation(hsl.saturation.clamp(0.35, 1.0));
    }

    final hslP = legible(p);
    final hslA = legible(a);
    Color tint(HSLColor c, double delta) => c.withLightness((c.lightness + delta).clamp(0.28, 0.62)).toColor();
    return [hslP.toColor(), tint(hslA, -0.08), tint(hslP, 0.14), tint(hslA, 0.1)];
  }

  String headerSchoolName(Role role) {
    if (role == Role.parent) {
      final child = focusedChild(Role.parent);
      final fromChild = child?.schoolName.trim() ?? '';
      if (fromChild.isNotEmpty) return fromChild;
    }
    return brandedSchoolName;
  }

  NamedRecord? staffRecordFor(AppUser user) {
    final uid = (sessionUserId ?? '').trim();
    final staffId = (sessionStaffId ?? '').trim();
    final email = user.email.trim().toLowerCase();
    final name = user.displayName.trim().toLowerCase();
    bool matches(NamedRecord t) {
      if (uid.isNotEmpty && (t.userId == uid || t.id == uid)) return true;
      if (staffId.isNotEmpty && t.id == staffId) return true;
      if (email.isNotEmpty && t.email.trim().toLowerCase() == email) return true;
      if (name.isNotEmpty && t.name.trim().toLowerCase() == name) return true;
      return false;
    }

    for (final t in teachers) {
      if (matches(t)) return t;
    }
    for (final row in tableRows('staff')) {
      final t = NamedRecord(
        id: '${row['id'] ?? ''}',
        name: '${row['full_name'] ?? ''}',
        detail: '${row['position'] ?? ''}',
        email: '${row['email'] ?? ''}',
        userId: '${row['user_id'] ?? ''}',
      );
      if (matches(t)) return t;
    }
    return null;
  }

  bool isHomeroomClass(NamedRecord klass, AppUser user) {
    final me = staffRecordFor(user);
    final uid = (sessionUserId ?? '').trim();
    final staffId = (sessionStaffId ?? '').trim();
    if (klass.userId.isNotEmpty) {
      if (uid.isNotEmpty && klass.userId == uid) return true;
      if (me != null && (klass.userId == me.userId || klass.userId == me.id)) return true;
    }
    if (klass.link.isNotEmpty) {
      final link = klass.link.trim().toLowerCase();
      if (link == user.displayName.trim().toLowerCase()) return true;
      if (me != null && link == me.name.trim().toLowerCase()) return true;
    }
    for (final row in tableRows('school_classes')) {
      if ('${row['id']}' != klass.id) continue;
      // The live API puts a class's homeroom teacher(s) in `teacher_ids`
      // (array of staff ids) plus a matching `teachers` array of full staff
      // objects — there is no singular `class_teacher_id`/`class_teacher`
      // field (confirmed against the real API: sending `class_teacher_id`
      // is silently ignored).
      // Newer API versions send one `class_teacher_id` instead.
      final single = '${row['class_teacher_id'] ?? ''}';
      if (single.isNotEmpty && single != 'null' && (single == staffId || (me != null && single == me.id))) return true;
      final ids = row['teacher_ids'];
      if (ids is List) {
        for (final id in ids) {
          final ctid = '$id';
          if (staffId.isNotEmpty && ctid == staffId) return true;
          if (me != null && ctid == me.id) return true;
        }
      }
      final teachers = row['teachers'];
      if (teachers is List) {
        for (final item in teachers) {
          if (item is! Map) continue;
          final ct = Map<String, dynamic>.from(item);
          if (uid.isNotEmpty && '${ct['user_id']}' == uid) return true;
          if (staffId.isNotEmpty && '${ct['id']}' == staffId) return true;
          final ctName = '${ct['full_name'] ?? ''}'.trim().toLowerCase();
          if (ctName.isNotEmpty && ctName == user.displayName.trim().toLowerCase()) return true;
          final ctEmail = '${ct['email'] ?? ''}'.trim().toLowerCase();
          if (ctEmail.isNotEmpty && ctEmail == user.email.trim().toLowerCase()) return true;
        }
      }
    }
    return false;
  }

  List<NamedRecord> homeroomClassesFor(AppUser user) {
    return [for (final klass in classes) if (isHomeroomClass(klass, user)) klass];
  }

  bool isClassTeacher(AppUser user) => user.role == Role.teacher && homeroomClassesFor(user).isNotEmpty;

  bool get sessionIsClassTeacher {
    if (_activeRole != null && _activeRole != Role.teacher) return false;
    return isClassTeacher(
      AppUser(
        email: _activeEmail ?? '',
        displayName: '',
        role: Role.teacher,
        subtitle: '',
      ),
    );
  }

  /// A teacher is "KG" when `daily_reports_eligible` came back true at login
  /// — the API computes that server-side from the teacher's department
  /// (`is_early_years: true`), so this is decided entirely by how the admin
  /// set the teacher up, not by anything picked at login.
  ///
  /// Uses the live flag for the signed-in teacher (refreshed from
  /// `/auth/me`, see [refreshSessionProfile]), and also treats the class
  /// teacher of an early-years class as KG, so moving a teacher to/from a KG
  /// class or department switches their dashboard without a new login.
  bool isKgTeacher(AppUser user) {
    if (user.role != Role.teacher) return false;
    final isSession = _activeEmail != null && _activeEmail!.toLowerCase() == user.email.toLowerCase();
    if (isSession ? _activeDailyReportsEligible : user.isKgDepartment) return true;
    return homeroomClassesFor(user).any((k) => isEarlyYearsClass(id: k.id, name: k.name));
  }

  bool get sessionIsKgTeacher {
    if (_activeRole != null && _activeRole != Role.teacher) return false;
    if (_activeDailyReportsEligible) return true;
    return isKgTeacher(AppUser(email: _activeEmail ?? '', displayName: '', role: Role.teacher, subtitle: ''));
  }

  /// The three teacher dashboard shapes: KG (department-based) takes
  /// priority, then homeroom class teacher, then plain subject teacher.
  TeacherKind teacherKind(AppUser user) {
    if (isKgTeacher(user)) return TeacherKind.kg;
    if (isClassTeacher(user)) return TeacherKind.classTeacher;
    return TeacherKind.subject;
  }

  TeacherKind get sessionTeacherKind {
    if (sessionIsKgTeacher) return TeacherKind.kg;
    if (sessionIsClassTeacher) return TeacherKind.classTeacher;
    return TeacherKind.subject;
  }

  // ---------------------------------------------------------------
  // KG daily reports (GET /daily-reports-roster, POST/PUT /daily-reports,
  // POST /daily-reports/{id}/send).
  // ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchDailyReportsRoster({
    required String classId,
    required String date,
  }) async {
    if (classId.isEmpty || !ApiSession.instance.isSignedIn) return const [];
    try {
      final response = await ApiClient.instance.get(
        ApiConfig.dailyReportsRosterPath,
        query: {'class_id': classId, 'date': date},
      );
      final data = _unwrap(response);
      if (data is List) {
        return [for (final item in data) if (item is Map) Map<String, dynamic>.from(item)];
      }
      if (data is Map) {
        final rows = data['roster'] ?? data['students'] ?? data['data'];
        if (rows is List) {
          return [for (final item in rows) if (item is Map) Map<String, dynamic>.from(item)];
        }
      }
    } catch (_) {}
    return const [];
  }

  /// The class id the API knows for [child] — asked from `/auth/me` when the
  /// app has none, so a parent's Daily report works even against a server
  /// that can't look a child up by student id.
  Future<String> _resolveChildClassId(Student child) async {
    if (child.classId.isNotEmpty) return child.classId;
    try {
      final me = _unwrap(await ApiClient.instance.get('auth/me'));
      final guardian = me is Map ? me['guardian'] : null;
      final kids = guardian is Map ? guardian['students'] : null;
      if (kids is List) {
        for (final kid in kids) {
          if (kid is! Map || '${kid['id']}' != child.id) continue;
          final direct = _asString(kid['class_id']);
          if (direct.isNotEmpty) return direct;
          for (final enrollment in _listOf(kid['enrollments'])) {
            final id = enrollment['class_id'] ?? (enrollment['class'] is Map ? (enrollment['class'] as Map)['id'] : null);
            if (id != null && '$id'.isNotEmpty) return '$id';
          }
        }
      }
    } catch (_) {}
    // Still unknown (the API's profile didn't carry it): the child's timetable
    // is looked up per student and every lesson names its class.
    for (final slot in timetable) {
      if (slot.classId.isNotEmpty && slotMatchesChild(slot, child)) return slot.classId;
    }
    try {
      final rows = _listOf(_unwrap(await ApiClient.instance.get('timetable-entries', query: {'student_id': child.id, 'per_page': '5'})));
      for (final row in rows) {
        final id = _asString(row['class_id']).isNotEmpty
            ? _asString(row['class_id'])
            : (row['class'] is Map ? _asString((row['class'] as Map)['id']) : (row['school_class'] is Map ? _asString((row['school_class'] as Map)['id']) : ''));
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    return '';
  }

  /// The report the teacher has *sent* to this child's family for [date]
  /// (`YYYY-MM-DD`). `error` is empty on success; a null report with no error
  /// means nothing has been sent yet. On failure it carries the server's
  /// reason so the screen can show what actually went wrong.
  Future<({Map<String, dynamic>? report, String error})> fetchSentDailyReport(Student child, String date) async {
    final first = await _fetchSentDailyReportOn(child, date);
    if (first.report != null || first.error.isNotEmpty) return first;
    // The website stamps a report with the UTC date, the app with the phone's
    // local date; around midnight those differ, so also look at the UTC day.
    final utc = DateTime.now().toUtc();
    final utcKey = '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final localKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (date == localKey && utcKey != localKey) return _fetchSentDailyReportOn(child, utcKey);
    return first;
  }

  /// A child's sent daily reports for each of [days] (yyyy-mm-dd), keyed by
  /// day — the live website's Trends tab uses `?from=&to=`; servers without
  /// the range filter are asked one day at a time.
  Future<({Map<String, Map<String, dynamic>> byDay, String error})> fetchDailyReportWeek(Student child, List<String> days) async {
    if (days.isEmpty) return (byDay: <String, Map<String, dynamic>>{}, error: '');
    if (!ApiSession.instance.isSignedIn) return (byDay: <String, Map<String, dynamic>>{}, error: 'You are signed out. Sign in again.');
    final want = child.id.trim().toLowerCase();
    final byDay = <String, Map<String, dynamic>>{};
    try {
      final rows = _listOf(_unwrap(await ApiClient.instance.get(
        ApiConfig.dailyReportsPath,
        query: {'student_id': child.id, 'from': days.first, 'to': days.last, 'per_page': '31'},
      )));
      for (final row in rows) {
        final sid = '${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}'.trim().toLowerCase();
        if (sid.isNotEmpty && sid != want) continue;
        final sent = row['is_sent'];
        if (!(sent == null || sent == true || sent == 1 || '$sent' == '1' || '$sent'.toLowerCase() == 'true')) continue;
        final day = '${row['date'] ?? ''}';
        final key = day.length >= 10 ? day.substring(0, 10) : day;
        if (days.contains(key)) byDay[key] = row;
      }
      // A server that ignores from/to returns only one day; top up per day.
      if (byDay.length > 1 || rows.length > 1) return (byDay: byDay, error: '');
    } on ApiException catch (e) {
      if (e.status != 404 && e.status != 405 && e.status != 422) {
        return (byDay: byDay, error: e.status == null ? e.message : '${e.message} (${e.status})');
      }
    } catch (_) {}
    final results = await Future.wait([for (final d in days) _fetchSentDailyReportOn(child, d)]);
    for (var i = 0; i < days.length; i++) {
      final report = results[i].report;
      if (report != null) byDay[days[i]] = report;
    }
    return (byDay: byDay, error: '');
  }

  /// Same call the live website's parent dashboard makes:
  /// `GET /daily-reports?student_id=&date=`. The server only lists a parent
  /// their own children's sent reports. Falls back to the class roster only
  /// on a server that doesn't have this route.
  Future<({Map<String, dynamic>? report, String error})> _fetchSentDailyReportOn(Student child, String date) async {
    if (!ApiSession.instance.isSignedIn) return (report: null, error: 'You are signed out. Sign in again.');
    try {
      final rows = _listOf(_unwrap(await ApiClient.instance.get(
        ApiConfig.dailyReportsPath,
        query: {'student_id': child.id, 'date': date, 'per_page': '20'},
      )));
      final want = child.id.trim().toLowerCase();
      for (final row in rows) {
        final sid = '${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}'.trim().toLowerCase();
        if (sid.isNotEmpty && sid != want) continue;
        final day = '${row['date'] ?? ''}';
        if (day.isNotEmpty && !day.startsWith(date)) continue;
        final sent = row['is_sent'];
        final isSent = sent == null || sent == true || sent == 1 || '$sent' == '1' || '$sent'.toLowerCase() == 'true';
        if (isSent) return (report: row, error: '');
      }
      return (report: null, error: '');
    } on ApiException catch (e) {
      if (e.status != 404 && e.status != 405) {
        return (report: null, error: e.status == null ? e.message : '${e.message} (${e.status})');
      }
    } catch (_) {}
    return _rosterSentDailyReport(child, date);
  }

  Future<({Map<String, dynamic>? report, String error})> _rosterSentDailyReport(Student child, String date) async {
    if (!ApiSession.instance.isSignedIn) return (report: null, error: 'You are signed out. Sign in again.');
    final classId = await _resolveChildClassId(child);
    try {
      final response = await ApiClient.instance.get(
        ApiConfig.dailyReportsRosterPath,
        query: {
          if (classId.isNotEmpty) 'class_id': classId,
          'student_id': child.id,
          'date': date,
        },
      );
      final data = _unwrap(response);
      final rows = data is List ? data : (data is Map ? (data['roster'] ?? data['students'] ?? data['data']) : null);
      if (rows is List) {
        bool isSent(Map report) {
          final v = report['is_sent'];
          return v == true || v == 1 || '$v' == '1' || '$v'.toLowerCase() == 'true';
        }

        String rowStudentId(Map item) {
          final studentJson = item['student'];
          final fromStudent = studentJson is Map ? '${studentJson['id'] ?? ''}' : '';
          return (fromStudent.isNotEmpty ? fromStudent : '${item['student_id'] ?? ''}').trim().toLowerCase();
        }

        final maps = [for (final item in rows) if (item is Map) item];
        final want = child.id.trim().toLowerCase();
        Map? pick;
        for (final item in maps) {
          if (rowStudentId(item) == want) {
            pick = item;
            break;
          }
        }
        // The API only returns a parent their own children's rows, so when
        // there is a single row it is theirs even if the ids didn't line up.
        if (pick == null && maps.length == 1) pick = maps.first;
        final json = pick == null ? null : (pick['daily_report'] ?? pick['report']);
        if (json is Map && isSent(json)) return (report: Map<String, dynamic>.from(json), error: '');
      }
      return (report: null, error: '');
    } on ApiException catch (e) {
      if (e.status == 403 && classId.isEmpty) {
        // No class known for this child and the server refused: they have no
        // class assigned, or the school server can't look them up yet.
        return (report: null, error: 'No class is linked to ${child.name} yet, so there is no daily report to show. Try another child, or ask the school office to check ${child.name}\'s class.');
      }
      return (report: null, error: e.status == null ? e.message : '${e.message} (${e.status})');
    } catch (_) {
      return (report: null, error: 'Something went wrong reading the response.');
    }
  }

  /// Exams and report cards straight from the school API — the same
  /// `GET /exams` and `GET /report-cards` calls the website makes (with the
  /// child's `student_id` for a parent). A list the user may not read comes
  /// back empty rather than failing the other.
  Future<({List<Map<String, dynamic>> exams, List<Map<String, dynamic>> reports, String error})> fetchExamsAndReports({String studentId = ''}) async {
    if (!ApiSession.instance.isSignedIn) return (exams: const <Map<String, dynamic>>[], reports: const <Map<String, dynamic>>[], error: 'Signed out.');
    final query = {'per_page': '50', if (studentId.isNotEmpty) 'student_id': studentId};
    var error = '';
    Future<List<Map<String, dynamic>>?> read(String path) async {
      try {
        return _listOf(_unwrap(await ApiClient.instance.get(path, query: query, timeout: const Duration(seconds: 12))));
      } on ApiException catch (e) {
        if (e.status != 403) error = e.message;
      } catch (_) {
        error = 'Could not reach the school server.';
      }
      return null;
    }

    final results = await Future.wait([read('exams'), read('report-cards')]);
    // Keep School life's Exams / Reports tabs in step with the dashboard.
    if (results[0] != null) tables['exams'] = results[0]!;
    if (results[1] != null) tables['report_cards'] = results[1]!;
    return (exams: results[0] ?? const <Map<String, dynamic>>[], reports: results[1] ?? const <Map<String, dynamic>>[], error: error);
  }

  Future<Map<String, dynamic>?> fetchDailyReport(String id) async {
    if (id.isEmpty || !ApiSession.instance.isSignedIn) return null;
    try {
      final data = _unwrap(await ApiClient.instance.get(ApiConfig.dailyReportPath(id)));
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  Future<({String error, String id})> saveDailyReport({
    String? reportId,
    required String studentId,
    required String classId,
    required String date,
    required Map<String, dynamic> fields,
  }) async {
    final body = <String, dynamic>{
      'student_id': studentId,
      if (classId.trim().isNotEmpty) 'class_id': classId,
      'date': date,
      ...fields,
    };
    try {
      final response = (reportId == null || reportId.isEmpty)
          ? await ApiClient.instance.post(ApiConfig.dailyReportsPath, body)
          : await ApiClient.instance.put(ApiConfig.dailyReportPath(reportId), body);
      final saved = _unwrap(response);
      final id = saved is Map ? '${saved['id'] ?? reportId ?? ''}' : (reportId ?? '');
      return (error: '', id: id);
    } on ApiException catch (e) {
      return (error: e.message, id: reportId ?? '');
    } catch (_) {
      return (error: 'Could not save this report to the school API.', id: reportId ?? '');
    }
  }

  Future<String> sendDailyReport(String reportId) async {
    if (reportId.isEmpty) return 'Save the report before sending it.';
    try {
      await ApiClient.instance.post(ApiConfig.dailyReportSendPath(reportId), {});
      return '';
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not send this report to parents.';
    }
  }

  /// Attaches a photo to a daily report via POST /daily-reports/{id}/photo —
  /// this endpoint has existed in the API config since before this method
  /// was added but was never actually called from anywhere in the app.
  /// Unverified against the live API: the multipart field name is a best
  /// guess ('photo', matching the endpoint's own name) since there's no
  /// prior confirmed-live usage to copy. A wrong field name surfaces as a
  /// normal server-rejection error here rather than crashing.
  Future<String> uploadDailyReportPhoto({
    required String reportId,
    required List<int> bytes,
    required String filename,
  }) async {
    if (reportId.isEmpty) return 'Save the report before attaching a photo.';
    if (!ApiSession.instance.isSignedIn) return 'Sign in again to attach a photo.';
    try {
      // Same call the live website makes: POST /daily-reports/{id}/media
      // with `photos[]`.
      await ApiClient.instance.postMultipart(
        'daily-reports/$reportId/media',
        fileField: 'photos[]',
        bytes: bytes,
        filename: filename,
      );
      return '';
    } on ApiException catch (e) {
      if (e.status != 404 && e.status != 405) return e.message;
    } catch (_) {
      return 'Could not attach this photo. Check the connection and try again.';
    }
    try {
      await ApiClient.instance.postMultipart(
        ApiConfig.dailyReportPhotoPath(reportId),
        fileField: 'photo',
        bytes: bytes,
        filename: filename,
      );
      return '';
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not attach this photo. Check the connection and try again.';
    }
  }

  /// Every photo on a daily report: the live API returns
  /// `media: [{id, url}]`, older builds a single `photo_url`.
  List<({String id, String url})> dailyReportPhotos(Map<String, dynamic> report) {
    final out = <({String id, String url})>[];
    final media = report['media'];
    if (media is List) {
      for (final item in media) {
        if (item is! Map) continue;
        final url = '${item['url'] ?? item['path'] ?? ''}'.trim();
        if (url.isNotEmpty && url != 'null') out.add((id: '${item['id'] ?? ''}', url: url));
      }
    }
    if (out.isEmpty) {
      final single = dailyReportPhotoUrl(report);
      if (single != null) out.add((id: '', url: single));
    }
    return out;
  }

  /// Adds photos to a saved report — the same `POST /daily-reports/{id}/media`
  /// (`photos[]`) call the website makes. A server without that route only
  /// takes one photo via the older `/photo` endpoint.
  Future<String> uploadDailyReportPhotos({
    required String reportId,
    required List<({List<int> bytes, String filename})> files,
  }) async {
    if (files.isEmpty) return '';
    if (reportId.isEmpty) return 'Save the report before attaching photos.';
    if (!ApiSession.instance.isSignedIn) return 'Sign in again to attach photos.';
    try {
      await ApiClient.instance.postMultipartFiles('daily-reports/$reportId/media', fileField: 'photos[]', files: files);
      return '';
    } on ApiException catch (e) {
      if (e.status != 404 && e.status != 405) return e.message;
    } catch (_) {
      return 'Could not attach the photos. Check the connection and try again.';
    }
    return uploadDailyReportPhoto(reportId: reportId, bytes: files.first.bytes, filename: files.first.filename);
  }

  Future<String> deleteDailyReportPhoto({required String reportId, required String mediaId}) async {
    if (reportId.isEmpty || mediaId.isEmpty) return 'This photo can only be replaced, not removed.';
    try {
      await ApiClient.instance.delete('daily-reports/$reportId/media/$mediaId');
      return '';
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not remove the photo.';
    }
  }

  /// First photo on a daily report: the live API returns `media: [{id, url}]`,
  /// older builds a single `photo_url`.
  String? dailyReportPhotoUrl(Map<String, dynamic> report) {
    final media = report['media'];
    if (media is List) {
      for (final item in media) {
        if (item is Map && '${item['url'] ?? ''}'.trim().isNotEmpty) return '${item['url']}'.trim();
      }
    }
    for (final key in const ['photo_url', 'photo', 'image_url']) {
      final value = '${report[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  /// The teacher's own early-years roster for [date], exactly as the live
  /// website asks for it (`GET /daily-reports-roster?date=`): rows of
  /// `{student, report}`. Null when the server wants a class id instead.
  Future<List<Map<String, dynamic>>?> fetchTeacherDailyRoster(String date) async {
    if (!ApiSession.instance.isSignedIn) return null;
    try {
      final data = _unwrap(await ApiClient.instance.get(ApiConfig.dailyReportsRosterPath, query: {'date': date}));
      final rows = data is List ? data : (data is Map ? (data['roster'] ?? data['students'] ?? data['data']) : null);
      if (rows is List) return [for (final item in rows) if (item is Map) Map<String, dynamic>.from(item)];
    } catch (_) {}
    return null;
  }

  /// A Student for a roster row the store doesn't already know.
  Student studentFromRosterRow(Map<String, dynamic> row) {
    final json = row['student'] is Map ? Map<String, dynamic>.from(row['student'] as Map) : <String, dynamic>{};
    final id = '${json['id'] ?? row['student_id'] ?? ''}';
    final known = students.where((s) => s.id == id).firstOrNull;
    if (known != null) return known;
    final name = _asString(json['full_name']).isEmpty ? 'Student' : _asString(json['full_name']);
    return Student(
      id: id,
      name: name,
      klass: _studentClassName(json),
      classId: _studentClassId(json),
      avatar: name,
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
      studentNumber: _studentNumber(json),
    );
  }

  // ---------------------------------------------------------------
  // Platform admin (BeeSoft Hive super admin) — GET/PATCH /platform/*.
  // Every /platform/* call 403s with "Only platform super admins can
  // perform this action." for anyone else — confirmed live.
  // ---------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchPlatformOverview() async {
    try {
      final data = _unwrap(await ApiClient.instance.get(ApiConfig.platformOverviewPath));
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchPlatformSchools() async {
    try {
      return await _allPages(ApiConfig.platformSchoolsPath, const {});
    } catch (_) {}
    return const [];
  }

  Future<Map<String, dynamic>?> fetchPlatformSchoolSubscriptionSummary(String schoolId) async {
    if (schoolId.isEmpty) return null;
    try {
      final data = _unwrap(await ApiClient.instance.get(ApiConfig.platformSchoolSubscriptionSummaryPath(schoolId)));
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  Future<String> createPlatformSchool({
    required String name,
    String code = '',
    String email = '',
    String phone = '',
    String address = '',
  }) async {
    if (name.trim().isEmpty) return 'Enter the school name.';
    try {
      await ApiClient.instance.post(ApiConfig.platformSchoolsPath, {
        'name': name.trim(),
        if (code.trim().isNotEmpty) 'code': code.trim(),
        if (email.trim().isNotEmpty) 'email': email.trim(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (address.trim().isNotEmpty) 'address': address.trim(),
      });
      return '';
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not create this school.';
    }
  }

  Future<List<Map<String, dynamic>>> fetchPlatformSignupRequests() async {
    try {
      return await _allPages(ApiConfig.platformSignupRequestsPath, const {});
    } catch (_) {}
    return const [];
  }

  Future<String> updateSignupRequestStatus(String id, String status) async {
    if (id.isEmpty) return 'Missing signup request.';
    try {
      await ApiClient.instance.patch(ApiConfig.platformSignupRequestPath(id), {'status': status});
      return '';
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update this signup request.';
    }
  }

  Future<List<Map<String, dynamic>>> fetchPlatformContactMessages() async {
    try {
      return await _allPages(ApiConfig.platformContactMessagesPath, const {});
    } catch (_) {}
    return const [];
  }

  Future<String> markContactMessageRead(String id) async {
    if (id.isEmpty) return 'Missing message.';
    try {
      await ApiClient.instance.patch(ApiConfig.platformContactMessagePath(id), {'read': true});
      return '';
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update this message.';
    }
  }

  bool canMarkAttendance(AppUser user, {String className = '', String classId = ''}) {
    if (user.role != Role.teacher) return false;
    if (user.permissions.isNotEmpty && !user.permissions.contains('attendance.mark')) return false;
    final rooms = homeroomClassesFor(user);
    if (rooms.isEmpty) return false;
    if (className.isEmpty && classId.isEmpty) return true;
    return rooms.any((c) => (className.isNotEmpty && c.name == className) || (classId.isNotEmpty && c.id == classId));
  }

  List<NamedRecord> teacherFocusClasses(AppUser user) {
    final rooms = homeroomClassesFor(user);
    if (rooms.isNotEmpty) return rooms;
    final me = staffRecordFor(user);
    final names = {
      user.displayName.trim().toLowerCase(),
      if (me != null) me.name.trim().toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
    final taught = <String>{
      for (final slot in timetable)
        if (slot.className.isNotEmpty && names.contains(slot.teacher.trim().toLowerCase())) slot.className,
    };
    final matched = [for (final klass in classes) if (taught.contains(klass.name)) klass];
    return matched.isNotEmpty ? matched : classes;
  }

  String classTeacherNameFor({String className = '', String classId = ''}) {
    for (final klass in classes) {
      final hit = (classId.isNotEmpty && klass.id == classId) || (className.isNotEmpty && klass.name == className);
      if (hit && klass.link.isNotEmpty) return klass.link;
    }
    for (final row in tableRows('school_classes')) {
      final id = '${row['id']}';
      final label = _classLabel(row);
      if ((classId.isNotEmpty && id == classId) ||
          (className.isNotEmpty && (label == className || '${row['name']}' == className))) {
        final teachers = row['teachers'];
        if (teachers is List && teachers.isNotEmpty && teachers.first is Map) {
          final n = '${(teachers.first as Map)['full_name'] ?? ''}'.trim();
          if (n.isNotEmpty) return n;
        }
      }
    }
    return 'the class teacher';
  }

  List<TeacherReport> subjectRecordsForClassTeacher(AppUser user) {
    final rooms = homeroomClassesFor(user);
    final names = {for (final r in rooms) r.name};
    return [
      for (final r in teacherReports)
        if (r.type == TeacherReportType.subjectRecord && (names.contains(r.klass) || rooms.any((c) => c.id == r.klass))) r,
    ];
  }

  List<TeacherReport> subjectRecordsFromTeacher(AppUser user) {
    final name = user.displayName.trim().toLowerCase();
    return [
      for (final r in teacherReports)
        if (r.type == TeacherReportType.subjectRecord && r.teacher.trim().toLowerCase() == name) r,
    ];
  }

  void applyUserSchool(AppUser user) {
    _activeEmail = user.email;
    _activeRole = user.role;
    _activeDailyReportsEligible = user.dailyReportsEligible;
    if (user.schoolId.trim().isNotEmpty) schoolId = user.schoolId.trim();
    if (user.school.trim().isNotEmpty) schoolName = user.school.trim();
    if (user.schoolCode.trim().isNotEmpty) schoolCode = user.schoolCode.trim();
    if (user.schoolLogoUrl.trim().isNotEmpty) schoolLogoUrl = user.schoolLogoUrl.trim();
    notifyListeners();
    unawaited(refreshSchoolLogo());
  }

  /// The school logo, downloaded once and kept on the device so every
  /// header (admin, teacher, parent) shows it straight away — also offline
  /// and before the first sync finishes. It lives behind the protected
  /// `/api/school/logo`, so it's fetched through [ApiClient] with the
  /// bearer token and retried on a dropped connection, like the website
  /// does, instead of giving up for the whole session after one failure.
  Uint8List? get schoolLogoBytes => _logoSchool != null && _logoSchool == schoolId ? _logoBytes : null;

  Uint8List? _logoBytes;
  String? _logoSchool; // school the bytes belong to
  String? _logoSource; // logo_url they were downloaded from
  Future<void>? _logoLoad;

  /// A logo the server refused (403/404) isn't asked for again this session.
  final Set<String> _logoRefused = {};

  static const _logoPrefix = 'e10.school_logo.';

  Future<void> refreshSchoolLogo() => _logoLoad ??= _refreshSchoolLogo().whenComplete(() => _logoLoad = null);

  Future<void> _refreshSchoolLogo() async {
    final school = schoolId?.trim() ?? '';
    if (school.isEmpty) return;
    if (_logoSchool != school) await _restoreSchoolLogo(school);
    final source = schoolLogoUrl?.trim() ?? '';
    final url = resolveApiFileUrl(source);
    if (url == null || !ApiSession.instance.isSignedIn) return;
    if (_logoSchool == school && _logoSource == source && _logoBytes != null) return;
    if (_logoRefused.contains(url)) return;
    try {
      final bytes = await ApiClient.instance.getBytes(url);
      if (bytes.isEmpty || schoolId?.trim() != school) return;
      _logoBytes = bytes;
      _logoSchool = school;
      _logoSource = source;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_logoPrefix$school', jsonEncode({'source': source, 'bytes': base64Encode(bytes)}));
      } catch (_) {}
    } on ApiException catch (error) {
      debugPrint('e10.logo failed ${error.status}: ${error.message}');
      // Parents get 403 until the backend opens the route to them; a school
      // without a logo gives 404. Either way: initials, no retry loop.
      if (error.status == 403 || error.status == 404) _logoRefused.add(url);
    } catch (error) {
      debugPrint('e10.logo failed: $error');
      // Network hiccup: keep whatever is cached, try again on the next sync.
    }
  }

  Future<void> _restoreSchoolLogo(String school) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_logoPrefix$school');
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map || schoolId?.trim() != school) return;
      _logoBytes = base64Decode('${data['bytes']}');
      _logoSchool = school;
      _logoSource = '${data['source'] ?? ''}';
      notifyListeners();
    } catch (_) {}
  }

  /// The school removed its logo: forget the device copy too.
  void _dropSchoolLogo(String school) {
    if (_logoSchool == school) {
      _logoBytes = null;
      _logoSchool = null;
      _logoSource = null;
    }
    unawaited(SharedPreferences.getInstance().then((prefs) => prefs.remove('$_logoPrefix$school')).catchError((_) => false));
  }

  /// Turns a relative path the API returned (e.g. `/api/daily-reports/{id}/
  /// photo?v=…`, same shape as the school logo's `/school/logo`) into an
  /// absolute URL. These are protected API routes, not public file URLs —
  /// callers must attach the bearer token themselves (see [ApiSession]).
  String? resolveApiFileUrl(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    final api = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    final origin = api.replaceFirst(RegExp(r'/api$'), '');
    if (trimmed.startsWith('/')) return '$origin$trimmed';
    return '$api/$trimmed';
  }

  /// Confirmed live against PUT /school/profile: name, code, currency_code
  /// and timezone are all required even though only a couple of fields are
  /// actually being edited — this is a full-replace endpoint like the
  /// students one, not a partial-merge one. Callers pass the current store
  /// values for anything they don't want to touch.
  Future<bool> updateSchoolProfile({
    required String name,
    required String code,
    required String currencyCode,
    required String timezone,
    String motto = '',
    String address = '',
    String phone = '',
    String phoneSecondary = '',
    String email = '',
  }) {
    return _mutate(() async {
      await ApiClient.instance.put(ApiConfig.schoolProfilePath, {
        'name': name.trim(),
        'code': code.trim(),
        'currency_code': currencyCode.trim(),
        'timezone': timezone.trim(),
        'motto': motto.trim(),
        'address': address.trim(),
        'phone': phone.trim(),
        // Confirmed live: omitting an optional field leaves it unchanged,
        // but explicit null clears it — so send null rather than dropping
        // the key, otherwise there's no way to clear this from the form.
        'phone_secondary': phoneSecondary.trim().isEmpty ? null : phoneSecondary.trim(),
        'email': email.trim(),
      });
    });
  }

  Map<String, List<Map<String, dynamic>>> tables = {};
  String catalogKey = 'students';
  String catalogTitle = 'Records';

  final List<Student> students = [];

  List<String> get classNames {
    final names = classes.map((c) => c.name).where((n) => n.isNotEmpty).toSet();
    for (final student in students) {
      if (student.klass.isNotEmpty) names.add(student.klass);
    }
    return names.toList();
  }

  List<String> get studentNames => students.map((s) => s.name).toList();

  List<String> get accountantNames => accountants.map((a) => a.name).toList();

  List<String> get teacherNames => teachers.map((t) => t.name).toList();

  List<String> get departmentNames => departments.map((d) => d.name).toList();

  List<String> get subjectNames {
    final fromSchool = [
      for (final row in tables['subjects'] ?? const <Map<String, dynamic>>[])
        _asString(row['name']),
    ].where((name) => name.isNotEmpty).toSet();
    if (fromSchool.isNotEmpty) return fromSchool.toList()..sort();
    final names = departments.map((d) => d.name).toSet();
    for (final teacher in teachers) {
      if (teacher.detail.isNotEmpty) names.add(teacher.detail);
    }
    for (final mark in academics) {
      names.add(mark.subject);
    }
    return names.toList();
  }

  List<ReportSubjectMark> get reportSubjectTemplates {
    final fromSchool = [
      for (final row in tables['subjects'] ?? const <Map<String, dynamic>>[])
        if (_asString(row['name']).isNotEmpty)
          ReportSubjectMark(subject: _asString(row['name']), subjectId: '${row['id'] ?? ''}'),
    ];
    if (fromSchool.isNotEmpty) return fromSchool;
    return [for (final name in gesReportSubjects) ReportSubjectMark(subject: name)];
  }

  String get currentTermLabel {
    for (final row in tables['academic_terms'] ?? const <Map<String, dynamic>>[]) {
      if ('${row['id']}' == academicTermId) return _asString(row['name']);
    }
    final terms = tables['academic_terms'] ?? const <Map<String, dynamic>>[];
    if (terms.isNotEmpty) return _asString(terms.first['name']);
    return 'Term 1';
  }

  /// An academic year's label. The API calls it `year` ("2025/2026"), not
  /// `name` — reading `name` left the year blank everywhere.
  String _yearLabelOf(Map row) => _asString(row['year'] ?? row['name']);

  String get currentYearLabel {
    for (final row in tables['academic_years'] ?? const <Map<String, dynamic>>[]) {
      if ('${row['id']}' == academicYearId) return _yearLabelOf(row);
    }
    final years = tables['academic_years'] ?? const <Map<String, dynamic>>[];
    if (years.isNotEmpty) return _yearLabelOf(years.first);
    return '';
  }

  /// The school's academic years, newest first as the API sends them.
  List<String> get yearLabels => [
        for (final row in tables['academic_years'] ?? const <Map<String, dynamic>>[])
          if (_yearLabelOf(row).isNotEmpty) _yearLabelOf(row),
      ];

  /// Year label for an academic year id ('' when unknown).
  String yearLabelFor(String id) {
    for (final row in tables['academic_years'] ?? const <Map<String, dynamic>>[]) {
      if ('${row['id']}' == id) return _yearLabelOf(row);
    }
    return '';
  }

  List<String> get termLabels {
    final names = [
      for (final row in tables['academic_terms'] ?? const <Map<String, dynamic>>[])
        _asString(row['name']),
    ].where((name) => name.isNotEmpty).toList();
    if (names.isNotEmpty) return names;
    return const ['Term 1', 'Term 2', 'Term 3'];
  }

  String? classIdFor(String klass) {
    for (final item in classes) {
      if (item.name == klass) return item.id;
    }
    for (final student in students) {
      if (student.klass == klass && student.classId.isNotEmpty) return student.classId;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Teacher assignments: subject teacher / class teacher
  // ------------------------------------------------------------------

  /// The signed-in teacher's own subject assignments (subject + class), from
  /// the school server — not guessed from the timetable.
  List<({String classId, String className, String subjectId, String subjectName})> get mySubjectAssignments {
    final me = (sessionStaffId ?? '').trim();
    final out = <({String classId, String className, String subjectId, String subjectName})>[];
    final seen = <String>{};
    for (final row in tableRows('teacher_subject_assignments')) {
      if (me.isEmpty || '${row['staff_id']}' != me) continue;
      final classId = '${row['class_id'] ?? ''}';
      final subjectId = '${row['subject_id'] ?? ''}';
      if (classId.isEmpty || subjectId.isEmpty || !seen.add('$classId|$subjectId')) continue;
      final klass = row['class'];
      out.add((
        classId: classId,
        className: klass is Map ? _classLabel(klass) : classDisplayName(classId),
        subjectId: subjectId,
        subjectName: _relationLabel(row['subject']) ?? subjectDisplayName(subjectId),
      ));
    }
    out.sort((a, b) => '${a.subjectName}${a.className}'.compareTo('${b.subjectName}${b.className}'));
    return out;
  }

  /// Whether a piece of class work (assignment, or class test) was set by
  /// the signed-in teacher. Teacher dashboards show only their own work —
  /// another teacher's homework never appears there.
  bool isMyClassWork(Map<String, dynamic> row) {
    final me = (sessionStaffId ?? '').trim();
    if (me.isEmpty) return true;
    final teacher = row['teacher'];
    final teacherId = '${row['teacher_id'] ?? (teacher is Map ? teacher['id'] : '') ?? ''}';
    if (teacherId.isNotEmpty && teacherId != 'null') return teacherId == me;
    // Class tests carry no teacher: they belong to that subject's teacher.
    final klass = row['class'];
    final subject = row['subject'];
    final classId = '${row['class_id'] ?? (klass is Map ? klass['id'] : '') ?? ''}';
    final subjectId = '${row['subject_id'] ?? (subject is Map ? subject['id'] : '') ?? ''}';
    return mySubjectAssignments.any((a) => a.classId == classId && a.subjectId == subjectId);
  }

  /// Subjects the signed-in teacher teaches in [classId].
  List<NamedRecord> subjectsTaughtIn(String classId) => [
        for (final a in mySubjectAssignments)
          if (a.classId == classId) NamedRecord(id: a.subjectId, name: a.subjectName),
      ];

  /// Classes where the signed-in teacher teaches at least one subject.
  List<NamedRecord> get mySubjectClasses {
    final ids = <String>{};
    return [
      for (final a in mySubjectAssignments)
        if (ids.add(a.classId)) NamedRecord(id: a.classId, name: a.className),
    ];
  }

  // ------------------------------------------------------------------
  // Marking: homework / assignments / exercises and class tests
  // ------------------------------------------------------------------

  /// Students actively in [classId], for a marking sheet.
  List<Student> studentsInClass(String classId) {
    final name = classDisplayName(classId);
    return [for (final s in students) if (s.classId == classId || (s.classId.isEmpty && s.klass == name)) s]
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Every page of a list (the server caps a page at 100), throwing like a
  /// plain GET so callers keep their own error messages.
  Future<List<Map<String, dynamic>>> _allPages(String path, Map<String, String> query, {Duration timeout = const Duration(seconds: 20)}) async {
    final full = {...query, 'per_page': '100'};
    final first = await ApiClient.instance.get(path, query: full, timeout: timeout);
    final rows = [..._listOf(_unwrap(first) ?? first)];
    final meta = first is Map && first['meta'] is Map ? first['meta'] as Map : null;
    final last = int.tryParse('${meta?['last_page'] ?? 1}') ?? 1;
    for (var page = 2; page <= last && page <= 30; page++) {
      final more = await ApiClient.instance.get(path, query: {...full, 'page': '$page'}, timeout: timeout);
      rows.addAll(_listOf(_unwrap(more) ?? more));
    }
    return rows;
  }

  Future<({List<Map<String, dynamic>> rows, String error})> fetchSubmissions(String assignmentId) async {
    if (!ApiSession.instance.isSignedIn) return (rows: const <Map<String, dynamic>>[], error: 'Sign in to mark work.');
    try {
      final rows = await _allPages('/assignment-submissions', {'assignment_id': assignmentId});
      return (rows: rows, error: '');
    } on ApiException catch (e) {
      return (rows: const <Map<String, dynamic>>[], error: e.message);
    } catch (_) {
      return (rows: const <Map<String, dynamic>>[], error: 'Could not load the marks from the school server.');
    }
  }

  /// Saves each student's mark for a piece of work (score out of [maxScore]);
  /// students with no score are left as they are.
  Future<String> saveSubmissionMarks({
    required String assignmentId,
    required double maxScore,
    required Map<String, double?> scores,
    required List<Map<String, dynamic>> existing,
    Map<String, String> comments = const {},
  }) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in to mark work.';
    if (maxScore <= 0) return 'Enter what the work is marked out of.';
    final byStudent = {for (final row in existing) '${row['student_id']}': row};
    var saved = 0;
    for (final entry in scores.entries) {
      final score = entry.value;
      if (score == null) continue;
      if (score < 0 || score > maxScore) return 'Marks must be between 0 and ${_trimNum(maxScore)}.';
      final body = {
        'assignment_id': assignmentId,
        'student_id': entry.key,
        'status': 'marked',
        'score': score,
        'max_score': maxScore,
        if ((comments[entry.key] ?? '').trim().isNotEmpty) 'teacher_comment': comments[entry.key]!.trim(),
      };
      try {
        final current = byStudent[entry.key];
        if (current != null && _isUuid('${current['id']}')) {
          await ApiClient.instance.put('/assignment-submissions/${current['id']}', body);
        } else {
          await ApiClient.instance.post('/assignment-submissions', body);
        }
        saved++;
      } on ApiException catch (e) {
        return saved == 0 ? e.message : 'Saved $saved marks, then: ${e.message}';
      } catch (_) {
        return saved == 0 ? 'Could not reach the school server. No marks were saved.' : 'Saved $saved marks, then lost the connection.';
      }
    }
    if (saved == 0) return 'Enter at least one mark.';
    unawaited(syncFromApi(budget: const Duration(seconds: 20)));
    return '';
  }

  static String _trimNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Creates a class test (an exam of kind `class_test`) for this term.
  Future<({String id, String error})> createClassTest({
    required String classId,
    required String subjectId,
    required String name,
    required double maxScore,
    String date = '',
  }) async {
    if (!ApiSession.instance.isSignedIn) return (id: '', error: 'Sign in to set a class test.');
    final termId = academicTermId;
    if (termId == null || !_isUuid(termId)) return (id: '', error: 'The school has no current term set.');
    if (maxScore <= 0) return (id: '', error: 'Enter what the test is marked out of.');
    try {
      final response = await ApiClient.instance.post('/exams', {
        'class_id': classId,
        'subject_id': subjectId,
        'academic_term_id': termId,
        'name': name.trim().isEmpty ? 'Class test' : name.trim(),
        'kind': 'class_test',
        'max_score': maxScore,
        if (date.trim().isNotEmpty) 'exam_date': date.trim(),
      });
      final data = _unwrap(response);
      final id = data is Map ? '${data['id'] ?? ''}' : '';
      unawaited(syncFromApi(budget: const Duration(seconds: 20)));
      return (id: id, error: '');
    } on ApiException catch (e) {
      return (id: '', error: e.message);
    } catch (_) {
      return (id: '', error: 'Could not reach the school server. The test was not created.');
    }
  }

  Future<({List<Map<String, dynamic>> rows, String error})> fetchExamResults(String examId) async {
    if (!ApiSession.instance.isSignedIn) return (rows: const <Map<String, dynamic>>[], error: 'Sign in to enter marks.');
    try {
      final rows = await _allPages('/exam-results', {'exam_id': examId});
      return (rows: rows, error: '');
    } on ApiException catch (e) {
      return (rows: const <Map<String, dynamic>>[], error: e.message);
    } catch (_) {
      return (rows: const <Map<String, dynamic>>[], error: 'Could not load the marks from the school server.');
    }
  }

  Future<String> saveExamResults({
    required String examId,
    required double maxScore,
    required Map<String, double?> scores,
    required List<Map<String, dynamic>> existing,
  }) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in to enter marks.';
    final byStudent = {for (final row in existing) '${row['student_id']}': row};
    var saved = 0;
    for (final entry in scores.entries) {
      final score = entry.value;
      if (score == null) continue;
      if (score < 0 || (maxScore > 0 && score > maxScore)) return 'Marks must be between 0 and ${_trimNum(maxScore)}.';
      final body = {'exam_id': examId, 'student_id': entry.key, 'score': score};
      try {
        final current = byStudent[entry.key];
        if (current != null && _isUuid('${current['id']}')) {
          await ApiClient.instance.put('/exam-results/${current['id']}', body);
        } else {
          await ApiClient.instance.post('/exam-results', body);
        }
        saved++;
      } on ApiException catch (e) {
        return saved == 0 ? e.message : 'Saved $saved marks, then: ${e.message}';
      } catch (_) {
        return saved == 0 ? 'Could not reach the school server. No marks were saved.' : 'Saved $saved marks, then lost the connection.';
      }
    }
    if (saved == 0) return 'Enter at least one mark.';
    unawaited(syncFromApi(budget: const Duration(seconds: 20)));
    return '';
  }

  // ------------------------------------------------------------------
  // Class report: class work calculated by the server
  // ------------------------------------------------------------------

  /// Each student's class-work score per subject, calculated on the school
  /// server from the subject teachers' marked homework, assignments,
  /// exercises and class tests. Class teacher (of that class) and admin only.
  Future<({int weight, Map<String, Map<String, double>> scores, String error})> fetchClassWork({
    required String classId,
    String? termId,
  }) async {
    final term = termId ?? academicTermId;
    const empty = <String, Map<String, double>>{};
    if (!ApiSession.instance.isSignedIn) return (weight: classScoreWeight, scores: empty, error: 'Sign in first.');
    if (term == null || !_isUuid(term)) return (weight: classScoreWeight, scores: empty, error: 'The school has no current term set.');
    try {
      final data = _unwrap(await ApiClient.instance.get('/report-cards/class-work',
          query: {'class_id': classId, 'academic_term_id': term}, timeout: const Duration(seconds: 20)));
      if (data is! Map) return (weight: classScoreWeight, scores: empty, error: 'The school server sent no class work.');
      final weight = int.tryParse('${data['class_score_weight'] ?? ''}') ?? classScoreWeight;
      classScoreWeight = weight;
      final scores = <String, Map<String, double>>{};
      for (final student in _listOf(data['students'])) {
        final bySubject = <String, double>{};
        for (final line in _listOf(student['subjects'])) {
          final v = double.tryParse('${line['class_score'] ?? ''}');
          if (v != null) bySubject['${line['subject_id']}'] = v;
        }
        scores['${student['student_id']}'] = bySubject;
      }
      return (weight: weight, scores: scores, error: '');
    } on ApiException catch (e) {
      final message = e.status == 404
          ? 'The school server does not calculate class work yet — it needs the latest update.'
          : e.message;
      return (weight: classScoreWeight, scores: empty, error: message);
    } catch (_) {
      return (weight: classScoreWeight, scores: empty, error: 'Could not reach the school server.');
    }
  }

  /// Admin: how many of the 100 report marks come from class work.
  Future<String> saveReportSettings(int classWeight) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in first.';
    if (classWeight < 0 || classWeight > 100) return 'Class work must be between 0 and 100 marks.';
    try {
      await ApiClient.instance.put('/school/report-settings', {'class_score_weight': classWeight});
      classScoreWeight = classWeight;
      notifyListeners();
      return '';
    } on ApiException catch (e) {
      return e.status == 404 ? 'The school server needs the latest update before this can be saved.' : e.message;
    } catch (_) {
      return 'Could not reach the school server.';
    }
  }

  String? termIdFor(String term) {
    for (final row in tables['academic_terms'] ?? const <Map<String, dynamic>>[]) {
      if (_asString(row['name']) == term) return '${row['id']}';
    }
    return academicTermId;
  }

  final List<NamedRecord> classes = [];

  final List<NamedRecord> teachers = [];
  final List<NamedRecord> departments = [];
  final List<NamedRecord> parents = [];
  final List<RoleAccount> roleAccounts = [];
  final List<Invoice> invoices = [];
  final List<NamedRecord> accountants = [];
  String focusedChildId = '';
  String focusedClassId = '';

  void focusChild(String id) {
    if (focusedChildId == id) return;
    focusedChildId = id;
    notifyListeners();
  }

  void focusClass(String id) {
    if (focusedClassId == id) return;
    focusedClassId = id;
    notifyListeners();
  }

  Student? focusedChild([Role? role]) {
    final kids = linkedChildren(role);
    if (kids.isEmpty) return null;
    if (focusedChildId.isNotEmpty) {
      final match = kids.where((k) => k.id == focusedChildId).firstOrNull;
      if (match != null) return match;
    }
    return kids.first;
  }

  NamedRecord? focusedClassRecord() {
    if (focusedClassId.isEmpty) return null;
    return classes.where((c) => c.id == focusedClassId).firstOrNull;
  }

  bool rowMatchesStudent(Map<String, dynamic> row, Student child) {
    if (child.id.isEmpty && child.name.isEmpty) return false;
    final sid = '${row['student_id'] ?? ''}';
    if (child.id.isNotEmpty && sid == child.id) return true;
    if (row['student'] is Map) {
      final m = Map<String, dynamic>.from(row['student'] as Map);
      if (child.id.isNotEmpty && '${m['id'] ?? ''}' == child.id) return true;
      final name = '${m['full_name'] ?? m['name'] ?? ''}';
      if (name.isNotEmpty && name == child.name) return true;
    }
    final name = '${row['student_name'] ?? (row['student'] is String ? row['student'] : '')}';
    if (name.isNotEmpty && name == child.name) return true;
    final classId = '${row['class_id'] ?? (row['class'] is Map ? (row['class'] as Map)['id'] : '')}';
    if (child.classId.isNotEmpty && classId == child.classId) return true;
    if (row['class'] is Map) {
      final klass = row['class'] as Map;
      final label = '${klass['name'] ?? ''} ${klass['stream'] ?? ''}'.trim();
      if (child.klass.isNotEmpty && (label == child.klass || '${klass['name']}' == child.klass)) {
        return true;
      }
    }
    final className = '${row['class_name'] ?? row['klass'] ?? row['class'] ?? ''}';
    return child.klass.isNotEmpty && className == child.klass;
  }

  bool rowMatchesClass(Map<String, dynamic> row, NamedRecord klass) {
    final classId = '${row['class_id'] ?? (row['class'] is Map ? (row['class'] as Map)['id'] : '')}';
    if (klass.id.isNotEmpty && classId == klass.id) return true;
    if (row['class'] is Map) {
      final mapped = row['class'] as Map;
      final label = '${mapped['name'] ?? ''} ${mapped['stream'] ?? ''}'.trim();
      if (klass.name.isNotEmpty && (label == klass.name || '${mapped['name']}' == klass.name)) {
        return true;
      }
    }
    final className = '${row['class_name'] ?? row['klass'] ?? row['class'] ?? ''}';
    return klass.name.isNotEmpty && className == klass.name;
  }

  final List<AcademicMark> academics = [];
  final List<TimeSlot> timetable = [];
  final List<SchoolReport> reports = [];
  final List<TeacherReport> teacherReports = [];
  final List<AcademicReport> academicReports = [];
  final Map<String, String> rollMarks = {};
  final List<ChatPreview> messages = [];
  final List<AppNotification> notifications = [];
  final Set<String> _apiNotificationIds = <String>{};
  final List<PickupPass> pickupPasses = [];
  final List<PickupDelegate> pickupDelegates = [];
  final List<PickupLog> pickupLogs = [];
  int _pickupSeq = 0;

  List<AppNotification> noticesFor(Role role) {
    bool visible(AppNotification n) {
      if (n.audience.isEmpty) return true;
      if (n.audience.contains(role)) return true;
      if (role.isAdminPortal && n.audience.any((r) => r.isAdminPortal)) return true;
      return false;
    }

    return [
      for (final n in notifications)
        if (visible(n)) n,
      if (role == Role.teacher) ..._arrivalNotices.values,
      if (role.isAdminPortal) ..._paymentNotices.values,
      if (role.isAdminPortal) ..._staffClockNotices.values,
      if (role == Role.parent || role == Role.teacher) ..._homeworkNotices.values,
    ];
  }

  /// Every school this guardian's phone number is linked to — confirmed
  /// live against the deployed API on the verify-code/me response's
  /// `guardian_schools` key: `[{"id": ..., "name": ...}, ...]`. Each entry
  /// is a fully separate account under the hood (see the backend's
  /// GuardianAuthController::findActiveGuardianUser — one `users` row per
  /// school sharing this phone), so this carries no children of its own;
  /// picking one calls `Auth.guardianEnterSchool(id)` to actually switch
  /// into it and load its own [linkedChildren]. Empty when the phone is
  /// only linked to one school (or the account isn't a guardian at all).
  List<({String id, String name})> guardianSchools() {
    final raw = ApiSession.instance.user?['guardian_schools'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map && _asString(entry['id']).isNotEmpty)
          (id: _asString(entry['id']), name: _asString(entry['name'])),
    ];
  }

  /// Children linked to the signed-in guardian (or demo parent). Staff see [students].
  List<Student> linkedChildren([Role? role]) {
    final isParent = role == Role.parent || sessionGuardianId != null;
    if (!isParent) return List<Student>.from(students);

    Student fromMap(Map raw) {
      final row = Map<String, dynamic>.from(raw);
      final name = _asString(row['full_name']).isNotEmpty ? _asString(row['full_name']) : _asString(row['name']);
      final guardian = _primaryGuardianOf(row);
      return Student(
        id: '${row['id'] ?? ''}',
        name: name.isEmpty ? 'Child' : name,
        klass: _studentClassName(row),
        classId: _studentClassId(row),
        userId: _studentUserId(row),
        avatar: name.isEmpty ? 'C' : name,
        attendance: _attendancePercent('${row['id'] ?? ''}'),
        fees: 0,
        outstanding: _outstandingFor('${row['id'] ?? ''}'),
        status: _asString(row['status']).isEmpty ? 'active' : _asString(row['status']),
        boarder: _asString(row['residence_type']) == 'boarding',
        palmCredentialId: _asString(row['active_palm_credential_id']),
        cardNumber: _asString(row['card_number']),
        studentNumber: _studentNumber(row),
        schoolId: _asString(row['school_id']),
        schoolName: _studentSchoolName(row),
        dateOfBirth: _asString(row['date_of_birth']),
        gender: _asString(row['gender']),
        emergencyContactPhone: _asString(row['emergency_contact_phone']),
        allergies: _asString(row['allergies']),
        medicalNotes: _asString(row['medical_notes']),
        admissionDate: _asString(row['admission_date']),
        guardianName: guardian.name,
        guardianPhone: guardian.phone,
        guardianRelationship: guardian.relationship,
      );
    }

    List<Student> fromIds(Iterable<String> ids) {
      final want = ids.where((id) => id.isNotEmpty).toSet();
      if (want.isEmpty) return const [];
      final matched = [for (final s in students) if (want.contains(s.id)) s];
      if (matched.isNotEmpty) return matched;
      return [
        for (final row in tableRows('students'))
          if (want.contains('${row['id']}')) fromMap(row),
      ];
    }

    final session = ApiSession.instance.user;

    final guardian = session?['guardian'];
    if (guardian is Map) {
      final kids = guardian['students'];
      if (kids is List && kids.isNotEmpty) {
        final fromSession = <Student>[];
        final seen = <String>{};
        for (final kid in kids) {
          if (kid is! Map) continue;
          final built = fromMap(kid);
          if (built.id.isEmpty || !seen.add(built.id)) continue;
          final existing = students.where((s) => s.id == built.id).firstOrNull;
          fromSession.add(existing ?? built);
        }
        if (fromSession.isNotEmpty) return fromSession;
      }
    }

    final gid = sessionGuardianId;
    final uid = sessionUserId;
    for (final row in tableRows('guardians')) {
      final match = (gid != null && '${row['id']}' == gid) ||
          (uid != null && '${row['user_id']}' == uid);
      if (!match) continue;
      final kids = row['students'];
      if (kids is! List || kids.isEmpty) continue;
      final out = <Student>[];
      final seen = <String>{};
      for (final kid in kids) {
        if (kid is! Map) continue;
        final built = fromMap(kid);
        if (built.id.isEmpty || !seen.add(built.id)) continue;
        final existing = students.where((s) => s.id == built.id).firstOrNull;
        out.add(existing ?? built);
      }
      if (out.isNotEmpty) return out;
    }

    for (final p in parents) {
      if (uid != null && p.userId == uid && p.link.isNotEmpty) {
        final matched = fromIds(p.link.split(','));
        if (matched.isNotEmpty) return matched;
      }
    }

    // Signed-in parent: bootstrap already scoped [students] to linked children.
    if (ApiSession.instance.isSignedIn && students.isNotEmpty) {
      return List<Student>.from(students);
    }

    return List<Student>.from(students);
  }

  /// Today's attendance alerts (arrived / late / very late / absent) for the
  /// dashboard card, newest first. They are messages the server delivers to
  /// the "School System" thread in the Messages inbox.
  List<AppNotification> attendanceNoticesToday(Role role) {
    final today = DateTime.now();
    bool isToday(String raw) {
      final d = parseFlexibleDate(raw)?.toLocal();
      return d == null || (d.year == today.year && d.month == today.month && d.day == today.day);
    }

    final out = <AppNotification>[];
    for (final thread in messagesFor(role)) {
      if (!thread.isSystem) continue;
      final unreadTail = thread.unreadCount;
      for (var i = 0; i < thread.lines.length; i++) {
        final line = thread.lines[i];
        if (!line.category.startsWith('attendance_') || line.category == 'attendance_checked_out') continue;
        if (!isToday(line.time)) continue;
        out.add(AppNotification(
          id: line.id,
          type: line.category,
          text: line.body,
          time: line.time,
          icon: 'bell',
          color: 'slate',
          unread: i >= thread.lines.length - unreadTail,
        ));
      }
    }
    out.sort((a, b) => b.time.compareTo(a.time));
    return out;
  }

  int unreadNoticeCount(Role role) => noticesFor(role).where((n) => n.unread).length;

  int inboxUnreadCount(Role role) => unreadNoticeCount(role) + unreadMessageCountFor(role);

  String rollOf(String studentId) => rollMarks[studentId] ?? '';

  List<Map<String, dynamic>> attendanceRowsFor(String studentId) {
    final rows = [
      for (final row in tables['attendance'] ?? const <Map<String, dynamic>>[])
        if ('${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}' == studentId)
          Map<String, dynamic>.from(row),
    ];
    rows.sort((a, b) => _asString(b['date'] ?? b['created_at']).compareTo(_asString(a['date'] ?? a['created_at'])));
    return rows;
  }

  /// Present/on-time/late/absent day counts for the parent dashboard's
  /// attendance grid. Scoped to the current academic term when the
  /// attendance rows actually carry a term id (`academic_term_id`/`term_id`);
  /// the API doesn't always send one, in which case there's nothing to scope
  /// by and this falls back to every recorded day.
  AttendanceTermSummary attendanceTermSummaryFor(String studentId) {
    final all = attendanceRowsFor(studentId);
    final termId = academicTermId;
    final hasTermData = termId != null && termId.isNotEmpty && all.any((row) => _asString(row['academic_term_id'] ?? row['term_id']).isNotEmpty);
    final rows = hasTermData ? all.where((row) => _asString(row['academic_term_id'] ?? row['term_id']) == termId).toList() : all;

    var onTime = 0, late = 0, absent = 0, excused = 0, leftEarly = 0;
    for (final row in rows) {
      final status = _asString(row['status']).toLowerCase();
      if (status == 'late') {
        late++;
      } else if (status == 'excused' || status == 'authorized_absence' || status == 'excuse') {
        excused++;
      } else if (status == 'absent') {
        absent++;
      } else if (status == 'early_departure') {
        leftEarly++;
      } else {
        onTime++;
      }
    }
    return AttendanceTermSummary(onTime: onTime, late: late, absent: absent, excused: excused, totalDays: rows.length, leftEarly: leftEarly);
  }

  /// True when the child is in crèche / KG / nursery — the same class-name
  /// rule the API uses for early-years departments — so the dashboard can
  /// offer the Daily report instead of the Timetable.
  bool isEarlyYearsChild(Student student) {
    // The server's own flag, but only while it still describes the child's
    // current class — after a promotion (KG → Class 1) the old flag must not
    // keep the KG dashboard alive.
    final kids = ApiSession.instance.user?['guardian'] is Map ? (ApiSession.instance.user!['guardian'] as Map)['students'] : null;
    if (kids is List) {
      for (final kid in kids) {
        if (kid is! Map || '${kid['id']}' != student.id || kid['is_early_years'] == null) continue;
        final kidClass = '${kid['class_id'] ?? ''}';
        if (student.classId.isEmpty || kidClass.isEmpty || kidClass == student.classId) {
          return kid['is_early_years'] == true || kid['is_early_years'] == 1;
        }
      }
    }
    return isEarlyYearsClass(id: student.classId, name: student.klass);
  }

  /// The number people know a student by: the admission number, else the
  /// student card number — never a database key (UUID/ULID/hash), which
  /// shows as "Not assigned" instead.
  String studentDisplayId(Student student) {
    final number = student.studentNumber.trim();
    if (number.isNotEmpty && !looksMachineId(number)) return number;
    final card = student.cardNumber.trim();
    if (card.isNotEmpty && !looksMachineId(card)) return card;
    return 'Not assigned';
  }

  /// True for internal identifiers that mean nothing to a person: UUIDs,
  /// ULIDs, long hex/hash strings, or long unbroken letter+digit tokens.
  /// Admission and card numbers are short or have separators
  /// ("AGA123/2026/001", "STU-00042", "10023").
  static bool looksMachineId(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(v)) return true;
    if (RegExp(r'^[0-9A-HJKMNP-TV-Za-hjkmnp-tv-z]{26}$').hasMatch(v)) return true; // ULID
    if (RegExp(r'^[0-9a-fA-F]{24,}$').hasMatch(v)) return true; // hex hash / object id
    if (v.length >= 20 && RegExp(r'^[A-Za-z0-9+/=_]+$').hasMatch(v) && RegExp(r'[A-Za-z]').hasMatch(v) && RegExp(r'[0-9]').hasMatch(v)) {
      return true; // base64 / token-like, no separators
    }
    if (v.startsWith('eyJ') || v.startsWith(r'$2y$')) return true; // encrypted payload / bcrypt
    return false;
  }

  String _studentNumber(Map<String, dynamic> row) {
    // Only real, human-issued numbers. `student_id` / `code` are database
    // keys (the website never shows them to parents either).
    for (final key in const [
      'admission_number',
      'student_number',
      'admission_no',
      'registration_number',
    ]) {
      final value = _asString(row[key]);
      if (value.isNotEmpty && !looksMachineId(value)) return value;
    }
    return '';
  }

  void mergeAttendanceRows(List<Map<String, dynamic>> rows) {
    final current = [
      for (final row in tables['attendance'] ?? const <Map<String, dynamic>>[])
        Map<String, dynamic>.from(row),
    ];
    final byId = <String, Map<String, dynamic>>{
      for (final row in current
          .where((row) => _asString(row['id']).isNotEmpty))
        _asString(row['id']): row,
    };
    for (final row in rows) {
      final id = _asString(row['id']);
      if (id.isNotEmpty) {
        byId[id] = Map<String, dynamic>.from(row);
      } else {
        current.add(Map<String, dynamic>.from(row));
      }
    }
    tables['attendance'] = [...byId.values, ...current.where((row) => _asString(row['id']).isEmpty)];
    notifyListeners();
  }

  void setRoll(String studentId, String status) {
    rollMarks[studentId] = status;
    notifyListeners();
  }

  String billLabelFor(String studentName) {
    final due = invoices.where((i) => i.student == studentName && !i.isPaid).toList();
    if (due.isEmpty) {
      final any = invoices.any((i) => i.student == studentName);
      return any ? 'Paid' : '—';
    }
    final sum = due.fold<double>(0, (a, b) => a + b.dueAmount);
    return 'Due ${sum.toStringAsFixed(0)}';
  }

  DateTime? parseFlexibleDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t) ?? DateTime.tryParse(t.replaceAll('/', '-'));
  }

  double _moneyOf(dynamic v) {
    if (v is num) return v.toDouble();
    final raw = '$v'.trim().replaceAll(',', '');
    if (raw.isEmpty || raw == 'null') return 0;
    return double.tryParse(raw) ?? 0;
  }

  num _numOf(dynamic v, [num fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v;
    final raw = '$v'.trim().replaceAll(',', '');
    if (raw.isEmpty || raw == 'null') return fallback;
    return num.tryParse(raw) ?? fallback;
  }

  int _intOf(dynamic v, [int fallback = 0]) => _numOf(v, fallback).round();

  String _cellOf(dynamic v) {
    if (v is Map) return '${v['value'] ?? v['name'] ?? ''}';
    return v == null ? '' : '$v';
  }

  bool _incomingPayment(Map<String, dynamic> row) {
    return !_cellOf(row['kind']).toLowerCase().contains('out');
  }

  bool _successfulPayment(Map<String, dynamic> row) {
    final status = _cellOf(row['status']).toLowerCase();
    return status.isEmpty || status == 'successful' || status == 'paid' || status == 'completed';
  }

  List<Map<String, dynamic>> get paymentRecords {
    final rows = [
      for (final row in tableRows('payments')) Map<String, dynamic>.from(row),
    ];
    rows.sort((a, b) {
      final da = parseFlexibleDate('${a['paid_at'] ?? a['created_at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = parseFlexibleDate('${b['paid_at'] ?? b['created_at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return rows;
  }

  DateTime? paymentWhen(Map<String, dynamic> row) {
    return parseFlexibleDate('${row['paid_at'] ?? row['created_at'] ?? ''}');
  }

  String paymentStudentName(Map<String, dynamic> row) {
    if (row['student'] is Map) return _asString((row['student'] as Map)['full_name']);
    return _cellOf(row['student_name'] ?? row['payer'] ?? row['name']);
  }

  double paymentAmount(Map<String, dynamic> row) => _moneyOf(row['amount']);

  String paymentMethodLabel(Map<String, dynamic> row) {
    final method = _cellOf(row['method']).toLowerCase();
    if (method.contains('telecel')) return 'Telecel';
    if (method.contains('airtel')) return 'AirtelTigo';
    if (method.contains('momo') || method.contains('mtn')) return 'MTN MoMo';
    if (method.contains('card')) return 'Card';
    if (method.contains('bank')) return 'Bank';
    if (method.contains('cash')) return 'Cash';
    return method.isEmpty ? 'Payment' : _cellOf(row['method']);
  }

  double feesCollected({bool Function(DateTime?)? matches}) {
    final pays = paymentRecords;
    if (pays.isNotEmpty) {
      var sum = 0.0;
      for (final row in pays) {
        if (!_incomingPayment(row) || !_successfulPayment(row)) continue;
        if (matches != null && !matches(paymentWhen(row))) continue;
        sum += _moneyOf(row['amount']);
      }
      return sum;
    }
    var sum = 0.0;
    for (final inv in invoices.where((i) => i.isPaid)) {
      if (matches != null && !matches(parseFlexibleDate(inv.date))) continue;
      sum += inv.amount;
    }
    return sum;
  }

  int feesPaymentCount({bool Function(DateTime?)? matches}) {
    final pays = paymentRecords;
    if (pays.isNotEmpty) {
      var n = 0;
      for (final row in pays) {
        if (!_incomingPayment(row) || !_successfulPayment(row)) continue;
        if (matches != null && !matches(paymentWhen(row))) continue;
        n++;
      }
      return n;
    }
    return invoices.where((i) {
      if (!i.isPaid) return false;
      if (matches == null) return true;
      return matches(parseFlexibleDate(i.date));
    }).length;
  }

  double feesOutstanding() {
    final bills = tables['bills'] ?? const <Map<String, dynamic>>[];
    if (bills.isNotEmpty) {
      var sum = 0.0;
      for (final bill in bills) {
        final status = _asString(bill['status']).toLowerCase();
        if (status == 'paid' || status == 'cancelled') continue;
        sum += _moneyOf(bill['balance'] ?? bill['total_amount'] ?? bill['amount']);
      }
      return sum;
    }
    return invoices.where((i) => !i.isPaid).fold<double>(0, (sum, i) => sum + i.dueAmount);
  }

  int unpaidBillCount() {
    final bills = tables['bills'] ?? const <Map<String, dynamic>>[];
    if (bills.isNotEmpty) {
      return bills.where((bill) {
        final status = _asString(bill['status']).toLowerCase();
        return status != 'paid' && status != 'cancelled';
      }).length;
    }
    return invoices.where((i) => !i.isPaid).length;
  }

  List<Map<String, dynamic>> recentFeePayments({int limit = 5, String? studentId}) {
    return [
      for (final row in paymentRecords)
        if (_incomingPayment(row) && (studentId == null || '${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}' == studentId))
          row,
    ].take(limit).toList();
  }

  double feesCollectedForStudent(String studentId) {
    if (studentId.isEmpty) return 0;
    final pays = paymentRecords;
    if (pays.isNotEmpty) {
      var sum = 0.0;
      for (final row in pays) {
        final id = '${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}';
        if (id != studentId || !_incomingPayment(row) || !_successfulPayment(row)) continue;
        sum += _moneyOf(row['amount']);
      }
      return sum;
    }
    return invoices.where((i) => i.isPaid && (i.studentId == studentId || i.student.isNotEmpty)).fold<double>(0, (s, i) {
      if (i.studentId == studentId) return s + i.amount;
      return s;
    });
  }

  List<ReportLine> draftReportLines(String klass) {
    final roll = students.where((s) => s.klass == klass).toList();
    final subjects = reportSubjectTemplates;
    return [
      for (var i = 0; i < roll.length; i++)
        ReportLine(
          studentId: roll[i].id,
          student: roll[i].name,
          bill: billLabelFor(roll[i].name),
          position: '${i + 1}',
          attendanceOutOf: '',
          attendanceMade: '',
          subjects: [
            for (final subject in subjects)
              ReportSubjectMark(subject: subject.subject, subjectId: subject.subjectId),
          ],
        ),
    ];
  }

  void upsertAcademicReport(AcademicReport report, {bool isNew = false}) {
    if (isNew || report.id.isEmpty) {
      report.id = 'ar${DateTime.now().millisecondsSinceEpoch}';
      academicReports.insert(0, report);
    } else {
      final i = academicReports.indexWhere((r) => r.id == report.id);
      if (i >= 0) {
        academicReports[i] = report;
      } else {
        academicReports.insert(0, report);
      }
    }
    _notifyAfterFrame();
  }

  void _notifyAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  List<AcademicReport> academicReportsFor(Role role, {String? childName}) {
    return academicReports.where((report) {
      if (role == Role.parent) {
        if (!report.sentToParent) return false;
        if (childName == null || childName.isEmpty) return true;
        return report.lines.any((line) => line.student == childName);
      }
      if (role.isAdminPortal) return report.sentToAdmin;
      return true;
    }).toList();
  }

  Future<String> sendAcademicReportToAdmin(AcademicReport report, {required String from}) async {
    if (ApiSession.instance.isSignedIn) {
      final error = await _persistAcademicReport(report);
      if (error.isNotEmpty) return error;
    }
    report.status = 'sent_to_admin';
    report.submittedAt = _clock();
    upsertAcademicReport(report);
    return '';
  }

  Future<String> _persistAcademicReport(AcademicReport report) async {
    final termId = report.termId.isNotEmpty ? report.termId : (termIdFor(report.term) ?? academicTermId ?? '');
    if (termId.isEmpty || !_isUuid(termId)) {
      return 'No academic term from the school API. Set the current term in the office web app.';
    }
    final templates = reportSubjectTemplates;
    for (final line in report.lines) {
      if (!_isUuid(line.studentId)) continue;
      line.ensureReportSubjects(templates);
      final subjectLines = [
        for (final mark in line.subjects)
          if (_isUuid(mark.subjectId))
            {
              'subject_id': mark.subjectId,
              // Blank lets the server fill it from the subject teachers' latest marks.
              'class_score': mark.classScore == 0 ? null : mark.classScore,
              'exam_score': mark.examScore,
              'score': mark.total,
              if (mark.grade.isNotEmpty && mark.grade != '—') 'grade': mark.grade,
              if (mark.remark.isNotEmpty) 'remark': mark.remark,
            },
      ];
      if (subjectLines.isEmpty) {
        return 'This school has no subjects yet. Add subjects in the office web app, then try again.';
      }
      final body = <String, dynamic>{
        'student_id': line.studentId,
        'academic_term_id': termId,
        if (line.remark.isNotEmpty) 'teacher_remark': line.remark,
        if (line.headteacherRemark.isNotEmpty) 'headteacher_remark': line.headteacherRemark,
        if (line.promotedTo.isNotEmpty)
          'promotion_status': line.promotedTo
        else if (line.promote == true)
          'promotion_status': 'promoted',
        'lines': subjectLines,
      };
      try {
        final response = line.cardId.isNotEmpty && _isUuid(line.cardId)
            ? await ApiClient.instance.put('/report-cards/${line.cardId}', body)
            : await ApiClient.instance.post('/report-cards', body);
        final id = _resourceId(response);
        if (id != null) line.cardId = id;
      } on ApiException catch (error) {
        return error.message;
      }
    }
    return '';
  }

  bool _isUuid(String value) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(value.trim());
  }

  /// Demo / offline thread ids (`pm-2`, `local-…`, `m-1`) are not API UUIDs.
  bool _isApiThreadId(String threadId) {
    var id = threadId.trim();
    if (id.isEmpty) return false;
    for (final suffix in const ['-inbox', '-staff', '-parents', '-teachers', '-sent']) {
      if (id.endsWith(suffix)) {
        id = id.substring(0, id.length - suffix.length);
        break;
      }
    }
    return _isUuid(id);
  }

  String? resolveStudentUuid(String idOrName) {
    final raw = idOrName.trim();
    if (raw.isNotEmpty && _isUuid(raw)) return raw;
    for (final s in students) {
      if ((raw.isEmpty || s.id == raw || s.name == raw) && _isUuid(s.id)) return s.id;
    }
    for (final row in tableRows('students')) {
      final id = '${row['id'] ?? ''}'.trim();
      final name = _asString(row['full_name']);
      if ((raw.isEmpty || id == raw || name == raw) && _isUuid(id)) return id;
    }
    return null;
  }

  /// Prefer a real API UUID for [idOrName] (id or class label).
  String? resolveClassUuid(String idOrName) {
    final raw = idOrName.trim();
    if (raw.isEmpty) return null;
    if (_isUuid(raw)) return raw;
    for (final c in classes) {
      if ((c.id == raw || c.name == raw) && _isUuid(c.id)) return c.id;
    }
    for (final row in tableRows('school_classes')) {
      final id = '${row['id'] ?? ''}'.trim();
      final name = _classLabel(row);
      if ((id == raw || name == raw) && _isUuid(id)) return id;
    }
    return null;
  }

  String? resolveSubjectUuid(String idOrName) {
    final raw = idOrName.trim();
    if (raw.isEmpty) return null;
    if (_isUuid(raw)) return raw;
    for (final s in subjectRecords) {
      if ((s.id == raw || s.name == raw) && _isUuid(s.id)) return s.id;
    }
    for (final row in tableRows('subjects')) {
      final id = '${row['id'] ?? ''}'.trim();
      final name = _asString(row['name']);
      if ((id == raw || name == raw) && _isUuid(id)) return id;
    }
    return null;
  }

  String classDisplayName(String idOrName) {
    final raw = idOrName.trim();
    for (final c in classes) {
      if (c.id == raw || c.name == raw) return c.name;
    }
    for (final row in tableRows('school_classes')) {
      final id = '${row['id'] ?? ''}'.trim();
      final name = _classLabel(row);
      if (id == raw || name == raw) return name;
    }
    return raw.isEmpty ? 'Class' : raw;
  }

  String subjectDisplayName(String idOrName) {
    final raw = idOrName.trim();
    for (final s in subjectRecords) {
      if (s.id == raw || s.name == raw) return s.name;
    }
    for (final row in tableRows('subjects')) {
      final id = '${row['id'] ?? ''}'.trim();
      final name = _asString(row['name']);
      if (id == raw || name == raw) return name;
    }
    return raw.isEmpty ? 'Subject' : raw;
  }

  String? _resourceId(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'];
    if (data is Map && data['id'] != null) return '${data['id']}';
    if (response['id'] != null) return '${response['id']}';
    return null;
  }

  Future<String> sendAcademicReportToParents(AcademicReport report) async {
    if (ApiSession.instance.isSignedIn) {
      final ids = [
        for (final line in report.lines)
          if (line.cardId.isNotEmpty) line.cardId,
      ];
      for (final id in ids) {
        try {
          await ApiClient.instance.post('/report-cards/$id/submit');
        } on ApiException catch (error) {
          if (ids.length == 1) return error.message;
        }
      }
    }
    report.status = 'sent_to_parent';
    for (final line in report.lines) {
      line.published = true;
    }
    upsertAcademicReport(report);
    return '';
  }

  String _selfViewerId(Role role) {
    final id = (sessionUserId ?? '').trim();
    return id.isNotEmpty ? id : 'local-${role.name}';
  }

  String _peerViewerId(String participantUserId, String participantRole) {
    final mine = (sessionUserId ?? '').trim();
    final peer = participantUserId.trim();
    if (mine.isNotEmpty && peer.isNotEmpty) return peer;
    return 'local-${_inboxRolesFor(participantRole, Role.parent).first.name}';
  }

  bool _messageVisibleTo(ChatPreview m, Role role) {
    if (m.isAnnouncement) {
      return role == Role.parent || role == Role.teacher || role.isAdminPortal;
    }
    if (m.viewerUserId.isNotEmpty) {
      return m.viewerUserId == _selfViewerId(role);
    }
    if (m.audience.isEmpty) return false;
    if (m.audience.contains(role)) return true;
    if (role.isAdminPortal && m.audience.any((r) => r.isAdminPortal)) return true;
    return false;
  }

  List<ChatPreview> messagesFor(Role role) {
    final list = [for (final m in messages) if (_messageVisibleTo(m, role)) m];
    list.sort((a, b) {
      if (a.unread != b.unread) return a.unread ? -1 : 1;
      return b.time.compareTo(a.time);
    });
    return list;
  }

  int unreadMessageCountFor(Role role) =>
      messagesFor(role).where((m) => m.unread && m.sentByRole != role).length;

  String get _readViewerKey {
    final uid = (sessionUserId ?? '').trim();
    if (uid.isNotEmpty) return 'u:$uid';
    final email = (_activeEmail ?? '').trim().toLowerCase();
    if (email.isNotEmpty) return 'e:$email';
    final role = _activeRole?.name;
    if (role != null && role.isNotEmpty) return 'r:$role';
    return 'local';
  }

  Future<void> _hydrateReadReceipts() async {
    await MessageReadPrefs.instance.load(_readViewerKey);
  }

  void _applyPersistedReads() {
    final receipts = MessageReadPrefs.instance;
    var changed = false;
    for (final m in messages) {
      if (!receipts.isRead([m.id, m.threadId], m.preview)) continue;
      if (!m.unread && m.unreadCount == 0) continue;
      m.unread = false;
      m.unreadCount = 0;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> _rememberThreadRead({
    required Iterable<String> keys,
    required String preview,
  }) async {
    await _hydrateReadReceipts();
    MessageReadPrefs.instance.remember(keys, preview);
    await MessageReadPrefs.instance.save();
  }

  void _syncThreadReadOnServer(String threadId) {
    if (!ApiSession.instance.isSignedIn || !_isApiThreadId(threadId)) return;
    var id = threadId.trim();
    for (final suffix in const ['-inbox', '-staff', '-parents', '-teachers', '-sent']) {
      if (id.endsWith(suffix)) {
        id = id.substring(0, id.length - suffix.length);
        break;
      }
    }
    unawaited(ApiClient.instance.get('/message-threads/$id').then((_) {}, onError: (_) {}));
  }

  Future<void> markMessageRead(String id) async {
    var changed = false;
    String? threadId;
    var preview = '';
    final keys = <String>{id};
    for (final m in messages) {
      if (m.id == id || m.threadId == id) {
        threadId = m.threadId.isNotEmpty ? m.threadId : m.id;
        preview = m.preview;
        break;
      }
    }
    for (final m in messages) {
      final same = m.id == id ||
          m.threadId == id ||
          (threadId != null && (m.threadId == threadId || m.id == threadId || m.id.startsWith('$threadId-')));
      if (!same) continue;
      keys.add(m.id);
      if (m.threadId.isNotEmpty) keys.add(m.threadId);
      if (preview.isEmpty) preview = m.preview;
      if (!m.unread && m.unreadCount == 0) continue;
      m.unread = false;
      m.unreadCount = 0;
      changed = true;
    }
    if (threadId != null) keys.add(threadId);
    await _rememberThreadRead(keys: keys, preview: preview);
    _syncThreadReadOnServer(threadId ?? id);
    if (changed) notifyListeners();
  }

  String sendSchoolMessage({
    required String from,
    required Role fromRole,
    required String body,
    required bool announcement,
    bool toParents = false,
    bool toTeachers = false,
    List<String> parentNames = const [],
  }) {
    final text = body.trim();
    if (text.isEmpty) return 'Write a message first.';
    if (!announcement) {
      return 'Individual messages stay private. Use a direct chat, not a school-wide post.';
    }
    if (!fromRole.isAdminPortal) {
      return 'Only school admin can post an announcement.';
    }
    final allParents = toParents && parentNames.isEmpty;
    final namedParents = parentNames.where((n) => n.trim().isNotEmpty).toList();
    if (!toTeachers && !allParents && namedParents.isEmpty) {
      return fromRole == Role.teacher
          ? 'Select parents to message.'
          : 'Select parents, teachers, or both.';
    }

    final time = _clock();
    final kind = announcement ? 'announcement' : 'message';
    final targets = <String>[
      if (toTeachers) 'all teachers',
      if (allParents) 'all parents',
      if (namedParents.isNotEmpty) namedParents.length == 1 ? namedParents.first : '${namedParents.length} parents',
    ];
    final toLabel = targets.join(' and ');
    final id = 'msg-${DateTime.now().millisecondsSinceEpoch}';
    final lines = [
      ChatLine(from: from, body: text, time: time, role: fromRole),
    ];

    messages.insert(
      0,
      ChatPreview(
        id: '$id-sent',
        threadId: id,
        from: announcement ? 'Announcement sent' : 'Message sent',
        role: 'To $toLabel',
        time: time,
        preview: text,
        unread: false,
        avatar: from,
        kind: kind,
        toLabel: toLabel,
        audience: [fromRole],
        sentByRole: fromRole,
        lines: lines,
      ),
    );

    if (toTeachers) {
      messages.insert(
        0,
        ChatPreview(
          id: '$id-teachers',
          threadId: id,
          from: from,
          role: announcement ? 'School announcement' : '${fromRole.label} · all teachers',
          time: time,
          preview: text,
          unread: true,
          unreadCount: 1,
          avatar: from,
          kind: kind,
          toLabel: 'Teachers',
          audience: const [Role.teacher],
          sentByRole: fromRole,
          lines: lines,
        ),
      );
    }

    if (allParents || namedParents.isNotEmpty) {
      final parentLabel = allParents
          ? 'all parents'
          : (namedParents.length == 1 ? namedParents.first : '${namedParents.length} parents');
      messages.insert(
        0,
        ChatPreview(
          id: '$id-parents',
          threadId: id,
          from: from,
          role: announcement ? 'School announcement' : '${fromRole.label} · $parentLabel',
          time: time,
          preview: text,
          unread: true,
          unreadCount: 1,
          avatar: from,
          kind: kind,
          toLabel: parentLabel,
          audience: const [Role.parent],
          sentByRole: fromRole,
          lines: lines,
        ),
      );
    }

    notifyListeners();
    return '';
  }

  Future<String> sendThreadReply({
    required String threadId,
    required String from,
    required Role fromRole,
    required String body,
  }) async {
    try {
    final text = body.trim();
    if (text.isEmpty) return 'Write a message first.';
    final copies = [
      for (final m in messages)
        if (m.threadId == threadId || m.id == threadId) m,
    ];
    if (copies.isEmpty) return 'Conversation not found.';

    final time = _clock();
    final line = ChatLine(
      id: 'line-${DateTime.now().millisecondsSinceEpoch}',
      senderId: sessionUserId ?? 'local-me',
      from: from,
      body: text,
      time: time,
      role: fromRole,
    );
    final seen = <List<ChatLine>>{};
    for (final m in copies) {
      if (seen.add(m.lines)) m.lines.add(line);
      m.preview = text;
      m.time = time;
      final forSenderOnly = m.audience.length == 1 && m.audience.contains(fromRole);
      if (forSenderOnly) {
        m.unread = false;
        m.unreadCount = 0;
      } else if (!m.audience.contains(fromRole)) {
        m.unread = true;
        m.unreadCount += 1;
      } else {
        m.unread = false;
      }
    }

    if (copies.first.isAnnouncement) {
    }
    notifyListeners();

    // Was previously `unawaited(...)` with a fully-silent catch below — the
    // local copy above always looked "sent" even when the office API
    // rejected it (expired session, no longer a thread participant, etc.),
    // so a reply could silently never reach the other side. Mirrors
    // startDirectMessage's error handling: a real ApiException (the API was
    // reached and explicitly refused it) is reported back to the sender;
    // a genuine network blip stays silent so sending isn't blocked offline.
    final error = await _pushReplyToApi(copies.first, threadId, text);
    if (error.isNotEmpty) {
      // Not on the server, so not sent: take the line back out of the chat.
      for (final lines in seen) {
        lines.remove(line);
      }
      notifyListeners();
    }
    return error;
    } catch (_) {
      return 'Could not send the message.';
    }
  }

  Future<String> _pushReplyToApi(ChatPreview thread, String threadId, String text) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in to send messages.';
    try {
      if (thread.isAnnouncement) {
        var announcementId = thread.id.startsWith('ann-') ? thread.id.substring(4) : thread.threadId;
        if (announcementId.startsWith('ann-')) announcementId = announcementId.substring(4);
        if (!_isUuid(announcementId)) return 'This announcement is not on the school server.';
        await ApiClient.instance.post('/announcements/$announcementId/replies', {'body': text});
        return '';
      }
      if (!_isApiThreadId(threadId)) return 'This conversation is not on the school server.';
      await ApiClient.instance.post('/message-threads/$threadId/messages', {'body': text});
      return '';
    } on ApiException catch (e) {
      return e.status == null ? 'Could not reach the school server. The message was not sent.' : e.message;
    } catch (_) {
      return 'Could not reach the school server. The message was not sent.';
    }
  }

  String? get sessionStaffId {
    final staff = ApiSession.instance.user?['staff'];
    return staff is Map ? staff['id']?.toString() : null;
  }

  String? get sessionGuardianId {
    final guardian = ApiSession.instance.user?['guardian'];
    return guardian is Map ? guardian['id']?.toString() : null;
  }

  List<Map<String, dynamic>> tableRows(String key) => tables[key] ?? const <Map<String, dynamic>>[];

  List<NamedRecord> get subjectRecords => [
        for (final row in tableRows('subjects'))
          NamedRecord(id: '${row['id']}', name: _asString(row['name'])),
      ];

  Future<String> postToApi(String path, [Map<String, dynamic>? body]) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in through the school API first.';
    try {
      await ApiClient.instance.post(path, body);
      await syncFromApi();
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not save to the school API.';
    }
  }

  /// Homework, assignments and exercises (the backend's assignment `type`).
  static const assignmentTypes = {'homework': 'Homework', 'assignment': 'Assignment', 'exercise': 'Exercise'};

  /// Saves on the school server only — a failure is an error, never a
  /// phone-only copy.
  Future<String> createAssignment({
    required String classId,
    required String subjectId,
    required String title,
    String instructions = '',
    String? deadline,
    String type = 'homework',
  }) async {
    final heading = title.trim().isEmpty ? (assignmentTypes[type] ?? 'Homework') : title.trim();
    final notes = instructions.trim();
    final classUuid = resolveClassUuid(classId);
    final subjectUuid = resolveSubjectUuid(subjectId);
    final teacherId = sessionStaffId;
    if (!ApiSession.instance.isSignedIn) return 'Sign in to set homework.';
    if (teacherId == null || !_isUuid(teacherId)) return 'Only a signed-in teacher can set homework.';
    if (classUuid == null || subjectUuid == null) return 'Choose a class and subject from the school records.';
    try {
      await ApiClient.instance.post('/assignments', {
        'class_id': classUuid,
        'subject_id': subjectUuid,
        'teacher_id': teacherId,
        'title': heading,
        'type': type,
        if (notes.isNotEmpty) 'instructions': notes,
        if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
        'published_date': DateTime.now().toIso8601String().split('T').first,
      });
      await syncFromApi(budget: const Duration(seconds: 20));
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not reach the school server. Nothing was saved.';
    }
  }

  Future<String> updateAssignment({
    required String id,
    required String classId,
    required String subjectId,
    required String title,
    String instructions = '',
    String? deadline,
    String type = 'homework',
  }) async {
    final teacherId = sessionStaffId;
    if (!ApiSession.instance.isSignedIn) return 'Sign in to update homework.';
    if (teacherId == null || !_isUuid(teacherId)) return 'Only a signed-in teacher can update homework.';
    final classUuid = resolveClassUuid(classId);
    final subjectUuid = resolveSubjectUuid(subjectId);
    if (classUuid == null || subjectUuid == null || !_isUuid(id)) return 'Choose a class and subject from the school records.';
    try {
      await ApiClient.instance.put('/assignments/$id', {
        'class_id': classUuid,
        'subject_id': subjectUuid,
        'teacher_id': teacherId,
        'title': title,
        'type': type,
        'instructions': instructions,
        if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
      });
      await syncFromApi(budget: const Duration(seconds: 20));
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not update the assignment.';
    }
  }

  Future<String> deleteAssignment(String id) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in through the school API first.';
    try {
      await ApiClient.instance.delete('/assignments/$id');
      await syncFromApi();
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not delete the assignment.';
    }
  }

  String? get sessionUserId => ApiSession.instance.user?['id']?.toString();

  Future<String> startDirectMessage({
    required String studentId,
    required String participantUserId,
    required String body,
    String? participantName,
    String? participantRole,
    String? fromName,
    Role? fromRole,
  }) async {
    try {
      final text = body.trim();
      if (text.isEmpty) return 'Write a message first.';
    var sid = studentId.trim();
    if (sid.isEmpty) {
      sid = students.firstOrNull?.id ?? '';
      if (sid.isEmpty) {
        for (final row in tableRows('students')) {
          final id = '${row['id'] ?? ''}';
          if (id.isNotEmpty) {
            sid = id;
            break;
          }
        }
      }
    }
    if (sid.isEmpty) return 'Choose which student this is about.';
    final participant = participantUserId.trim();
    if (participant.isEmpty) return 'Choose who to send this to.';
    final studentUuid = resolveStudentUuid(sid) ?? sid;

    final role = fromRole ?? Role.parent;
    final sender = (fromName ?? '').trim().isNotEmpty
        ? fromName!.trim()
        : (ApiSession.instance.user?['email']?.toString() ?? 'You');
    final otherName = (participantName ?? '').trim().isNotEmpty ? participantName!.trim() : 'Chat';
    final otherRole = (participantRole ?? '').trim().isNotEmpty ? participantRole!.trim() : 'Staff';

    // Messages only ever live on the school server: it is shown in the
    // conversation list once the server has accepted it, and a failure is
    // reported as "not sent" — never kept as a phone-only copy that looks
    // sent but never reached the other person.
    if (!ApiSession.instance.isSignedIn) return 'Sign in to send messages.';
    if (!_isUuid(studentUuid) || !_isUuid(participant)) {
      return 'This person cannot be messaged yet — they have no account on the school server.';
    }

    try {
      final response = await ApiClient.instance.post(
        '/message-threads',
        {
          'student_id': studentUuid,
          'participant_user_id': participant,
          'body': text,
        },
        const Duration(seconds: 20),
      );
      final threadId = _threadIdFromResponse(response);
      _upsertLocalDirectThread(
        threadId: threadId,
        studentId: studentUuid,
        participantUserId: participant,
        participantName: otherName,
        participantRole: otherRole,
        fromName: sender,
        fromRole: role,
        body: text,
      );
      unawaited(refreshNoticesAndAttendance());
      return '';
    } on ApiException catch (e) {
      // No status: the server was never reached. Otherwise it refused it
      // (e.g. this guardian isn't linked to that student). Either way the
      // recipient never got it.
      return e.status == null ? 'Could not reach the school server. The message was not sent.' : e.message;
    } catch (_) {
      return 'Could not reach the school server. The message was not sent.';
    }
    } catch (_) {
      return 'Could not send the message.';
    }
  }

  String? _threadIdFromResponse(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'];
    if (data is Map && data['id'] != null) return '${data['id']}';
    if (response['id'] != null) return '${response['id']}';
    return null;
  }

  void _upsertLocalDirectThread({
    required String? threadId,
    required String studentId,
    required String participantUserId,
    required String participantName,
    required String participantRole,
    required String fromName,
    required Role fromRole,
    required String body,
  }) {
    final id = (threadId == null || threadId.isEmpty)
        ? 'local-$participantUserId-$studentId'
        : threadId;
    final time = _clock();
    final me = sessionUserId ?? 'local-me';
    final line = ChatLine(
      id: 'line-${DateTime.now().millisecondsSinceEpoch}',
      senderId: me,
      from: fromName,
      body: body,
      time: time,
      role: fromRole,
    );

    final existing = [
      for (final m in messages)
        if (m.threadId == id || m.id == id || m.id.startsWith('$id-')) m,
    ];
    if (existing.isNotEmpty) {
      final seenLines = <List<ChatLine>>{};
      for (final m in existing) {
        if (seenLines.add(m.lines)) m.lines.add(line);
        m.preview = body;
        m.time = time;
        if (m.audience.contains(fromRole) && m.audience.length == 1) {
          m.unread = false;
          m.unreadCount = 0;
        } else if (!m.audience.contains(fromRole)) {
          m.unread = true;
          m.unreadCount += 1;
        } else {
          m.unread = false;
        }
      }
      notifyListeners();
      return;
    }

    final senderAudience = <Role>[fromRole];
    final recipientAudience = _inboxRolesFor(participantRole, fromRole);
    final senderViewer = _selfViewerId(fromRole);
    final peerViewer = _peerViewerId(participantUserId, participantRole);

    // Sender's chat list (shows the other person).
    messages.insert(
      0,
      ChatPreview(
        id: id,
        threadId: id,
        from: participantName,
        role: participantRole,
        time: time,
        preview: body,
        unread: false,
        avatar: participantName,
        audience: senderAudience,
        sentByRole: fromRole,
        viewerUserId: senderViewer,
        lines: [line],
      ),
    );
    // Recipient inbox (shows the sender, unread).
    messages.insert(
      0,
      ChatPreview(
        id: '$id-inbox',
        threadId: id,
        from: fromName,
        role: fromRole.label,
        time: time,
        preview: body,
        unread: true,
        unreadCount: 1,
        avatar: fromName,
        audience: recipientAudience,
        sentByRole: fromRole,
        viewerUserId: peerViewer,
        lines: [line],
      ),
    );
    notifyListeners();
  }

  List<Role> _inboxRolesFor(String participantRole, Role fromRole) {
    final pr = participantRole.toLowerCase();
    if (pr.contains('admin') || pr.contains('deputy') || pr.contains('registrar')) {
      return const [Role.admin, Role.schoolAdmin];
    }
    if (pr.contains('teacher') || pr.contains('staff') || pr.contains('bursar')) {
      return const [Role.teacher];
    }
    // Student accounts are not a portal role here — route to parents so a guardian can reply.
    if (pr.contains('student')) {
      return const [Role.parent];
    }
    // Parent picker details look like "Ama Mensah · Grade 3A", or "Mother".
    return const [Role.parent];
  }

  /// Sends the same message to each selected staff/parent user (1:1 threads).
  Future<String> startDirectMessages({
    required String studentId,
    required List<String> participantUserIds,
    required String body,
    Map<String, String> participantNames = const {},
    Map<String, String> participantRoles = const {},
    String? fromName,
    Role? fromRole,
  }) async {
    final ids = {
      for (final id in participantUserIds)
        if (id.trim().isNotEmpty) id.trim(),
    }.toList();
    if (ids.isEmpty) return 'Choose who to send this to.';
    String? lastError;
    var sent = 0;
    return runNotifyBatch(() async {
    for (final id in ids) {
      final err = await startDirectMessage(
        studentId: studentId,
        participantUserId: id,
        body: body,
        participantName: participantNames[id],
        participantRole: participantRoles[id],
        fromName: fromName,
        fromRole: fromRole,
      );
      if (err.isEmpty) {
        sent += 1;
      } else {
        lastError = err;
      }
    }
    if (sent == 0) return lastError ?? 'Could not send the message.';
    if (sent < ids.length) return 'Sent to $sent of ${ids.length}. ${lastError ?? ''}';
    return '';
    });
  }

  Future<String> sendGroupNotice({
    required String title,
    required String body,
    required String audience,
    String? classId,
    Role? fromRole,
    bool allowReplies = true,
  }) async {
    final poster = fromRole ?? Role.schoolAdmin;
    if (!poster.isAdminPortal) {
      return 'Only school admin can post an announcement. Teachers and parents use private messages.';
    }
    final text = body.trim();
    if (text.isEmpty) return 'Write a message first.';
    final heading = title.trim().isEmpty ? 'School message' : title.trim();
    final resolvedClass = classId == null || classId.isEmpty ? null : resolveClassUuid(classId);

    if (!ApiSession.instance.isSignedIn ||
        (audience == 'single_class' && (resolvedClass == null || !_isUuid(resolvedClass)))) {
      return sendSchoolMessage(
        from: 'School',
        fromRole: poster,
        body: audience == 'single_class'
            ? '$heading\n${classDisplayName(classId ?? '')}\n$text'
            : (heading == 'School message' ? text : '$heading\n$text'),
        announcement: true,
        toParents: audience == 'all' || audience == 'parents' || audience == 'single_class',
        toTeachers: audience == 'all' || audience == 'teachers',
      );
    }
    try {
      await ApiClient.instance.post(
        '/announcements',
        {
          'title': heading,
          'body': text,
          'audience': audience,
          if (resolvedClass != null) 'class_id': resolvedClass,
          'allow_replies': allowReplies,
        },
        const Duration(seconds: 3),
      );
      unawaited(syncFromApi());
      return '';
    } catch (_) {
      return sendSchoolMessage(
        from: 'School',
        fromRole: poster,
        body: heading == 'School message' ? text : '$heading\n$text',
        announcement: true,
        toParents: audience == 'all' || audience == 'parents' || audience == 'single_class',
        toTeachers: audience == 'all' || audience == 'teachers',
      );
    }
  }

  Future<String> updateChatMessage({
    required String threadId,
    required String messageId,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return 'Write a message first.';
    void applyLocal() {
      for (final thread in messages) {
        if (thread.id != threadId && thread.threadId != threadId) continue;
        for (final line in thread.lines) {
          if (line.id == messageId) {
            line.body = text;
            line.edited = true;
          }
        }
        if (thread.lines.isNotEmpty) thread.preview = thread.lines.last.body;
      }
      notifyListeners();
    }

    if (!ApiSession.instance.isSignedIn || !_isApiThreadId(threadId)) {
      applyLocal();
      return '';
    }
    try {
      await ApiClient.instance.put('/message-threads/$threadId/messages/$messageId', {'body': text});
      await loadThreadMessages(threadId);
      return '';
    } on ApiException catch (error) {
      final msg = error.message.toLowerCase();
      if (msg.contains('no query results') || msg.contains('not found')) {
        applyLocal();
        return '';
      }
      return error.message;
    } catch (_) {
      applyLocal();
      return '';
    }
  }

  Future<String> deleteChatMessage({
    required String threadId,
    required String messageId,
  }) async {
    void applyLocal() {
      for (final thread in messages) {
        if (thread.id != threadId && thread.threadId != threadId) continue;
        thread.lines.removeWhere((line) => line.id == messageId);
        if (thread.lines.isNotEmpty) thread.preview = thread.lines.last.body;
      }
      notifyListeners();
    }

    if (!ApiSession.instance.isSignedIn || !_isApiThreadId(threadId)) {
      applyLocal();
      return '';
    }
    try {
      await ApiClient.instance.delete('/message-threads/$threadId/messages/$messageId');
      await loadThreadMessages(threadId);
      return '';
    } on ApiException catch (error) {
      final msg = error.message.toLowerCase();
      if (msg.contains('no query results') || msg.contains('not found')) {
        applyLocal();
        return '';
      }
      return error.message;
    } catch (_) {
      applyLocal();
      return '';
    }
  }

  Future<String> requestHomeStudy({
    required String studentId,
    required String teacherStaffId,
    String? subjectId,
    String purpose = '',
    String notes = '',
  }) {
    return postToApi('/home-study-engagements', {
      'student_id': studentId,
      'teacher_staff_id': teacherStaffId,
      if (sessionGuardianId != null) 'guardian_id': sessionGuardianId,
      if (subjectId != null && subjectId.isNotEmpty) 'subject_id': subjectId,
      if (purpose.isNotEmpty) 'purpose': purpose,
      if (notes.isNotEmpty) 'notes': notes,
    });
  }

  Future<String> decideHomeStudy(String id, {required bool approve, String notes = ''}) {
    return postToApi('/home-study-engagements/$id/${approve ? 'approve' : 'reject'}', {
      if (notes.isNotEmpty) 'decision_notes': notes,
    });
  }

  Future<String> requestLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    String reason = '',
  }) {
    final staffId = sessionStaffId;
    if (staffId == null || staffId.isEmpty) return Future.value('Only staff can request leave.');
    return postToApi('/leave-requests', {
      'staff_id': staffId,
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      if (reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<String> decideLeave(String id, {required bool approve, String notes = ''}) {
    return postToApi('/leave-requests/$id/${approve ? 'approve' : 'reject'}', {
      'status': approve ? 'approved' : 'rejected',
      if (notes.isNotEmpty) 'decision_note': notes,
    });
  }

  void markNoticeRead(String id) {
    var changed = false;
    if (_homeworkNotices.containsKey(id) || _staffClockNotices.containsKey(id)) _rememberLocalRead([id]);
    for (final n in [...notifications, ..._arrivalNotices.values, ..._paymentNotices.values, ..._homeworkNotices.values, ..._staffClockNotices.values]) {
      if (n.id == id && n.unread) {
        n.unread = false;
        changed = true;
        break;
      }
    }
    if (!changed) return;
    notifyListeners();
    if (ApiSession.instance.isSignedIn && _apiNotificationIds.contains(id)) {
      unawaited(ApiClient.instance.post('/notifications/$id/read').then((_) {}, onError: (_) {}));
    }
  }

  Future<String> markAllNoticesRead() async {
    _rememberLocalRead([..._homeworkNotices.keys, ..._staffClockNotices.keys]);
    for (final n in [...notifications, ..._arrivalNotices.values, ..._paymentNotices.values, ..._homeworkNotices.values, ..._staffClockNotices.values]) {
      n.unread = false;
    }
    notifyListeners();
    if (!ApiSession.instance.isSignedIn) return '';
    try {
      await ApiClient.instance.post('/notifications/read-all');
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not sync read state with the school API.';
    }
  }

  // ---------------------------------------------------------------
  // Palm-scan attendance for teachers. Scanner hardware posts every palm
  // scan to the API: a day student's scan records their attendance (and the
  // API notifies the parents), a boarder's scan is ignored (the class
  // teacher marks boarders by hand), and a teacher's own scan records the
  // teacher's attendance. The API doesn't notify teachers, so the app turns
  // today's scans into notices here.
  // ---------------------------------------------------------------

  /// The signed-in teacher's own record for today (palm scan), or null when
  /// they haven't scanned yet / it hasn't loaded.
  Map<String, dynamic>? myAttendanceToday;

  /// Today's student attendance rows the API lets this teacher see.
  List<Map<String, dynamic>> studentAttendanceToday = const [];
  DateTime? teacherTodayLoadedAt;
  bool _teacherTodayLoading = false;

  /// Keyed by id so a notice keeps its read state across refreshes.
  final Map<String, AppNotification> _arrivalNotices = {};
  String _arrivalNoticesDay = '';

  /// Today's staff attendance rows (palm clock-ins/outs or marked by the
  /// office), newest scan first. Filled by the 30-second live refresh, which
  /// reads `/attendance?date=today` for admins — staff rows included.
  List<Map<String, dynamic>> staffAttendanceToday() {
    final today = _today();
    final rows = [
      for (final row in tables['attendance'] ?? const <Map<String, dynamic>>[])
        if ('${row['date'] ?? ''}'.startsWith(today) &&
            (_asString(row['staff_id']).isNotEmpty || _asString(row['person_type']) == 'staff'))
          row,
    ];
    String last(Map<String, dynamic> r) => _asString(r['check_out_at']).isNotEmpty ? _asString(r['check_out_at']) : _asString(r['check_in_at']);
    rows.sort((a, b) => last(b).compareTo(last(a)));
    return rows;
  }

  /// Name for a staff attendance row: the row's own staff, else the directory.
  String staffNameOf(Map<String, dynamic> row) {
    final staff = row['staff'];
    final name = staff is Map ? _asString(staff['full_name'] ?? staff['name']) : '';
    if (name.isNotEmpty) return name;
    final id = _asString(row['staff_id']);
    for (final t in [...teachers, ...accountants]) {
      if (t.id == id) return t.name;
    }
    return 'Staff member';
  }

  /// "Staff clocked in" notices for admins, one per palm clock-in/out today.
  final Map<String, AppNotification> _staffClockNotices = {};
  String _staffClockDay = '';

  void _rebuildStaffClockNotices() {
    if (_activeRole?.isAdminPortal != true) return;
    final today = _today();
    if (_staffClockDay != today) {
      _staffClockNotices.clear();
      _staffClockDay = today;
    }
    void put(String id, String title, String text, String time, String type) {
      _staffClockNotices[id] = AppNotification(
        id: id,
        type: type,
        title: title,
        text: text,
        time: time,
        icon: type == 'attendance_checked_in' ? 'check' : 'calendar',
        color: 'emerald',
        unread: _staffClockNotices[id]?.unread ?? !(_localRead?.contains(id) ?? false),
      );
    }

    for (final row in staffAttendanceToday()) {
      final name = staffNameOf(row);
      final how = isPalmRecord(row) ? 'by palm scan' : 'by the office';
      if (clockOf(row['check_in_at']).isNotEmpty) {
        final late = '${row['status']}'.toLowerCase() == 'late' ? ' (late)' : '';
        put('staff-in-${row['id']}', '$name clocked in', '$name clocked in at ${clockOf(row['check_in_at'])}$late $how.', '${row['check_in_at']}', 'attendance_checked_in');
      }
      if (clockOf(row['check_out_at']).isNotEmpty) {
        put('staff-out-${row['id']}', '$name clocked out', '$name clocked out at ${clockOf(row['check_out_at'])} $how.', '${row['check_out_at']}', 'attendance_checked_out');
      }
    }
  }

  /// Submits everyone in [people] — (`staff` or `student`, id) with no
  /// attendance record for [date] — as Absent with the note "No palm scan",
  /// through `POST /attendance/manual`, the same call as the website's "Mark
  /// staff". Without `force` the server never overwrites a real palm scan.
  /// One request at a time so a large school isn't rate-limited.
  Future<({int marked, int failed, String error})> markNotScannedAbsent(
    List<(String, String)> people,
    String date, {
    void Function(int done)? onProgress,
  }) async {
    var marked = 0, failed = 0, done = 0;
    var error = '';
    for (final (type, id) in people) {
      try {
        await ApiClient.instance.post(ApiConfig.manualAttendancePath, {
          'person_type': type,
          if (type == 'staff') 'staff_id': id else 'student_id': id,
          'date': date,
          'status': 'absent',
          'note': 'No palm scan',
        });
        marked++;
      } on ApiException catch (e) {
        failed++;
        error = e.message;
      } catch (_) {
        failed++;
        error = 'Could not reach the school server.';
      }
      onProgress?.call(++done);
    }
    if (marked > 0) unawaited(refreshNoticesAndAttendance());
    return (marked: marked, failed: failed, error: error);
  }

  /// Active day students with no attendance record on [date] (palm scan or
  /// marked). Boarders are left out: the class teacher marks them on the
  /// boarding register. Null when today's records could not be read.
  Future<List<Student>?> dayStudentsNotScanned(String date, {String classId = ''}) async {
    final rows = await _tableOrNull('/attendance', query: {
      'date': date,
      'person_type': 'student',
      if (classId.isNotEmpty) 'class_id': classId,
    });
    if (rows == null) return null;
    final seen = {
      for (final r in rows) '${r['student_id'] ?? (r['student'] is Map ? (r['student'] as Map)['id'] : '')}',
    };
    return [
      for (final s in students)
        if (!s.boarder &&
            s.status.toLowerCase() == 'active' &&
            (classId.isEmpty || s.classId == classId) &&
            !seen.contains(s.id))
          s,
    ];
  }

  /// Every staff attendance row for [day] (yyyy-mm-dd), for the admin's
  /// teacher-attendance view; null when the request failed.
  Future<List<Map<String, dynamic>>?> staffAttendanceFor(String day) =>
      _tableOrNull('/attendance', query: {'date': day, 'person_type': 'staff', 'per_page': '500'});

  Future<void> refreshTeacherToday() async {
    if (_activeRole != Role.teacher || !ApiSession.instance.isSignedIn || _teacherTodayLoading) return;
    _teacherTodayLoading = true;
    try {
      final today = _today();
      final results = await Future.wait([
        _tableOrNull(ApiConfig.myAttendancePath, query: {'date': today, 'per_page': '5'}),
        _tableOrNull('/attendance', query: {'date': today, 'person_type': 'student', 'per_page': '500'}),
      ]);
      final mine = results[0];
      if (mine != null) myAttendanceToday = mine.isEmpty ? null : mine.first;
      final kids = results[1];
      if (kids != null) {
        studentAttendanceToday = kids;
        mergeAttendanceRows(kids);
      }
      teacherTodayLoadedAt = DateTime.now();
      _rebuildArrivalNotices();
      notifyListeners();
    } catch (_) {
    } finally {
      _teacherTodayLoading = false;
    }
  }

  /// Today's row for one student (palm or hand-marked), if any.
  Map<String, dynamic>? todayRecordFor(String studentId) {
    for (final row in studentAttendanceToday) {
      final id = '${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}';
      if (id == studentId) return row;
    }
    return null;
  }

  static bool isPalmRecord(Map<String, dynamic>? row) =>
      row != null && '${row['source'] is Map ? (row['source'] as Map)['value'] : row['source']}'.contains('palm');

  /// "07:42" in the phone's local time, '' when missing.
  static String clockOf(dynamic raw) {
    final t = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _rebuildArrivalNotices() {
    final today = _today();
    if (_arrivalNoticesDay != today) {
      _arrivalNotices.clear();
      _arrivalNoticesDay = today;
    }
    void put(String id, String title, String text, String time, String type) {
      final existing = _arrivalNotices[id];
      _arrivalNotices[id] = AppNotification(
        id: id,
        type: type,
        title: title,
        text: text,
        time: time,
        icon: type == 'attendance_checked_in' ? 'check' : 'calendar',
        color: 'emerald',
        unread: existing?.unread ?? true,
      );
    }

    final me = myAttendanceToday;
    if (me != null) {
      final how = isPalmRecord(me) ? 'by palm scan' : 'by the school';
      if (clockOf(me['check_in_at']).isNotEmpty) {
        final late = '${me['status']}'.toLowerCase() == 'late' ? ' (late)' : '';
        put('me-in-${me['id']}', 'You are checked in', 'Checked in at ${clockOf(me['check_in_at'])}$late $how.', '${me['check_in_at']}', 'attendance_checked_in');
      }
      if (clockOf(me['check_out_at']).isNotEmpty) {
        put('me-out-${me['id']}', 'You are checked out', 'Checked out at ${clockOf(me['check_out_at'])} $how.', '${me['check_out_at']}', 'attendance_checked_out');
      }
    }

    final homeroom = {
      for (final k in homeroomClassesFor(AppUser(email: _activeEmail ?? '', displayName: '', role: Role.teacher, subtitle: ''))) k.id,
    };
    if (homeroom.isEmpty) return;
    for (final row in studentAttendanceToday) {
      if (!isPalmRecord(row)) continue;
      final id = '${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}';
      final student = students.where((s) => s.id == id).firstOrNull;
      if (student == null || student.boarder || !homeroom.contains(student.classId)) continue;
      final name = student.name;
      if (clockOf(row['check_in_at']).isNotEmpty) {
        final late = '${row['status']}'.toLowerCase() == 'late' ? ' (late)' : '';
        put('arr-in-${row['id']}', '$name arrived', '$name scanned in at ${clockOf(row['check_in_at'])}$late · ${student.klass}', '${row['check_in_at']}', 'attendance_checked_in');
      }
      if (clockOf(row['check_out_at']).isNotEmpty) {
        put('arr-out-${row['id']}', '$name left school', '$name scanned out at ${clockOf(row['check_out_at'])} · ${student.klass}', '${row['check_out_at']}', 'attendance_checked_out');
      }
    }
  }

  // ---------------------------------------------------------------
  // Homework notices. The API doesn't notify anyone about homework, so the
  // app does: parents see new homework for their child and reminders the day
  // before and on the due date; teachers see the same for work they set.
  // Read state is kept on the phone so a notice doesn't come back unread.
  // ---------------------------------------------------------------

  final Map<String, AppNotification> _homeworkNotices = {};
  Set<String>? _localRead;
  static const _localReadKey = 'e10_local_notices_read';

  void _rememberLocalRead(Iterable<String> ids) {
    final read = _localRead ??= <String>{};
    final added = ids.where(read.add).toList();
    if (added.isEmpty) return;
    unawaited(SharedPreferences.getInstance().then((prefs) {
      // Keep the list small: homework notices only live a few days.
      final list = read.toList();
      prefs.setStringList(_localReadKey, list.length > 400 ? list.sublist(list.length - 400) : list);
    }).catchError((_) {}));
  }

  /// Rebuilds homework notices from the loaded assignments; true when the
  /// set changed.
  Future<bool> rebuildHomeworkNotices() async {
    final role = _activeRole;
    if (role != Role.parent && role != Role.teacher) return false;
    if (_localRead == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _localRead = {...?prefs.getStringList(_localReadKey)};
      } catch (_) {
        _localRead = <String>{};
      }
    }
    final read = _localRead!;
    final before = _homeworkNotices.keys.toSet();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = <String, AppNotification>{};

    for (final row in tableRows('assignments')) {
      if (role == Role.teacher && !isMyClassWork(row)) continue;
      final id = _asString(row['id']);
      if (id.isEmpty) continue;
      final title = _asString(row['title']).isEmpty ? 'Homework' : _asString(row['title']);
      final subject = row['subject'] is Map ? _asString((row['subject'] as Map)['name']) : _asString(row['subject']);
      final klass = row['class'] is Map ? _classLabel(row['class'] as Map) : _asString(row['class_name']);
      final what = subject.isEmpty ? title : '$subject: $title';
      final dueRaw = _asString(row['deadline'] ?? row['due_date']);
      final due = parseFlexibleDate(dueRaw)?.toLocal();
      final dueDay = due == null ? null : DateTime(due.year, due.month, due.day);
      final dueLabel = due == null ? '' : ' · due ${formatDueLabel(due)}';
      final created = parseFlexibleDate(_asString(row['published_date'] ?? row['created_at']))?.toLocal();

      void add(String key, String heading, String text, String time) {
        next[key] = AppNotification(
          id: key,
          type: 'homework',
          title: heading,
          text: text,
          time: time,
          icon: 'book',
          color: 'sky',
          unread: !read.contains(key),
        );
      }

      // New homework (set in the last 3 days, not already past due).
      if (created != null && now.difference(created).inDays < 3 && (dueDay == null || !dueDay.isBefore(today))) {
        add(
          'hw-new-$id',
          role == Role.parent ? 'New homework' : 'Homework sent',
          role == Role.parent ? '$what$dueLabel' : '$what${klass.isEmpty ? '' : ' · $klass'}$dueLabel',
          created.toIso8601String(),
        );
      }
      if (dueDay != null) {
        final days = dueDay.difference(today).inDays;
        if (days == 1) {
          add('hw-due1-$id', 'Homework due tomorrow', '$what${klass.isEmpty || role == Role.parent ? '' : ' · $klass'}', DateTime(today.year, today.month, today.day, 6).toIso8601String());
        } else if (days == 0) {
          add('hw-due0-$id', 'Homework due today', '$what${klass.isEmpty || role == Role.parent ? '' : ' · $klass'}${due!.hour != 0 || due.minute != 0 ? ' by ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}' : ''}', DateTime(today.year, today.month, today.day, 6, 1).toIso8601String());
        }
      }
    }
    _homeworkNotices
      ..clear()
      ..addAll(next);
    return before.length != next.length || !before.containsAll(next.keys);
  }

  static String formatDueLabel(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
    final base = '${d.day} ${months[d.month - 1]}';
    return d.hour != 0 || d.minute != 0 ? '$base, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : base;
  }

  List<PickupDelegate> delegatesFor(String studentId) =>
      pickupDelegates.where((d) => d.studentId == studentId && d.status != DelegateStatus.revoked).toList();

  List<PickupDelegate> get pendingDelegates =>
      pickupDelegates.where((d) => d.status == DelegateStatus.pending).toList();

  List<PickupLog> get todayPickupLogs {
    final today = DateTime.now();
    return [
      for (final log in pickupLogs)
        if (_sameDay(_parseStamp(log.time), today)) log,
    ];
  }

  DateTime? _parseStamp(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
    return null;
  }

  bool _sameDay(DateTime? when, DateTime today) {
    if (when == null) return true;
    return when.year == today.year && when.month == today.month && when.day == today.day;
  }

  Future<String> refreshPickup() async {
    if (!ApiSession.instance.isSignedIn) return '';
    try {
      final fetched = await Future.wait([
        _table('/pickup-delegates'),
        _table('/pickup-passes'),
        _table('/pickup-logs'),
        _table('/notifications'),
      ]);
      tables['pickup_delegates'] = fetched[0];
      tables['pickup_passes'] = fetched[1];
      tables['pickup_logs'] = fetched[2];
      tables['notifications'] = fetched[3];
      _applyPickupTables();
      _applyNotificationRows();
      notifyListeners();
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not refresh pickup records.';
    }
  }

  Future<String> _postPickup(String path, [Map<String, dynamic>? body]) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in through the school API first.';
    try {
      await ApiClient.instance.post(path, body);
      await refreshPickup();
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not save pickup to the school API.';
    }
  }

  Future<String> issuePass({
    required Student student,
    required String parentName,
    PickupDelegate? delegate,
  }) async {
    if (delegate != null && delegate.status != DelegateStatus.authorised) {
      return 'A teacher or administrator must confirm this delegate first.';
    }
    if (ApiSession.instance.isSignedIn) {
      return _postPickup('/pickup-passes', {
        'student_id': student.id,
        if (delegate != null) 'delegate_id': delegate.id,
      });
    }
    _pickupSeq += 1;
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final token = '${student.id.replaceAll('-', '')}-$stamp-$_pickupSeq';
    final otc = _nextPickupOtc();
    final pass = PickupPass(
      token: token,
      studentId: student.id,
      studentName: student.name,
      klass: student.klass,
      parentName: parentName,
      pickerName: delegate?.name ?? parentName,
      pickerRole: delegate == null ? 'Parent' : delegate.relation,
      kind: delegate == null ? 'parent' : 'delegate',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      delegateId: delegate?.id,
      palmCredentialId: student.palmCredentialId.isEmpty ? null : student.palmCredentialId,
      cardNumber: student.cardNumber.isEmpty ? null : student.cardNumber,
      otc: otc,
    );
    pickupPasses.removeWhere((p) => p.studentId == student.id && p.live);
    pickupPasses.insert(0, pass);
    notifyListeners();
    return '';
  }

  Future<String> requestDelegate({
    required Student student,
    required String name,
    required String relation,
    required String phone,
    required String until,
    required String requestedBy,
    String? pickupDate,
    String? pickupTime,
  }) async {
    if (ApiSession.instance.isSignedIn) {
      return _postPickup('/pickup-delegates', {
        'student_id': student.id,
        'name': name,
        'relation': relation,
        'phone': phone,
        'valid_until': until,
        if (pickupDate != null && pickupDate.isNotEmpty) 'pickup_date': pickupDate,
        if (pickupTime != null && pickupTime.isNotEmpty) 'pickup_time': pickupTime,
      });
    }
    final id = 'DEL-${DateTime.now().millisecondsSinceEpoch}';
    final confirmOtc = _nextPickupOtc();
    final scheduled = pickupDate != null && pickupDate.isNotEmpty;
    final payload = scheduled
        ? 'e10://pickup?kind=auth&token=$id'
        : 'e10://pickup?kind=confirm&did=$id&sid=${student.id}&child=${Uri.encodeComponent(student.name)}&picker=${Uri.encodeComponent(name)}&role=${Uri.encodeComponent(relation)}&token=$id&otc=$confirmOtc';
    final delegate = PickupDelegate(
      id: id,
      studentId: student.id,
      studentName: student.name,
      klass: student.klass,
      name: name,
      relation: relation,
      phone: phone,
      until: until,
      requestedBy: requestedBy,
      status: scheduled ? DelegateStatus.authorised : DelegateStatus.pending,
      confirmOtc: confirmOtc,
      confirmPayload: payload,
      pickupDate: pickupDate,
      pickupTime: pickupTime,
      schoolName: student.schoolName,
      payload: scheduled ? payload : null,
    );
    pickupDelegates.insert(0, delegate);
    notifyListeners();
    return '';
  }

  Future<String?> confirmDelegate(String id, {required String officer, Role? role}) async {
    if (ApiSession.instance.isSignedIn) {
      final err = await _postPickup('/pickup-delegates/$id/confirm');
      return err.isEmpty ? null : err;
    }
    final index = pickupDelegates.indexWhere((d) => d.id == id);
    if (index < 0) return 'Delegation not found.';
    final delegate = pickupDelegates[index];
    if (delegate.status != DelegateStatus.pending) return 'This delegation is not awaiting confirmation.';
    delegate.status = DelegateStatus.authorised;
    notifyListeners();
    return null;
  }

  Future<String?> rejectDelegate(String id, {required String officer, Role? role}) async {
    if (ApiSession.instance.isSignedIn) {
      final err = await _postPickup('/pickup-delegates/$id/reject');
      return err.isEmpty ? null : err;
    }
    final index = pickupDelegates.indexWhere((d) => d.id == id);
    if (index < 0) return 'Delegation not found.';
    pickupDelegates[index].status = DelegateStatus.rejected;
    notifyListeners();
    return null;
  }

  Future<String?> revokeDelegate(String id, {String? parentName}) async {
    if (ApiSession.instance.isSignedIn) {
      final err = await _postPickup('/pickup-delegates/$id/revoke');
      return err.isEmpty ? null : err;
    }
    final index = pickupDelegates.indexWhere((d) => d.id == id);
    if (index < 0) return 'Delegate not found.';
    final delegate = pickupDelegates[index];
    if (delegate.status == DelegateStatus.revoked) return 'This delegate is already revoked.';
    if (delegate.status == DelegateStatus.rejected) return 'This request was already declined.';
    delegate.status = DelegateStatus.revoked;
    pickupPasses.removeWhere((p) => p.delegateId == id && !p.used);
    notifyListeners();
    return null;
  }

  PickupPass? resolvePass(String raw) {
    final otc = _extractOtc(raw);
    if (otc.isNotEmpty) {
      for (final pass in pickupPasses) {
        if (pass.live && pass.otc == otc) return pass;
      }
    }
    final token = _extractToken(raw);
    if (token.isEmpty) return null;
    for (final pass in pickupPasses) {
      if (pass.token == token) return pass;
    }
    return null;
  }

  Future<String?> confirmRelease({
    required String code,
    required String officer,
    String gate = 'Main Gate',
  }) async {
    if (ApiSession.instance.isSignedIn) {
      final err = await _postPickup('/pickup/scan', {'code': code, 'gate': gate});
      return err.isEmpty ? null : err;
    }
    final otc = _extractOtc(code);
    final token = _extractToken(code);
    for (final d in pickupDelegates) {
      if (d.status != DelegateStatus.pending) continue;
      final matchesOtc = otc.isNotEmpty && d.confirmOtc == otc;
      final matchesToken = token.isNotEmpty &&
          (d.id == token ||
              (d.confirmPayload != null && d.confirmPayload!.contains(token)));
      if (matchesOtc || matchesToken) {
        return confirmDelegate(d.id, officer: officer);
      }
    }
    final pass = resolvePass(code);
    if (pass == null) {
      return 'Code not recognised. Ask the parent for a fresh pickup OTC or QR.';
    }
    if (pass.used) {
      return 'This pickup code was already used.';
    }
    if (pass.expired) {
      return 'Code expired. Ask the parent to refresh the OTC or QR.';
    }
    if (pass.delegateId != null) {
      final pending = pickupDelegates.where((d) => d.id == pass.delegateId).toList();
      if (pending.isEmpty || pending.first.status != DelegateStatus.authorised) {
        return 'This is a delegated pickup. A teacher or administrator must confirm the delegate first.';
      }
    }
    pass.used = true;
    final time = _clock();
    pickupLogs.insert(
      0,
      PickupLog(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
        studentName: pass.studentName,
        klass: pass.klass,
        pickerName: pass.pickerName,
        pickerRole: pass.pickerRole,
        kind: pass.kind,
        gate: gate,
        officer: officer,
        time: time,
      ),
    );
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> inspectPickup(String code) async {
    if (ApiSession.instance.isSignedIn) {
      try {
        final decoded = await ApiClient.instance.post('/pickup/verify', {'code': code.trim()});
        if (decoded is Map && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data'] as Map);
        }
        return null;
      } on ApiException catch (error) {
        throw ApiException(error.message, status: error.status);
      }
    }
    final delegate = _matchAuthorization(code);
    if (delegate == null) {
      throw ApiException('Pickup authorization is invalid or expired.');
    }
    return {
      'child': delegate.studentName,
      'school': delegate.schoolName,
      'pickup_person': delegate.name,
      'phone': delegate.phone,
      'pickup_date': delegate.pickupDate,
      'pickup_time': delegate.pickupTime,
      'status': 'ACTIVE',
      'delegation_id': delegate.id,
    };
  }

  Future<Map<String, dynamic>?> approvePickup({required String code, String gate = 'Main Gate', required String officer}) async {
    if (ApiSession.instance.isSignedIn) {
      try {
        final decoded = await ApiClient.instance.post('/pickup/approve', {'code': code.trim(), 'gate': gate});
        await refreshPickup();
        if (decoded is Map && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data'] as Map);
        }
        return null;
      } on ApiException catch (error) {
        throw ApiException(error.message, status: error.status);
      }
    }
    final delegate = _matchAuthorization(code);
    if (delegate == null) {
      throw ApiException('Pickup authorization is invalid or expired.');
    }
    delegate.status = DelegateStatus.used;
    pickupLogs.insert(
      0,
      PickupLog(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
        studentName: delegate.studentName,
        klass: delegate.klass,
        pickerName: delegate.name,
        pickerRole: delegate.relation,
        kind: 'delegate',
        gate: gate,
        officer: officer,
        time: _clock(),
        schoolName: delegate.schoolName,
      ),
    );
    notifyListeners();
    return {
      'status': 'USED',
      'child': delegate.studentName,
      'child_status': 'PICKED UP',
      'school': delegate.schoolName,
      'pickup_person': delegate.name,
      'verified_by': officer,
      'verified_at': DateTime.now().toIso8601String(),
    };
  }

  PickupDelegate? _matchAuthorization(String raw) {
    final otc = _extractOtc(raw);
    final token = _extractToken(raw);
    for (final d in pickupDelegates) {
      if (d.status != DelegateStatus.authorised) continue;
      if (d.pickupDate == null || d.pickupDate!.isEmpty) continue;
      final matchesOtc = otc.isNotEmpty && d.confirmOtc == otc;
      final payload = d.payload ?? d.confirmPayload ?? '';
      final matchesToken = token.isNotEmpty && (payload.contains(token) || d.id == token);
      if (matchesOtc || matchesToken) return d;
    }
    return null;
  }

  /// Mobile-money wallet prefix → pay-intent provider, same table the website
  /// uses to pre-pick the network from the payer's number.
  static const _momoPrefixes = {
    '024': 'mtn_momo', '025': 'mtn_momo', '053': 'mtn_momo', '054': 'mtn_momo', '055': 'mtn_momo', '059': 'mtn_momo',
    '020': 'telecel_cash', '050': 'telecel_cash',
    '026': 'airteltigo_money', '027': 'airteltigo_money', '056': 'airteltigo_money', '057': 'airteltigo_money',
  };

  static String? momoProviderFor(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('233')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length < 9) return null;
    return _momoPrefixes['0${digits.substring(0, 2)}'];
  }

  /// Starts a parent's mobile-money payment the way the website does: a
  /// pay-intent against the child's balance (the school allocates it across
  /// open bills). The parent approves the prompt on their phone; poll
  /// [paymentIntentStatus] until it settles. Nothing changes on the bill
  /// until the provider confirms.
  Future<FeePaymentResult> startParentPayment({
    required String studentId,
    required double amount,
    required String provider,
    required String payerPhone,
    String studentName = '',
    String parentName = '',
    String feeLabel = '',
  }) async {
    if (!ApiSession.instance.isSignedIn || studentId.isEmpty) {
      return const FeePaymentResult(error: 'Sign in again to pay school fees.');
    }
    final outstanding = studentFinance(studentId).balance;
    if (amount <= 0 || amount - outstanding > 0.009) {
      return FeePaymentResult(error: 'Enter an amount up to GHS ${outstanding.toStringAsFixed(2)}.');
    }
    try {
      final res = await ApiClient.instance.post('/students/$studentId/pay-balance/pay-intents', {
        'provider': provider,
        'amount': double.parse(amount.toStringAsFixed(2)),
        'payer_phone': payerPhone,
      });
      final data = res is Map && res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : const <String, dynamic>{};
      return FeePaymentResult(
        status: '${data['status'] ?? 'pending'}',
        paymentId: '${data['id'] ?? ''}',
        reference: '${data['reference'] ?? ''}',
        parentName: parentName,
        childName: studentName,
        schoolName: brandedSchoolName,
        method: paymentMethodLabel({'method': provider}),
        amount: amount.toStringAsFixed(2),
        date: '${data['created_at'] ?? DateTime.now().toIso8601String()}',
        feeLabel: feeLabel,
      );
    } on ApiException catch (error) {
      return FeePaymentResult(error: error.message);
    } catch (_) {
      return const FeePaymentResult(error: 'Could not start the payment. Check your connection and try again.');
    }
  }

  /// Latest state of a pay-intent started by [startParentPayment]; null when
  /// the check itself failed (keep polling). Refreshes the child's fees once
  /// it succeeds.
  Future<FeePaymentResult?> paymentIntentStatus(FeePaymentResult started, {String studentId = ''}) async {
    if (started.paymentId.isEmpty) return null;
    try {
      final res = await ApiClient.instance.get('/payment-intents/${started.paymentId}');
      final data = res is Map && res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : const <String, dynamic>{};
      String pick(String key, String fallback) {
        final v = data[key];
        return v == null || '$v'.trim().isEmpty ? fallback : '$v';
      }
      final result = FeePaymentResult(
        status: pick('status', started.status),
        paymentId: started.paymentId,
        receiptNumber: pick('receipt_number', started.receiptNumber),
        transactionNumber: pick('transaction_number', started.transactionNumber),
        reference: pick('reference', started.reference),
        failureKind: pick('failure_kind', ''),
        remaining: pick('remaining_debt', started.remaining),
        parentName: started.parentName,
        childName: started.childName,
        schoolName: started.schoolName,
        method: started.method,
        amount: pick('amount', started.amount),
        date: pick('paid_at', pick('updated_at', started.date)),
        feeLabel: started.feeLabel,
      );
      if (result.isSuccess && studentId.isNotEmpty) await refreshChildFees(studentId);
      return result;
    } catch (_) {
      return null;
    }
  }

  bool _billsRefreshing = false;
  bool _noticesRefreshing = false;

  /// Everything that changes while the app is open: bills/payments, the
  /// notification feed (attendance alerts included) and, for staff, today's
  /// attendance so the dashboard counts stay current.
  Future<void> refreshLive() async {
    await Future.wait([refreshBillsAndPayments(), refreshNoticesAndAttendance(), refreshTeacherToday()]);
  }

  Future<void> refreshNoticesAndAttendance() async {
    if (!ApiSession.instance.isSignedIn || _noticesRefreshing) return;
    _noticesRefreshing = true;
    try {
      final results = await Future.wait([
        _tableOrNull('/notifications', timeout: const Duration(seconds: 12)),
        // A cashier can read only notifications here; anything else is a 403.
        _cashierSession && !_cashierMayMessage
            ? Future.value(null)
            : _tableOrNull('/message-threads', timeout: const Duration(seconds: 12)),
        // Today only: the full history (with every student attached) is
        // large on slow mobile data and is loaded by the full sync instead.
        _cashierSession
            ? Future.value(null)
            : _tableOrNull('/attendance', query: {'date': _today(), 'per_page': '500'}, timeout: const Duration(seconds: 12)),
      ]);
      var changed = false;
      final notes = results[0];
      if (notes != null && jsonEncode(notes) != jsonEncode(tables['notifications'] ?? const [])) {
        tables['notifications'] = notes;
        _applyNotificationRows();
        changed = true;
      }
      final threads = results[1];
      if (threads != null && jsonEncode(threads) != jsonEncode(tables['message_threads'] ?? const [])) {
        tables['message_threads'] = threads;
        _applyMessageThreads();
        changed = true;
      }
      final att = results[2];
      if (att != null && att.isNotEmpty) {
        final before = jsonEncode(tables['attendance'] ?? const []);
        mergeAttendanceRows(att);
        if (jsonEncode(tables['attendance'] ?? const []) != before) {
          changed = true;
          _rebuildStaffClockNotices();
        }
      }
      if (!_cashierSession && await rebuildHomeworkNotices()) changed = true;
      if (changed) notifyListeners();
    } catch (_) {
    } finally {
      _noticesRefreshing = false;
    }
  }
  Timer? _liveTimer;

  /// Polls bills and payments every 30 seconds while signed in, so a bill
  /// created (or a payment/edit made) on the office website or on another
  /// device reaches this one without a manual refresh. Idempotent.
  ///
  /// Every other tick (once a minute) it does a full, quiet resync instead,
  /// so students, classes, staff, announcements, timetable and the rest also
  /// reach every dashboard without anyone pulling to refresh.
  void startLiveSync() {
    var tick = 0;
    // Every 30s tick: notices, today's attendance and the teacher's day
    // (small). Bills/payments every 2 min (the 10s payment watch below
    // catches new payments sooner); a full re-sync of every list every
    // 5 min. Re-downloading everything each minute timed out on slow
    // mobile data (~100 KB/s).
    _liveTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (loading) return;
      tick++;
      if (tick % 10 == 0) {
        unawaited(syncFromApi(budget: const Duration(seconds: 60)));
      } else {
        unawaited(refreshNoticesAndAttendance());
        unawaited(refreshTeacherToday());
        if (tick % 4 == 0) unawaited(refreshBillsAndPayments());
      }
      unawaited(refreshSessionProfile());
    });
    _payTimer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      if (!loading) unawaited(watchPayments());
    });
  }

  Timer? _payTimer;
  bool _payWatching = false;
  Map<String, String>? _paySeen;

  /// Payments land in seconds: every 10s this reads only the newest few
  /// payments, and when one is new (or its status changed, e.g. a MoMo
  /// payment confirmed) refreshes bills and balances straight away instead
  /// of waiting for the minute-long sync. Admins also get a notice.
  Future<void> watchPayments() async {
    if (!ApiSession.instance.isSignedIn || _payWatching || _activeRole == Role.teacher || _cashierSession) return;
    _payWatching = true;
    try {
      final latest = await ApiClient.instance.get('/payments', query: const {'per_page': '10'}, timeout: const Duration(seconds: 12));
      final rows = [..._listOf(_unwrap(latest) ?? latest)];
      final now = {for (final r in rows) _asString(r['id']): _cellOf(r['status'])};
      final seen = _paySeen;
      _paySeen = now;
      if (seen == null) return; // first look: just remember what's there
      final changed = [
        for (final r in rows)
          if (seen[_asString(r['id'])] != _cellOf(r['status'])) r,
      ];
      if (changed.isEmpty) return;
      await refreshBillsAndPayments();
      for (final id in {for (final r in changed) _asString(r['student_id'] ?? (r['student'] is Map ? (r['student'] as Map)['id'] : ''))}) {
        if (id.isNotEmpty && childFeeSummary.containsKey(id)) await refreshChildFees(id);
      }
      if (_activeRole?.isAdminPortal == true) {
        for (final r in changed) {
          if (!_successfulPayment(r)) continue;
          final id = 'pay-${_asString(r['id'])}';
          if (_paymentNotices.containsKey(id)) continue;
          final who = paymentStudentName(r);
          _paymentNotices[id] = AppNotification(
            id: id,
            type: 'payment_succeeded',
            title: 'Payment received',
            text: 'GHS ${paymentAmount(r).toStringAsFixed(2)}${who.isEmpty ? '' : ' for $who'} · ${paymentMethodLabel(r)}',
            time: '${r['paid_at'] ?? r['created_at'] ?? DateTime.now().toIso8601String()}',
            icon: 'dollar',
            color: 'emerald',
          );
        }
      }
      notifyListeners();
    } catch (_) {
    } finally {
      _payWatching = false;
    }
  }

  final Map<String, AppNotification> _paymentNotices = {};

  DateTime? _profileAt;

  /// Re-reads `/auth/me` (at most every 2 minutes) so a change the admin
  /// makes on the website reaches the dashboard without signing out: a child
  /// promoted from KG to Class 1 (or primary to JHS) gets their new class and
  /// `is_early_years` flag, and a teacher moved into or out of an early-years
  /// department gets the new `daily_reports_eligible`. The next sync then
  /// rebuilds the children/class lists from the fresh profile.
  Future<void> refreshSessionProfile({bool force = false}) async {
    if (!ApiSession.instance.isSignedIn) return;
    final at = _profileAt;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(minutes: 2)) return;
    _profileAt = DateTime.now();
    try {
      final hit = await ApiClient.instance.get(ApiConfig.mePath, timeout: const Duration(seconds: 12));
      if (hit is! Map) return;
      final data = hit['data'] is Map ? Map<String, dynamic>.from(hit['data'] as Map) : Map<String, dynamic>.from(hit);
      final fresh = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : data;
      if (fresh.isEmpty || jsonEncode(fresh) == jsonEncode(ApiSession.instance.user ?? const {})) return;
      final token = ApiSession.instance.token;
      if (token == null || token.isEmpty) return;
      ApiSession.instance.save(token, fresh);
      _activeDailyReportsEligible = fresh['daily_reports_eligible'] == true;
      notifyListeners();
    } catch (_) {}
  }

  /// Early-years (crèche / nursery / KG) by the class itself: the class's
  /// department flag when the class list carries it, else the same
  /// class-name rule the API uses.
  bool isEarlyYearsClass({String id = '', String name = ''}) {
    for (final row in tableRows('school_classes')) {
      final sameId = id.isNotEmpty && '${row['id']}' == id;
      final sameName = name.isNotEmpty && _classLabel(row).toLowerCase() == name.trim().toLowerCase();
      if (!sameId && !sameName) continue;
      final dept = row['department'];
      final flag = row['is_early_years'] ?? (dept is Map ? dept['is_early_years'] : null);
      if (flag != null) return flag == true || flag == 1;
      if (name.isEmpty) name = _classLabel(row);
      break;
    }
    return _earlyYearsName.hasMatch(name);
  }

  static final _earlyYearsName = RegExp(
    r'\b(kg\s*\d?|kindergarten|nursery|pre[\s-]?school|pre[\s-]?k|creche|cr.che|early\s*years|baby\s*class)\b',
    caseSensitive: false,
  );

  DashboardSummary? dashboardSummary;

  /// Refreshed with every sync. A failed request keeps the last figures, and
  /// with none the dashboard counts from the downloaded lists as before.
  Future<void> refreshDashboardSummary() async {
    if (_activeRole?.isAdminPortal != true || !ApiSession.instance.isSignedIn) return;
    try {
      final hit = await ApiClient.instance.get(
        ApiConfig.dashboardSummaryPath,
        query: {'date': _today()},
        timeout: const Duration(seconds: 12),
      );
      final data = _unwrap(hit);
      if (data is! Map) return;
      dashboardSummary = DashboardSummary.fromJson(Map<String, dynamic>.from(data));
      notifyListeners();
    } catch (_) {}
  }

  void stopLiveSync() {
    _liveTimer?.cancel();
    _liveTimer = null;
    _payTimer?.cancel();
    _payTimer = null;
    _paySeen = null;
  }

  /// Re-pulls bills and payments straight from the office website. A failed
  /// request leaves the current rows alone instead of wiping them.
  Future<void> refreshBillsAndPayments() async {
    if (!ApiSession.instance.isSignedIn || _billsRefreshing || _cashierSession) return;
    _billsRefreshing = true;
    try {
      final results = await Future.wait([
        _tableOrNull('/bills', timeout: const Duration(seconds: 12)),
        _tableOrNull('/payments', timeout: const Duration(seconds: 12)),
      ]);
      final billRows = results[0];
      final payRows = results[1];
      if (billRows == null || payRows == null) return;
      final unchanged = jsonEncode(billRows) == jsonEncode(tables['bills'] ?? const []) &&
          jsonEncode(payRows) == jsonEncode(tables['payments'] ?? const []);
      if (unchanged) return;
      tables['payments'] = payRows;
      tables['bills'] = billRows;
      invoices
        ..clear()
        ..addAll([for (final row in billRows) invoiceFromRow(row)]);
      for (final id in childFeeSummary.keys.toList()) {
        final bills = invoices.where((item) => item.studentId == id);
        childFeeSummary[id] = (
          charges: bills.fold<double>(0, (sum, item) => sum + item.amount),
          paid: bills.fold<double>(0, (sum, item) => sum + item.amountPaid),
          balance: bills.fold<double>(0, (sum, item) => sum + item.dueAmount),
        );
      }
      notifyListeners();
    } catch (_) {
    } finally {
      _billsRefreshing = false;
    }
  }

  /// Payouts (money the platform settles out to the school), shown on the
  /// admin Transactions "Payouts out" tab — the same `/payouts` list the
  /// website reads. Payments in come from `/payments` via
  /// [refreshBillsAndPayments].
  Future<void> loadFinanceWorkspace() async {
    if (!ApiSession.instance.isSignedIn) return;
    final payouts = await _tableOrNull('/payouts', query: const {'per_page': '100'});
    if (payouts == null) return;
    tables['payouts'] = payouts;
    notifyListeners();
  }

  /// A parent's mobile-money payments that the provider has not settled yet
  /// (`/payment-intents`), so a payment started earlier still shows as
  /// "in progress" after the pay screen was closed.
  List<Map<String, dynamic>> paymentIntents = [];

  Future<void> loadPaymentIntents() async {
    if (!ApiSession.instance.isSignedIn) return;
    final rows = await _tableOrNull('/payment-intents', query: const {'per_page': '50'});
    if (rows == null) return;
    paymentIntents = rows;
    notifyListeners();
  }

  /// Re-checks every unsettled intent (the website does this every 5s);
  /// refreshes the child's fees when one succeeds.
  Future<void> refreshPendingIntents() async {
    final pending = [
      for (final row in paymentIntents)
        if (const {'pending', 'processing', 'created'}.contains('${row['status']}')) row,
    ];
    if (pending.isEmpty) return;
    final fresh = await Future.wait([
      for (final row in pending) _object('/payment-intents/${row['id']}'),
    ]);
    final settled = <String>{};
    for (final got in fresh) {
      if (got == null) continue;
      final i = paymentIntents.indexWhere((r) => '${r['id']}' == '${got['id']}');
      if (i >= 0) paymentIntents[i] = {...paymentIntents[i], ...got};
      if ('${got['status']}' == 'successful') settled.add('${got['student_id'] ?? ''}');
    }
    for (final id in settled) {
      if (id.isNotEmpty) await refreshChildFees(id);
    }
    notifyListeners();
  }

  Future<String> collectCashPayment({
    required String billId,
    required double amount,
    required String paidBy,
    String method = 'cash',
    String? bankReference,
  }) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in to collect a payment.';
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      // There is no dedicated `/finance/payments` route on the API; this
      // posts to the same `/payments` resource the parent fee-payment flow
      // uses, with the same field shape.
      await ApiClient.instance.post('/payments', {
        'bill_id': billId,
        'amount': amount,
        'method': method,
        'reference': 'CSH$stamp',
        'paid_by': paidBy,
        if (method == 'cash') 'status': 'successful',
        if (bankReference != null) 'bank_reference': bankReference,
        if (method == 'bank_transfer') 'status': 'pending',
      });
      await syncFromApi();
      await loadFinanceWorkspace();
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not collect this payment.';
    }
  }

  Future<String> verifyFinancePayment(String paymentId, {bool success = true}) async {
    try {
      // No dedicated `/finance/payments/{id}/verify` route exists; update the
      // payment's status directly via the real `/payments/{payment}` route.
      await ApiClient.instance.put('/payments/$paymentId', {
        'status': success ? 'successful' : 'failed',
      });
      await syncFromApi();
      await loadFinanceWorkspace();
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not verify this payment.';
    }
  }

  ({double charges, double paid, double balance}) studentFinance(String studentId) {
    final cached = childFeeSummary[studentId];
    if (cached != null) return cached;
    final bills = invoices.where((i) => i.studentId == studentId);
    final charges = bills.fold<double>(0, (s, i) => s + i.amount);
    final billedPaid = bills.fold<double>(0, (s, i) => s + (i.amountPaid > 0 ? i.amountPaid : (i.isPaid ? i.amount : 0)));
    final paid = billedPaid > 0.009 ? billedPaid : feesCollectedForStudent(studentId);
    final balance = bills.fold<double>(0, (s, i) => s + i.dueAmount);
    return (charges: charges, paid: paid, balance: balance);
  }

  final Map<String, ({double charges, double paid, double balance})> childFeeSummary = {};

  Future<void> refreshChildFees(String studentId) async {
    if (studentId.isEmpty || !ApiSession.instance.isSignedIn) return;
    try {
      final billRows = await _tableOrNull('/bills', query: {'student_id': studentId, 'per_page': '100'}, timeout: const Duration(seconds: 10));
      final payRows = await _tableOrNull('/payments', query: {'student_id': studentId, 'per_page': '100'}, timeout: const Duration(seconds: 10));
      if (billRows == null || payRows == null) return;
      invoices.removeWhere((item) => item.studentId == studentId);
      invoices.addAll([for (final row in billRows) invoiceFromRow(row)]);
      final kept = [
        for (final row in tableRows('payments'))
          if ('${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}' != studentId) row,
      ];
      tables['payments'] = [...kept, ...payRows];
      final bills = invoices.where((item) => item.studentId == studentId);
      final charges = bills.fold<double>(0, (sum, item) => sum + item.amount);
      final paid = bills.fold<double>(0, (sum, item) => sum + item.amountPaid);
      final balance = bills.fold<double>(0, (sum, item) => sum + item.dueAmount);
      childFeeSummary[studentId] = (charges: charges, paid: paid, balance: balance);
      notifyListeners();
    } catch (_) {
      await syncFromApi();
    }
  }

  List<BillTxn> paymentsForStudent(String studentId) {
    if (studentId.isEmpty) return const [];
    final nested = [
      for (final bill in invoices)
        if (bill.studentId == studentId) ...bill.payments,
    ];
    if (nested.isNotEmpty) {
      nested.sort((a, b) => b.paidAt.compareTo(a.paidAt));
      return nested;
    }
    return [
      for (final row in paymentRecords)
        if ('${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}' == studentId)
          _txnFromRow(row, studentName: paymentStudentName(row)),
    ];
  }

  List<BillTxn> paymentsForBill(String billId) {
    if (billId.isEmpty) return const [];
    final match = invoices.where((i) => i.id == billId);
    if (match.isNotEmpty && match.first.payments.isNotEmpty) return match.first.payments;
    return [
      for (final row in paymentRecords)
        if ('${row['bill_id'] ?? ''}' == billId) _txnFromRow(row),
    ];
  }

  List<Invoice> billsForStudent(String studentId) {
    final list = [
      for (final inv in invoices)
        if (inv.studentId == studentId) inv,
    ];
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.displayNumber.compareTo(a.displayNumber);
    });
    return list;
  }

  Future<Invoice?> loadBillDetail(String billId) async {
    if (billId.isEmpty) return null;
    Map<String, dynamic>? row;
    if (ApiSession.instance.isSignedIn) {
      row = await _object('/bills/$billId');
    }
    final invoice = row != null
        ? invoiceFromRow(row)
        : invoices.cast<Invoice?>().firstWhere((item) => item?.id == billId, orElse: () => null);
    if (invoice == null) return null;
    final index = invoices.indexWhere((item) => item.id == invoice.id);
    if (index >= 0) {
      invoices[index] = invoice;
    } else {
      invoices.insert(0, invoice);
    }
    notifyListeners();
    return invoice;
  }

  Invoice invoiceFromRow(Map<String, dynamic> row) {
    final id = '${row['id']}';
    final nested = row['payments'];
    final fromNested = <BillTxn>[
      if (nested is List)
        for (final item in nested)
          if (item is Map) _txnFromRow(Map<String, dynamic>.from(item)),
    ];
    final fromTable = [
      for (final pay in paymentRecords)
        if ('${pay['bill_id'] ?? ''}' == id) _txnFromRow(pay),
    ];
    final linesRaw = row['line_items'] ?? row['lineItems'];
    return Invoice(
      id: id,
      studentId: '${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}',
      student: row['student'] is Map ? _asString((row['student'] as Map)['full_name']) : _asString(row['student_name']),
      amount: _moneyOf(row['total_amount'] ?? row['amount']),
      amountPaid: _moneyOf(row['amount_paid']),
      balance: _moneyOf(row['balance']),
      date: _asString(row['issued_date'] ?? row['created_at']),
      dueDate: _asString(row['due_date']),
      status: _billStatusLabel(_asString(row['status'])),
      description: _asString(row['title'] ?? row['description']),
      invoiceNumber: _asString(row['invoice_number']),
      schoolId: _asString(row['school_id'] ?? (row['school'] is Map ? (row['school'] as Map)['id'] : '')),
      parentId: _asString(row['parent_id'] ?? (row['parent'] is Map ? (row['parent'] as Map)['id'] : '')),
      academicYear: row['academic_year'] is Map
          ? _asString((row['academic_year'] as Map)['year'] ?? (row['academic_year'] as Map)['name'] ?? (row['academic_year'] as Map)['label'])
          : _asString(row['academic_year'] ?? row['academic_year_label']),
      term: row['term'] is Map
          ? _asString((row['term'] as Map)['name'] ?? (row['term'] as Map)['label'])
          : _asString(row['term'] ?? row['term_name']),
      lineItems: [
        if (linesRaw is List)
          for (final item in linesRaw)
            if (item is Map)
              BillLine(
                label: _asString(item['label'] ?? item['description']),
                amount: _moneyOf(item['amount']),
                category: _asString(item['category']),
              ),
      ],
      payments: fromNested.isNotEmpty ? fromNested : fromTable,
    );
  }

  /// Public passthrough so admin-facing screens (e.g. the Finance
  /// transaction table) can resolve the same fee/bill/paid-by detail that
  /// [paymentsForStudent] already surfaces to parents, from a raw
  /// `/payments` row.
  BillTxn billTxnForRow(Map<String, dynamic> row) => _txnFromRow(row, studentName: paymentStudentName(row));

  BillTxn _txnFromRow(Map<String, dynamic> row, {String studentName = ''}) {
    final meta = row['metadata'] is Map ? Map<String, dynamic>.from(row['metadata'] as Map) : const <String, dynamic>{};
    final bill = row['bill'] is Map ? Map<String, dynamic>.from(row['bill'] as Map) : const <String, dynamic>{};
    final school = row['school'] is Map ? Map<String, dynamic>.from(row['school'] as Map) : const <String, dynamic>{};
    final academicTerm = bill['academic_term'] is Map ? Map<String, dynamic>.from(bill['academic_term'] as Map) : const <String, dynamic>{};
    final nestedTransaction = row['transaction'] is Map ? Map<String, dynamic>.from(row['transaction'] as Map) : const <String, dynamic>{};
    final transactionNumber = _firstNonEmpty([
      row['transaction_number'],
      row['transaction_id'],
      row['provider_transaction_id'],
      row['provider_reference'],
      nestedTransaction['number'],
      nestedTransaction['transaction_number'],
      nestedTransaction['transaction_id'],
      meta['transaction_number'],
      meta['transaction_id'],
      meta['provider_transaction_id'],
      row['reference'],
      row['payment_reference'],
      row['bank_reference'],
      meta['reference'],
      meta['payment_reference'],
      // Same convention as Bill.displayNumber: fall back to the payment's
      // own database id rather than showing "Pending" once it exists.
      row['id'],
    ]);
    final reference = _firstNonEmpty([
      row['reference'],
      row['payment_reference'],
      row['bank_reference'],
      meta['reference'],
      meta['payment_reference'],
    ]);
    return BillTxn(
      id: '${row['id'] ?? ''}',
      amount: _moneyOf(row['amount']),
      method: paymentMethodLabel(row),
      status: _asString(row['status']).isEmpty ? 'pending' : _asString(row['status']),
      reference: reference,
      receiptNumber: _asString(row['receipt_number']),
      transactionNumber: transactionNumber,
      paidAt: _asString(row['paid_at'] ?? row['created_at']),
      studentName: studentName.isNotEmpty
          ? studentName
          : (row['student'] is Map ? _asString((row['student'] as Map)['full_name']) : _asString(row['child'])),
      studentId: _asString(
        row['student_number'] ??
            row['admission_number'] ??
            row['student_code'] ??
            row['student_id'] ??
            (row['student'] is Map ? (row['student'] as Map)['id'] : ''),
      ),
      previousDebt: _asString(row['previous_debt'] ?? meta['previous_debt']),
      remainingDebt: _asString(row['remaining_debt'] ?? meta['remaining_debt']),
      paidBy: _asString(row['parent'] ?? row['paid_by'] ?? meta['parent']),
      billId: _asString(row['bill_id'] ?? bill['id']),
      billNumber: _asString(row['invoice_number'] ?? bill['invoice_number']),
      schoolName: _asString(row['school_name'] ?? school['name']),
      feeLabel: _asString(row['fee'] ?? row['description'] ?? meta['fee'] ?? bill['title']),
      billCategory: _asString(row['bill_category'] ?? bill['category']),
      academicTerm: _asString(row['academic_term'] ?? academicTerm['name']),
    );
  }

  String _extractToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (RegExp(r'^\d{6}$').hasMatch(value)) return '';
    if (value.contains('token=')) {
      try {
        return Uri.parse(value).queryParameters['token'] ?? value;
      } catch (_) {}
    }
    return value;
  }

  String _extractOtc(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.contains('otc=')) {
      try {
        final digits = (Uri.parse(value).queryParameters['otc'] ?? '').replaceAll(RegExp(r'\D'), '');
        if (digits.length == 6) return digits;
      } catch (_) {}
    }
    return RegExp(r'^\d{6}$').hasMatch(value) ? value : '';
  }

  String _nextPickupOtc() {
    final used = <String>{
      for (final pass in pickupPasses)
        if (pass.live && (pass.otc ?? '').isNotEmpty) pass.otc!,
      for (final d in pickupDelegates)
        if (d.status == DelegateStatus.pending && (d.confirmOtc ?? '').isNotEmpty) d.confirmOtc!,
    };
    String code;
    do {
      code = (100000 + DateTime.now().microsecondsSinceEpoch % 900000).toString();
    } while (used.contains(code));
    return code;
  }

  String _clock() {
    final n = DateTime.now();
    var hour = n.hour % 12;
    if (hour == 0) hour = 12;
    final minute = n.minute.toString().padLeft(2, '0');
    final ap = n.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ap';
  }

  // 3s was the original default and is still used by a couple of intentionally
  // quick fire-and-forget refreshes below, but as the *default* it was too
  // tight for a full resync against this server (~1.2-1.4s per request,
  // 15+ requests for an admin session) — see _mutate's comment for what
  // that caused.
  //
  // syncFromApi has no reentrancy guard of its own below (_syncFromApiNow),
  // and both `students` and every other list here get wiped with `clear()`
  // before being repopulated. Widening the budgets above made two calls
  // overlapping in practice — the background load kicked off by
  // `_login`/`_restoreSession` was still in flight when a save's own
  // `_mutate` -> `syncFromApi` started — far more likely, and whichever
  // call's `clear()` ran after the other's `addAll()` left that list
  // permanently empty until a full page reload. Coalescing concurrent
  // calls onto the same in-flight Future (same pattern as
  // ApiConfig.probe()'s `_inFlight`) fixes that at the root instead of
  // trying to out-guess the timing.
  Future<void>? _syncInFlight;

  Future<void> syncFromApi({Duration budget = const Duration(seconds: 15)}) {
    final existing = _syncInFlight;
    if (existing != null) return existing;
    unawaited(refreshSessionProfile());
    unawaited(refreshDashboardSummary());
    final future = _syncFromApiNow(budget);
    _syncInFlight = future;
    return future.whenComplete(() {
      if (identical(_syncInFlight, future)) _syncInFlight = null;
      unawaited(rebuildHomeworkNotices().then((changed) {
        if (changed) notifyListeners();
      }));
    });
  }

  bool _bootstrapInBackground = false;

  Future<void> _syncFromApiNow(Duration budget) async {
    loading = true;
    syncError = null;
    notifyListeners();
    await _hydrateReadReceipts();
    if (!ApiSession.instance.isSignedIn) {
      loading = false;
      notifyListeners();
      return;
    }
    startLiveSync();
    // Show the last copy saved on this device straight away, so a restarted
    // app opens on real numbers instead of empty dashboards while the
    // (slow) server catches up.
    if (tables.isEmpty && await _restoreCachedPayload()) notifyListeners();
    void apply(Map<String, dynamic> payload) {
      _cachedSchool = payload['school'] is Map ? Map<String, dynamic>.from(payload['school'] as Map) : _cachedSchool;
      // Carry over the extra tables (exams, library, subjects...) that the
      // core payload doesn't include, so a resync never blanks them.
      final fresh = payload['tables'];
      if (fresh is Map<String, dynamic>) {
        for (final entry in tables.entries) {
          fresh.putIfAbsent(entry.key, () => entry.value);
        }
      }
      applyBootstrap(payload);
      unawaited(_fillExtraTables().whenComplete(_saveCachedPayload));
    }

    if (_bootstrapInBackground) {
      // A slow load from before is still arriving; don't start a second one.
      loading = false;
      notifyListeners();
      return;
    }
    final pending = _bootstrapPayload(fallbackTables: true);
    try {
      apply(await pending.timeout(budget));
    } on TimeoutException {
      // Slow mobile data: keep what's on screen (the saved copy) and let the
      // load finish in the background instead of throwing it away with an
      // error. Only a real failure is reported.
      _bootstrapInBackground = true;
      unawaited(pending.then((payload) {
        apply(payload);
        syncError = null;
      }).catchError((Object _) {
        syncError = 'Could not load school records from the office website.';
      }).whenComplete(() {
        _bootstrapInBackground = false;
        notifyListeners();
      }));
    } on ApiException {
      syncError = 'Could not load school records from the office website.';
    } catch (_) {
      syncError = 'Could not load school records from the office website.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshReportCards() async {
    reportCardsLoading = true;
    reportCardsError = null;
    notifyListeners();
    if (!ApiSession.instance.isSignedIn) {
      academicReports.clear();
      reportCardsLoading = false;
      reportCardsError = 'Sign in with your school website account to load reports from the office.';
      notifyListeners();
      return;
    }
    try {
      final rows = await _table('/report-cards', query: const {'per_page': '100'});
      tables['report_cards'] = rows;
      academicReports
        ..clear()
        ..addAll(_academicReportsFromCards(rows));
      if (rows.isEmpty) {
        reportCardsError = 'No report cards on the office website yet.';
      }
    } catch (_) {
      academicReports.clear();
      reportCardsError = 'Could not load report cards from the office website.';
    }
    reportCardsLoading = false;
    notifyListeners();
  }

  Future<void> hydrateWebsiteReport(AcademicReport report) async {
    if (!ApiSession.instance.isSignedIn) return;
    final ids = {
      for (final line in report.lines)
        if (line.cardId.isNotEmpty) line.cardId,
    };
    if (ids.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    await Future.wait([
      for (final id in ids)
        _object('/report-cards/$id').then((row) {
          if (row != null && row.isNotEmpty) rows.add(row);
        }),
    ]);
    if (rows.isEmpty) return;
    _mergeWebsiteCards(rows);
    notifyListeners();
  }

  Future<void> loadWebsiteReportCard(String cardId) async {
    if (cardId.isEmpty || !ApiSession.instance.isSignedIn) return;
    final row = await _object('/report-cards/$cardId');
    if (row == null || row.isEmpty) return;
    _mergeWebsiteCards([row]);
    notifyListeners();
  }

  void _mergeWebsiteCards(List<Map<String, dynamic>> rows) {
    final incoming = _academicReportsFromCards(rows);
    for (final next in incoming) {
      final i = academicReports.indexWhere((r) => r.id == next.id);
      if (i < 0) {
        academicReports.add(next);
        continue;
      }
      for (final line in next.lines) {
        final j = academicReports[i].lines.indexWhere(
          (item) => item.cardId == line.cardId || (item.studentId.isNotEmpty && item.studentId == line.studentId),
        );
        if (j < 0) {
          academicReports[i].lines.add(line);
        } else {
          academicReports[i].lines[j] = line;
        }
      }
    }
  }

  static const _cachePrefix = 'school_cache.v1.';
  Map<String, dynamic>? _cachedSchool;

  /// One saved copy per signed-in account, so a shared phone never shows
  /// one user's school data to another.
  String? get _cacheKey {
    final id = '${ApiSession.instance.user?['id'] ?? ''}';
    return id.isEmpty ? null : '$_cachePrefix$id';
  }

  Future<bool> _restoreCachedPayload() async {
    final key = _cacheKey;
    if (key == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return false;
      final data = jsonDecode(raw);
      if (data is! Map || tables.isNotEmpty) return false;
      final payload = Map<String, dynamic>.from(data);
      if (payload['school'] is Map) _cachedSchool = Map<String, dynamic>.from(payload['school'] as Map);
      applyBootstrap(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveCachedPayload() async {
    final key = _cacheKey;
    if (key == null || tables.isEmpty) return;
    try {
      final raw = jsonEncode({
        'school': _cachedSchool,
        'academic_year_id': academicYearId,
        'academic_term_id': academicTermId,
        'tables': tables,
      });
      // Browser storage caps out around 5 MB; skip rather than fail there.
      if (raw.length > 4 * 1024 * 1024) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, raw);
    } catch (_) {}
  }

  /// Signing out removes every saved school copy from the device.
  Future<void> _forgetCachedPayloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList()) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _bootstrapPayload({bool fallbackTables = true}) async {
    if (!fallbackTables) {
      throw ApiException('School records are not ready yet.');
    }
    return _assemblePayload();
  }

  /// Every core table (guardians, departments, staff, classes, students, ...)
  /// went through this with no `per_page` at all — the Laravel API's default
  /// page size (15) silently truncated any list longer than that, and
  /// nothing here ever followed `meta.last_page` to fetch the rest. Schools
  /// with more than 15 guardians/departments/staff only ever saw the first
  /// page. Default every `_table()` call to a page size big enough to cover
  /// a single school's full list in one request; callers that already pass
  /// their own `per_page` (e.g. the 100-row calls elsewhere) keep it.
  Future<List<Map<String, dynamic>>> _table(String path, {Map<String, String>? query, Duration timeout = const Duration(seconds: 12)}) async {
    return await _tableOrNull(path, query: query, timeout: timeout) ?? const [];
  }

  /// Like [_table] but returns null when the request fails or times out, so a
  /// caller can keep the rows it already has instead of treating a network
  /// hiccup as "the list is empty" (which made bills vanish from the parent
  /// app whenever `/bills` was slower than the timeout).
  Future<List<Map<String, dynamic>>?> _tableOrNull(String path, {Map<String, String>? query, Duration timeout = const Duration(seconds: 12)}) async {
    final fullQuery = {'per_page': '500', ...?query};
    try {
      final response = await ApiClient.instance.get(path, query: fullQuery, timeout: timeout);
      final rows = [..._listOf(_unwrap(response) ?? response)];
      // Laravel caps per_page (the website asks for 100 and pages through),
      // so keep reading pages or long lists — payments above all — get cut off.
      final meta = response is Map && response['meta'] is Map ? response['meta'] as Map : null;
      final lastPage = int.tryParse('${meta?['last_page'] ?? 1}') ?? 1;
      final current = int.tryParse('${meta?['current_page'] ?? 1}') ?? 1;
      // Undated `/attendance` is the whole attendance history; the live
      // refresh re-reads it every minute, so keep that to the first page.
      final history = path == '/attendance' && !(query?.containsKey('date') ?? false);
      if (lastPage > current && !history) {
        final more = await Future.wait([
          for (var page = current + 1; page <= lastPage && page <= 30; page++)
            ApiClient.instance.get(path, query: {...fullQuery, 'page': '$page'}, timeout: timeout),
        ]);
        for (final res in more) {
          rows.addAll(_listOf(_unwrap(res) ?? res));
        }
      }
      return rows;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _object(String path) async {
    try {
      final response = await ApiClient.instance.get(path, timeout: const Duration(seconds: 12));
      final data = _unwrap(response);
      if (data is Map) return _mapOf(data);
    } catch (_) {}
    return null;
  }

  static const _coreTablePaths = <String, String>{
    '/students': 'students',
    '/notifications': 'notifications',
    '/announcements': 'announcements',
    '/message-threads': 'message_threads',
    '/bills': 'bills',
    '/payments': 'payments',
    '/attendance': 'attendance',
    '/timetable-entries': 'timetable_entries',
    '/assignments': 'assignments',
    '/academic-years': 'academic_years',
    '/academic-terms': 'academic_terms',
    '/staff': 'staff',
    '/guardians': 'guardians',
    '/school-classes': 'school_classes',
  };

  /// A cashier works from the live counter endpoints; the API refuses them
  /// the school-wide lists (students, bills, payments, messages…), and
  /// asking anyway every few seconds gets the login rate-limited.
  bool get _cashierSession => _activeRole == Role.cashier;

  bool get _cashierMayMessage {
    final perms = ApiSession.instance.user?['permissions'];
    return perms is List && perms.contains('messages.view');
  }

  Map<String, String> _corePathsForRole() {
    final role = _activeRole;
    if (role?.isAdminPortal == true) return _coreTablePaths;
    if (role == Role.cashier) {
      return {
        '/notifications': 'notifications',
        '/announcements': 'announcements',
        if (_cashierMayMessage) '/message-threads': 'message_threads',
      };
    }
    if (role == Role.teacher) {
      return {
        for (final path in [
          '/students',
          '/notifications',
          '/announcements',
          '/message-threads',
          '/attendance',
          '/timetable-entries',
          '/assignments',
          '/academic-years',
          '/academic-terms',
          '/school-classes',
          '/school',
          '/teacher-subject-assignments',
        ])
          path: _coreTablePaths[path] ?? path.substring(1).replaceAll('-', '_'),
      };
    }
    final parentPaths = <String>[
      '/notifications',
      '/announcements',
      '/message-threads',
      '/report-cards',
      '/daily-reports',
      '/timetable-entries',
      '/assignments',
      '/bills',
      '/payments',
      '/attendance',
    ];
    return {
      for (final path in parentPaths) path: path.substring(1).replaceAll('-', '_'),
    };
  }

  static const _extraTablePaths = <String, String>{
    '/exams': 'exams',
    '/exam-results': 'exam_results',
    '/report-cards': 'report_cards',
    '/departments': 'departments',
    '/houses': 'houses',
    '/subjects': 'subjects',
    '/enrollments': 'enrollments',
    '/roles': 'roles',
    '/permissions': 'permissions',
    '/library-books': 'library_books',
    '/book-loans': 'book_loans',
    '/inventory-items': 'inventory_items',
    '/leave-requests': 'leave_requests',
    '/buses': 'buses',
    '/bus-routes': 'bus_routes',
    '/calendar-events': 'calendar_events',
    '/home-study-engagements': 'home_study_engagements',
    '/student-transports': 'student_transports',
  };

  /// The permission slug (from the login response's `permissions` array)
  /// that gates each extra table. Without this, every signed-in user —
  /// including a plain teacher — requested all 18 of these on every sync,
  /// and anything outside their role (departments, roles, permissions,
  /// library, buses, inventory, student transport...) came back as a
  /// console-flooding 403. A missing entry here means "don't gate it".
  static const _extraTablePermissions = <String, String>{
    '/exams': 'exams.view',
    '/exam-results': 'exam-results.view',
    '/report-cards': 'report-cards.view',
    '/houses': 'houses.view',
    '/subjects': 'subjects.view',
    '/enrollments': 'enrollments.view',
    '/roles': 'roles.view',
    '/permissions': 'roles.view',
    '/library-books': 'library-books.view',
    '/book-loans': 'book-loans.view',
    '/inventory-items': 'inventory-items.view',
    '/leave-requests': 'leave-requests.view',
    '/buses': 'buses.view',
    '/bus-routes': 'bus-routes.view',
    '/calendar-events': 'calendar-events.view',
    '/home-study-engagements': 'home-study.view',
    '/student-transports': 'student-transports.view',
  };

  /// The live API answers these with 403 "Only school staff can perform this
  /// action." for guardians, so a parent session never asks for them.
  static const _staffOnlyForParents = {'/departments', '/calendar-events', '/school'};

  /// The only extra lists the live API lets a guardian read. Everything else
  /// in [_extraTablePaths] (roles, permissions, subjects, library, buses,
  /// exam results…) answers 403 for parents, so a parent never asks.
  static const _parentExtraPaths = {'/exams', '/report-cards', '/home-study-engagements'};

  bool _parentMayFetch(String path) => _activeRole == Role.cashier
      ? path == '/calendar-events'
      : _activeRole != Role.parent || (_parentExtraPaths.contains(path) && !_staffOnlyForParents.contains(path));

  Future<void> _fillExtraTables() async {
    if (!ApiSession.instance.isSignedIn) return;
    final extrasAt = _extrasLoadedAt;
    if (extrasAt != null && DateTime.now().difference(extrasAt) < const Duration(minutes: 5)) {
      // Already loaded once: re-pull only the records staff edit on the
      // website so edits/deletes reach the app on every refresh.
      const live = ['/calendar-events', '/departments', '/exams'];
      final rawPerms = ApiSession.instance.user?['permissions'];
      final perms = rawPerms is List ? {for (final p in rawPerms) '$p'} : <String>{};
      final paths = [
        for (final p in live)
          if (_parentMayFetch(p) &&
              (perms.isEmpty || _extraTablePermissions[p] == null || perms.contains(_extraTablePermissions[p]) || _activeRole == Role.parent))
            p,
      ];
      final liveChild = _activeRole == Role.parent ? focusedChild(Role.parent) : null;
      final rows = await Future.wait([for (final p in paths) _tableOrNull(p, query: _roleQuery(p, liveChild))]);
      for (var i = 0; i < paths.length; i++) {
        final got = rows[i];
        if (got != null) tables[_extraTablePaths[paths[i]]!] = got;
      }
      _rebuildDepartments();
      notifyListeners();
      return;
    }
    final rawPermissions = ApiSession.instance.user?['permissions'];
    final permissions = rawPermissions is List ? {for (final p in rawPermissions) '$p'} : null;
    final entries = _extraTablePaths.entries.where((e) {
      if (!_parentMayFetch(e.key)) return false;
      // No permissions array at all (e.g. platform super admin) — don't gate.
      if (permissions == null || permissions.isEmpty) return true;
      final required = _extraTablePermissions[e.key];
      return required == null || permissions.contains(required);
    }).toList();
    if (entries.isEmpty) return;
    final parentChild = _activeRole == Role.parent ? focusedChild(Role.parent) : null;
    final fetched = await Future.wait([for (final e in entries) _tableOrNull(e.key, query: _roleQuery(e.key, parentChild))]);
    for (var i = 0; i < entries.length; i++) {
      final got = fetched[i];
      if (got != null) tables[entries[i].value] = got;
    }
    if (entries.any((e) => e.key == '/enrollments')) _rebuildStudents();
    _rebuildDepartments();
    _extrasLoadedAt = DateTime.now();
    notifyListeners();
  }

  DateTime? _extrasLoadedAt;

  Future<Map<String, dynamic>> _assemblePayload() async {
    final entries = _corePathsForRole().entries.toList();
    final child = _activeRole == Role.parent ? focusedChild(Role.parent) : null;
    final fetched = await Future.wait([
      for (final e in entries)
        _tableOrNull(
          e.key,
          query: _roleQuery(e.key, child),
          timeout: const Duration(seconds: 12),
        ),
    ]);
    final previous = this.tables;
    final tables = <String, dynamic>{
      for (var i = 0; i < entries.length; i++)
        entries[i].value: fetched[i] ?? previous[entries[i].value] ?? const <Map<String, dynamic>>[],
    };

    final sessionUser = ApiSession.instance.user ?? const <String, dynamic>{};
    // `/students` isn't in the parent (or teacher) path list either — same
    // "absent means null, not []" trap as `academic_years`/`academic_terms`
    // below; `as List` with no `?`/`??` threw here for every parent sync.
    // A parent's only source for their children is the profile, so always
    // take it from there: after a promotion the refreshed profile carries the
    // new class, and keeping the first copy would pin the old one forever.
    final existingStudentsTable = tables['students'];
    final parentSession = _activeRole == Role.parent;
    if ((parentSession || existingStudentsTable is! List || existingStudentsTable.isEmpty) && sessionUser['guardian'] is Map) {
      final kids = (sessionUser['guardian'] as Map)['students'];
      if (kids is List) {
        tables['students'] = [
          for (final kid in kids)
            if (kid is Map)
              {
                ...Map<String, dynamic>.from(kid),
                'status': kid['status'] ?? 'active',
              },
        ];
      }
    }
    tables['students'] ??= const <Map<String, dynamic>>[];
    // Teacher and parent sessions never fetch `/guardians` or `/staff` at all
    // (see `_corePathsForRole`), so those keys are simply absent from
    // `tables` here — casting the missing value `as List` threw a TypeError
    // that was never caught anywhere but `syncFromApi`'s catch-all, which
    // wipes everything and loads fake demo data instead. That silently
    // broke every non-admin login: real students/classes/timetable would
    // load, then get discarded in favour of "Grade 3A"/"Kwame Asante" demo
    // content a moment later.
    final existingGuardians = tables['guardians'];
    if ((existingGuardians is! List || existingGuardians.isEmpty) && sessionUser['guardian'] is Map) {
      tables['guardians'] = [Map<String, dynamic>.from(sessionUser['guardian'] as Map)];
    }
    tables['guardians'] ??= const <Map<String, dynamic>>[];
    final existingStaff = tables['staff'];
    if ((existingStaff is! List || existingStaff.isEmpty) && sessionUser['staff'] is Map) {
      tables['staff'] = [Map<String, dynamic>.from(sessionUser['staff'] as Map)];
    }
    tables['staff'] ??= const <Map<String, dynamic>>[];

    final school = (_activeRole == Role.parent ? null : await _object('/school')) ??
        (sessionUser['school'] is Map ? Map<String, dynamic>.from(sessionUser['school'] as Map) : null);
    // Root cause of "the website shows this, the app doesn't": `/academic-years`
    // and `/academic-terms` are staff-only endpoints — a parent (and a
    // teacher, whose own path list also omits them) never fetches them,
    // so `tables['academic_years']`/`tables['academic_terms']` are simply
    // absent (null), not an empty list. The old `as List` (no `?`, no `??`)
    // threw a TypeError on that null for every single parent/teacher sync,
    // straight out of `_assemblePayload()` before `applyBootstrap()` ever
    // ran — so nothing that only `applyBootstrap()` populates (message
    // threads chief among them) ever made it into the store, even though
    // the `/message-threads` request itself had already come back 200 with
    // the right data sitting unused in `tables`. Everything else on the
    // parent dashboard kept "working" only because those specific fields
    // (children, guardian info) have their own separate fallback straight
    // off the login response — messages have no such fallback.
    final years = (tables['academic_years'] as List? ?? const []).cast<Map<String, dynamic>>();
    final terms = (tables['academic_terms'] as List? ?? const []).cast<Map<String, dynamic>>();
    Map<String, dynamic>? currentYear;
    for (final year in years) {
      if (year['is_current'] == true || year['is_current'] == 1) currentYear = year;
    }
    currentYear ??= years.isEmpty ? null : years.first;
    Map<String, dynamic>? currentTerm;
    for (final term in terms) {
      if ('${term['status']}' == 'current') currentTerm = term;
    }
    currentTerm ??= terms.isEmpty ? null : terms.first;

    return {
      'school': school,
      'academic_year_id': currentYear?['id'],
      'academic_term_id': currentTerm?['id'],
      'tables': tables,
    };
  }

  Map<String, String>? _roleQuery(String path, Student? child) {
    if (child == null) return null;
    // The live API rejects a guardian's timetable request without a
    // student_id ("student_id is required"), so always send it.
    if (path == '/timetable-entries') {
      return {
        'student_id': child.id,
        if (child.classId.isNotEmpty) 'class_id': child.classId,
      };
    }
    if (path == '/assignments' || path == '/exams' || path == '/exam-results') {
      return {'student_id': child.id};
    }
    return null;
  }

  /// `/departments` arrives with the extra tables, after [applyBootstrap] has
  /// run, so both rebuild this list.
  void _rebuildDepartments() {
    departments
      ..clear()
      ..addAll([
        for (final row in tables['departments'] ?? const <Map<String, dynamic>>[])
          NamedRecord(
            id: '${row['id']}',
            name: '${row['name'] ?? ''}',
            detail: '${row['description'] ?? ''}',
            extra: '${row['status'] ?? ''}',
            link: [
              for (final head in _listOf(row['heads']))
                '${head['full_name'] ?? ''}${head['is_main'] == true || head['is_main'] == 1 ? '' : ' (assistant)'}',
            ].where((name) => name.isNotEmpty).join(', '),
          ),
      ]);
  }

  /// Rebuilds [students] from the cached `tables['students']` rows.
  ///
  /// `classId`/`klass` resolution depends on `tables['enrollments']`
  /// (see [_studentClassId]/[_studentClassName]), which is fetched
  /// separately and later by [_fillExtraTables] — on the first sync it
  /// hasn't landed yet when [applyBootstrap] first builds this list, so
  /// every student's classId comes back empty ("0 students" on every
  /// class screen even when the school database has real enrollments).
  /// Called again once enrollments arrive so classId actually resolves.
  void _rebuildStudents() {
    students
      ..clear()
      ..addAll([
        for (final row in tables['students'] ?? const <Map<String, dynamic>>[])
          () {
            final guardian = _primaryGuardianOf(row);
            return Student(
              id: '${row['id']}',
              name: _asString(row['full_name']),
              klass: _studentClassName(row),
              classId: _studentClassId(row),
              userId: _studentUserId(row),
              avatar: _asString(row['full_name']).isEmpty ? 'S' : _asString(row['full_name']),
              attendance: _attendancePercent('${row['id']}'),
              fees: 0,
              outstanding: _outstandingFor('${row['id']}'),
              status: _asString(row['status']).isEmpty ? 'active' : _asString(row['status']),
              boarder: _asString(row['residence_type']) == 'boarding',
              palmCredentialId: _asString(row['active_palm_credential_id']),
              cardNumber: _asString(row['card_number']),
              studentNumber: _studentNumber(row),
              schoolId: _asString(row['school_id']),
              schoolName: _studentSchoolName(row),
              dateOfBirth: _asString(row['date_of_birth']),
              gender: _asString(row['gender']),
              emergencyContactPhone: _asString(row['emergency_contact_phone']),
              allergies: _asString(row['allergies']),
              medicalNotes: _asString(row['medical_notes']),
              admissionDate: _asString(row['admission_date']),
              guardianName: guardian.name,
              guardianPhone: guardian.phone,
              guardianRelationship: guardian.relationship,
            );
          }(),
      ]);
  }

  void applyBootstrap(Map<String, dynamic> data) {
    if (data['school'] is Map) {
      final school = Map<String, dynamic>.from(data['school'] as Map);
      final name = _asString(school['name']);
      if (name.isNotEmpty) schoolName = name;
      schoolMotto = _asString(school['motto']);
      const logoKeys = ['logo_url', 'logo', 'logo_path', 'image_url'];
      // Only a payload that actually describes the logo may change it; a
      // trimmed school record (e.g. a parent's) must not wipe the login's.
      if (logoKeys.any(school.containsKey)) {
        schoolLogoUrl = logoKeys
            .map((key) => _asString(school[key]))
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        final id = _asString(school['id']).isNotEmpty ? _asString(school['id']) : (schoolId ?? '');
        if (schoolLogoUrl!.isEmpty && id.isNotEmpty) _dropSchoolLogo(id);
      }
      schoolCode = _asString(school['code']);
        schoolPrimaryColor = _asString(
          school['primary_color'] ?? school['theme_color'] ?? school['accent_color'] ?? school['brand_color'],
        );
      schoolAddress = _asString(school['address']);
      schoolPhone = _asString(school['phone']);
      schoolPhoneSecondary = _asString(school['phone_secondary']);
      schoolEmail = _asString(school['email']);
      schoolAccentColor = _asString(school['accent_color']);
      schoolCurrencyCode = _asString(school['currency_code']);
      schoolTimezone = _asString(school['timezone']);
      classScoreWeight = int.tryParse('${school['class_score_weight'] ?? ''}') ?? classScoreWeight;
      schoolType = _asString(school['school_type']);
      schoolStatus = _asString(school['status']);
    }
    academicYearId = data['academic_year_id']?.toString();
    academicTermId = data['academic_term_id']?.toString();
    final rawTables = data['tables'];
    tables = {
      if (rawTables is Map)
        for (final entry in rawTables.entries)
          entry.key.toString(): [
            for (final row in (entry.value as List? ?? const []))
              if (row is Map) Map<String, dynamic>.from(row),
          ],
    };

    _rebuildStudents();

    classes
      ..clear()
      ..addAll([
        for (final row in tables['school_classes'] ?? const <Map<String, dynamic>>[])
          NamedRecord(
            id: '${row['id']}',
            name: _classLabel(row),
            detail: row['house'] is Map ? _asString((row['house'] as Map)['name']) : '',
            extra: '${row['capacity'] ?? ''}',
            // Class teacher: `teachers` (live API) or `class_teacher` (newer API).
            link: row['teachers'] is List && (row['teachers'] as List).isNotEmpty && (row['teachers'] as List).first is Map
                ? _asString(((row['teachers'] as List).first as Map)['full_name'])
                : row['class_teacher'] is Map
                    ? _asString((row['class_teacher'] as Map)['full_name'])
                    : '',
            userId: row['teachers'] is List && (row['teachers'] as List).isNotEmpty && (row['teachers'] as List).first is Map
                ? _asString(((row['teachers'] as List).first as Map)['user_id'])
                : row['class_teacher'] is Map
                    ? _asString((row['class_teacher'] as Map)['user_id'])
                    : '',
          ),
      ]);

    rollMarks
      ..clear()
      ..addAll(_todayRollMarks());

    _rebuildDepartments();

    teachers
      ..clear()
      ..addAll([
        for (final row in tables['staff'] ?? const <Map<String, dynamic>>[])
          if (_asString(row['category']).toLowerCase() == 'teacher' ||
              _roleSlugs(row).contains('teacher') ||
              _asString(row['position']).toLowerCase().contains('teacher'))
            NamedRecord(
              id: '${row['id']}',
              name: '${row['full_name'] ?? ''}',
              detail: '${row['position'] ?? ''}',
              extra: row['department'] is Map ? '${(row['department'] as Map)['name'] ?? ''}' : '',
              email: '${row['email'] ?? ''}',
              phone: '${row['phone'] ?? ''}',
              userId: '${row['user_id'] ?? ''}',
            ),
      ]);

    accountants
      ..clear()
      ..addAll([
        for (final row in tables['staff'] ?? const <Map<String, dynamic>>[])
          if (_asString(row['category']) == 'accountant' ||
              _asString(row['position']).toLowerCase().contains('bursar') ||
              _roleSlugs(row).contains('bursar'))
            NamedRecord(
              id: '${row['id']}',
              name: '${row['full_name'] ?? ''}',
              detail: '${row['position'] ?? ''}',
              extra: row['department'] is Map ? '${(row['department'] as Map)['name'] ?? ''}' : '',
              email: '${row['email'] ?? ''}',
              phone: '${row['phone'] ?? ''}',
              userId: '${row['user_id'] ?? ''}',
            ),
      ]);

    parents
      ..clear()
      ..addAll([
        for (final row in tables['guardians'] ?? const <Map<String, dynamic>>[])
          NamedRecord(
            id: '${row['id']}',
            name: '${row['full_name'] ?? ''}',
            detail: [
              for (final child in _listOf(row['students'])) '${child['full_name'] ?? ''}',
            ].where((name) => name.isNotEmpty).join(', '),
            extra: '${row['relationship'] ?? ''}',
            email: '${row['email'] ?? ''}',
            phone: '${row['phone'] ?? ''}',
            userId: '${row['user_id'] ?? ''}',
            link: [
              for (final child in _listOf(row['students'])) '${child['id'] ?? ''}',
            ].where((id) => id.isNotEmpty).join(','),
          ),
      ]);

    roleAccounts
      ..clear()
      ..addAll([
        for (final row in tables['staff'] ?? const <Map<String, dynamic>>[])
          RoleAccount(
            id: '${row['id']}',
            name: '${row['full_name'] ?? ''}',
            role: _roleFromStaff(row),
            email: '${row['email'] ?? ''}',
            phone: '${row['phone'] ?? ''}',
            title: '${row['position'] ?? ''}',
          ),
        for (final row in tables['guardians'] ?? const <Map<String, dynamic>>[])
          RoleAccount(
            id: '${row['id']}',
            name: '${row['full_name'] ?? ''}',
            role: Role.parent,
            email: '${row['email'] ?? ''}',
            phone: '${row['phone'] ?? ''}',
            title: 'Guardian${_asString(row['relationship']).isEmpty ? '' : ' · ${_asString(row['relationship'])}'}',
          ),
      ]);

    invoices
      ..clear()
      ..addAll([
        for (final row in tables['bills'] ?? const <Map<String, dynamic>>[])
          invoiceFromRow(Map<String, dynamic>.from(row)),
      ]);

    academics
      ..clear()
      ..addAll([
        for (final row in tables['exam_results'] ?? const <Map<String, dynamic>>[])
          AcademicMark(
            id: '${row['id']}',
            student: row['student'] is Map ? '${(row['student'] as Map)['full_name'] ?? ''}' : '',
            klass: '',
            subject: row['exam'] is Map ? '${(row['exam'] as Map)['name'] ?? ''}' : '',
            term: '',
            score: _intOf(row['score']),
            grade: '${row['grade'] ?? ''}',
            remark: '${row['teacher_remark'] ?? ''}',
          ),
      ]);

    timetable
      ..clear()
      ..addAll([
        for (final row in tables['timetable_entries'] ?? const <Map<String, dynamic>>[])
          TimeSlot(
            id: '${row['id']}',
            classId: _relationId(row['class'] ?? row['school_class']) ?? _asString(row['class_id'] ?? row['school_class_id']),
            className: (row['class'] ?? row['school_class']) is Map
                ? _classLabel((row['class'] ?? row['school_class']) as Map)
                : _asString(row['class_name']),
            day: _weekdayLabel(row['weekday'] ?? row['day']),
            start: _timeLabel(row['start_time'] ?? row['start']),
            end: _timeLabel(row['end_time'] ?? row['end']),
            subject: _slotTitle(row),
            teacher: _relationLabel(row['teacher']) ?? _asString(row['teacher_name']),
            room: _asString(row['room'] ?? row['room_name']),
            teacherId: _asString(row['teacher_id'] ?? (row['teacher'] is Map ? (row['teacher'] as Map)['id'] : '')),
            kind: _asString(row['kind']).isEmpty ? 'lesson' : _asString(row['kind']),
          ),
      ]);

    reports
      ..clear()
      ..addAll([
        for (final row in tables['report_cards'] ?? const <Map<String, dynamic>>[])
          SchoolReport(
            id: '${row['id']}',
            title: row['student'] is Map ? '${(row['student'] as Map)['full_name'] ?? 'Report'}' : 'Report card',
            from: 'Academics',
            body: '${row['status'] ?? ''}',
            time: '${row['created_at'] ?? ''}',
            kind: 'academic',
          ),
      ]);

    final keptSubjectRecords = [
      for (final r in teacherReports)
        if (r.type == TeacherReportType.subjectRecord || r.id.startsWith('tr')) r,
    ];
    teacherReports
      ..clear()
      ..addAll([
        for (final row in tables['report_cards'] ?? const <Map<String, dynamic>>[])
          TeacherReport(
            id: '${row['id']}',
            teacher: 'Class teacher',
            subject: 'Report card',
            status: (row['published'] == true || '${row['published_at'] ?? ''}'.isNotEmpty)
                ? TeacherReportStatus.approved
                : TeacherReportStatus.submitted,
            klass: row['class'] is Map
                ? _classLabel(Map<String, dynamic>.from(row['class'] as Map))
                : (row['student'] is Map ? _studentClassName(Map<String, dynamic>.from(row['student'] as Map)) : ''),
            // The report card's own term and year, so the admin's year/term
            // filters match it (they used to be fixed at "2025/26 Term 1").
            term: row['academic_term'] is Map ? _asString((row['academic_term'] as Map)['name']) : '',
            year: row['academic_term'] is Map ? yearLabelFor(_asString((row['academic_term'] as Map)['academic_year_id'])) : '',
            section: row['class'] is Map ? _asString((row['class'] as Map)['stream']) : '',
            submittedAt: '${row['created_at'] ?? ''}',
          ),
        ...keptSubjectRecords,
      ]);

    academicReports
      ..clear()
      ..addAll(_academicReportsFromCards(tables['report_cards'] ?? const <Map<String, dynamic>>[]));

    _applyMessageThreads();

    _applyNotificationRows();
    _applyPickupTables();
    unawaited(refreshSchoolLogo());
  }

  /// Rebuilds the Messages inbox from `tables['message_threads']` (direct
  /// chats, the automatic "School System" thread) and announcements.
  void _applyMessageThreads() {
    final previousLines = {for (final m in messages) m.id: m.lines};
    final keptLocal = [
      for (final m in messages)
        if (m.id.startsWith('local-') || m.threadId.startsWith('local-') || m.id.contains('-inbox')) m,
    ];
    final apiThreads = [
      for (final row in tables['message_threads'] ?? const <Map<String, dynamic>>[])
        ChatPreview(
          id: '${row['id']}',
          threadId: '${row['id']}',
          from: _threadName(row),
          role: '${row['kind'] ?? ''}' == 'system' ? 'System' : 'Message',
          kind: '${row['kind'] ?? ''}' == 'system' ? 'system' : 'message',
          time: '${row['last_message_at'] ?? ''}',
          preview: row['latest_message'] is Map ? '${(row['latest_message'] as Map)['body'] ?? ''}' : '',
          unread: _intOf(row['unread_count']) > 0,
          unreadCount: _intOf(row['unread_count']),
          avatar: _threadName(row),
          audience: const [],
          viewerUserId: (sessionUserId ?? '').trim(),
          lines: (row['messages'] as List?)?.isNotEmpty == true
              ? [
                  for (final message in row['messages'] as List)
                    if (message is Map) _chatLineFromApi(Map<String, dynamic>.from(message)),
                ]
              // The list endpoint omits messages; keep the ones already loaded
              // so a background refresh doesn't blank an open conversation.
              : List<ChatLine>.of(previousLines['${row['id']}'] ?? const <ChatLine>[]),
        ),
      for (final row in tables['announcements'] ?? const <Map<String, dynamic>>[])
        ChatPreview(
          id: 'ann-${row['id']}',
          threadId: '${row['id']}',
          from: row['poster'] is Map ? _asString((row['poster'] as Map)['full_name']) : 'School',
          role: 'Announcement',
          time: _asString(row['posted_at'] ?? row['created_at']),
          preview: _asString(row['body']).isNotEmpty ? _asString(row['body']) : _asString(row['title']),
          unread: false,
          avatar: _asString(row['title']),
          kind: 'announcement',
          toLabel: _asString(row['audience']),
          audience: const [Role.parent, Role.teacher, Role.admin, Role.schoolAdmin],
          sentByRole: Role.schoolAdmin,
        ),
    ];
    final apiIds = {for (final m in apiThreads) m.id};
    messages
      ..clear()
      ..addAll([
        ...apiThreads,
        for (final m in keptLocal)
          if (!apiIds.contains(m.id) && !apiIds.contains(m.threadId)) m,
      ]);
    _applyPersistedReads();
  }

  void _applyNotificationRows() {
    _apiNotificationIds
      ..clear()
      ..addAll({
        for (final row in tables['notifications'] ?? const <Map<String, dynamic>>[])
          if (_asString(row['id']).isNotEmpty) _asString(row['id']),
      });
    notifications
      ..clear()
      ..addAll([
        for (final row in tables['notifications'] ?? const <Map<String, dynamic>>[])
          AppNotification(
            id: '${row['id']}',
            type: '${row['type'] ?? 'notice'}',
            title: _asString(row['body']).isNotEmpty ? _asString(row['title']) : '',
            text: _asString(row['body']).isNotEmpty ? _asString(row['body']) : _asString(row['title']),
            time: '${row['created_at'] ?? ''}',
            icon: _noticeIcon(_asString(row['type'])),
            color: _pickupNoticeColor(_asString(row['type'])),
            unread: row['read_at'] == null,
          ),
      ]);
  }

  String _noticeIcon(String type) {
    if (type.contains('pickup')) return 'shield';
    if (type == 'attendance_checked_in') return 'check';
    if (type.startsWith('attendance')) return 'calendar';
    if (type.contains('announcement')) return 'megaphone';
    if (type.contains('message')) return 'msg';
    if (type.contains('payment') || type.contains('bill') || type.contains('fee')) return 'dollar';
    if (type.contains('report') || type.contains('exam') || type.contains('result')) return 'book';
    return 'bell';
  }

  String _pickupNoticeColor(String type) {
    if (type == 'attendance_checked_in') return 'emerald';
    if (type == 'attendance_late') return 'honey';
    if (type == 'attendance_absent') return 'rose';
    if (type.contains('released') || type.contains('confirmed')) return 'emerald';
    if (type.contains('failed') || type.contains('rejected') || type.contains('revoked')) return 'rose';
    if (type.contains('pickup')) return 'honey';
    return 'slate';
  }

  DelegateStatus _delegateStatus(String raw) {
    return switch (raw.toLowerCase()) {
      'authorised' || 'authorized' || 'active' => DelegateStatus.authorised,
      'used' => DelegateStatus.used,
      'rejected' || 'declined' => DelegateStatus.rejected,
      'revoked' => DelegateStatus.revoked,
      _ => DelegateStatus.pending,
    };
  }

  void _applyPickupTables() {
    pickupDelegates
      ..clear()
      ..addAll([
        for (final row in tables['pickup_delegates'] ?? const <Map<String, dynamic>>[])
          PickupDelegate(
            id: '${row['id']}',
            studentId: '${row['student_id'] ?? ''}',
            studentName: _asString(row['student_name']).isEmpty && row['student'] is Map
                ? _asString((row['student'] as Map)['full_name'])
                : _asString(row['student_name']),
            klass: _asString(row['klass']),
            name: _asString(row['name']),
            relation: _asString(row['relation']),
            phone: _asString(row['phone']),
            until: _asString(row['valid_until']).isEmpty ? _asString(row['until']) : _asString(row['valid_until']),
            requestedBy: _asString(row['requested_by']),
            status: _delegateStatus(_asString(row['status'])),
            confirmPayload: _asString(row['confirm_payload']).isEmpty ? null : _asString(row['confirm_payload']),
            confirmOtc: _asString(row['confirm_otc']).isEmpty
                ? (_asString(row['otc']).isEmpty ? null : _asString(row['otc']))
                : _asString(row['confirm_otc']),
            pickupDate: _asString(row['pickup_date']).isEmpty ? null : _asString(row['pickup_date']),
            pickupTime: _asString(row['pickup_time']).isEmpty ? null : _asString(row['pickup_time']),
            schoolName: _asString(row['school_name']),
            payload: _asString(row['payload']).isEmpty ? null : _asString(row['payload']),
            usedAt: row['used_at']?.toString(),
          ),
      ]);
    pickupPasses
      ..clear()
      ..addAll([
        for (final row in tables['pickup_passes'] ?? const <Map<String, dynamic>>[])
          PickupPass(
            token: _asString(row['token']),
            studentId: '${row['student_id'] ?? ''}',
            studentName: _asString(row['student_name']).isEmpty && row['student'] is Map
                ? _asString((row['student'] as Map)['full_name'])
                : _asString(row['student_name']),
            klass: _asString(row['klass']),
            parentName: _asString(row['parent_name']),
            pickerName: _asString(row['picker_name']),
            pickerRole: _asString(row['picker_role']),
            kind: _asString(row['kind']).isEmpty ? 'parent' : _asString(row['kind']),
            expiresAt: DateTime.tryParse(_asString(row['expires_at'])) ?? DateTime.now().add(const Duration(minutes: 5)),
            delegateId: '${row['delegate_id'] ?? row['pickup_delegate_id'] ?? ''}'.isEmpty
                ? null
                : '${row['delegate_id'] ?? row['pickup_delegate_id']}',
            used: row['used_at'] != null,
            apiPayload: _asString(row['payload']).isEmpty ? null : _asString(row['payload']),
            palmCredentialId: _asString(row['palm_credential_id']).isEmpty ? null : _asString(row['palm_credential_id']),
            cardNumber: _asString(row['card_number']).isEmpty ? null : _asString(row['card_number']),
            otc: _asString(row['otc']).isEmpty ? null : _asString(row['otc']),
          ),
      ]);
    pickupLogs
      ..clear()
      ..addAll([
        for (final row in tables['pickup_logs'] ?? const <Map<String, dynamic>>[])
          PickupLog(
            id: '${row['id']}',
            studentName: _asString(row['student_name']).isEmpty && row['student'] is Map
                ? _asString((row['student'] as Map)['full_name'])
                : _asString(row['student_name']),
            klass: _asString(row['klass']),
            pickerName: _asString(row['picker_name']),
            pickerRole: _asString(row['picker_role']),
            kind: _asString(row['kind']),
            gate: _asString(row['gate']),
            officer: _asString(row['officer_name']).isEmpty ? _asString(row['officer']) : _asString(row['officer_name']),
            time: _asString(row['time']).isEmpty ? _asString(row['released_at']) : _asString(row['time']),
            schoolName: _asString(row['school_name']),
          ),
      ]);
  }

  Future<void> loadThreadMessages(String threadId) async {
    if (!ApiSession.instance.isSignedIn || threadId.isEmpty || !_isApiThreadId(threadId)) return;
    try {
      final data = _unwrap(await ApiClient.instance.get('/message-threads/$threadId'));
      if (data is! Map) return;
      final rows = data['messages'];
      if (rows is! List) return;
      final lines = [
        for (final row in rows)
          if (row is Map) _chatLineFromApi(Map<String, dynamic>.from(row)),
      ];
      final keys = <String>{threadId};
      var preview = '';
      for (final m in messages) {
        if (m.id == threadId || m.threadId == threadId) {
          m.lines
            ..clear()
            ..addAll(lines);
          m.unread = false;
          m.unreadCount = 0;
          if (lines.isNotEmpty) {
            m.preview = lines.last.body;
            m.time = lines.last.time;
          }
          keys.add(m.id);
          if (m.threadId.isNotEmpty) keys.add(m.threadId);
          if (preview.isEmpty) preview = m.preview;
        }
      }
      await _rememberThreadRead(keys: keys, preview: preview);
      notifyListeners();
    } catch (_) {}
  }

  ChatLine _chatLineFromApi(Map<String, dynamic> row) {
    final sender = row['sender'] is Map ? Map<String, dynamic>.from(row['sender'] as Map) : const <String, dynamic>{};
    final staff = _asString(sender['staff_name']);
    final guardian = _asString(sender['guardian_name']);
    final from = staff.isNotEmpty
        ? staff
        : guardian.isNotEmpty
            ? guardian
            : _asString(sender['email']).isNotEmpty
                ? _asString(sender['email'])
                : 'Staff';
    final system = row['system'] == true;
    final meta = row['meta'] is Map ? Map<String, dynamic>.from(row['meta'] as Map) : const <String, dynamic>{};
    return ChatLine(
      id: '${row['id'] ?? ''}',
      senderId: '${row['sender_id'] ?? sender['id'] ?? ''}',
      system: system,
      category: _asString(meta['category']),
      from: system ? 'School System' : from,
      body: _asString(row['body']),
      time: _asString(row['sent_at']).isNotEmpty ? _asString(row['sent_at']) : _asString(row['created_at']),
      role: staff.isNotEmpty ? Role.teacher : Role.parent,
      edited: _asString(row['updated_at']).isNotEmpty &&
          _asString(row['created_at']).isNotEmpty &&
          _asString(row['updated_at']) != _asString(row['created_at']),
    );
  }

  List<AcademicReport> _academicReportsFromCards(List<Map<String, dynamic>> rows) {
    final grouped = <String, AcademicReport>{};
    for (final raw in rows) {
      final row = _mapOf(raw);
      final student = _mapOf(row['student']);
      final klass = row['class'] is Map
          ? _classLabel(_mapOf(row['class']))
          : _studentClassName(student);
      final termMap = _mapOf(row['academic_term']);
      final term = _asString(termMap['name']);
      final yearMap = _mapOf(termMap['academic_year']);
      final year = yearMap.isNotEmpty ? _yearLabelOf(yearMap) : yearLabelFor(_asString(termMap['academic_year_id']));
      final published = row['published'] == true || _asString(row['published_at']).isNotEmpty;
      var classScore = 0;
      var examScore = 0;
      var count = 0;
      var grade = '';
      final subjectMarks = <ReportSubjectMark>[];
      for (final item in _listOf(row['lines'])) {
          final map = _mapOf(item);
          var cs = _intOf(map['class_score']);
          var es = _intOf(map['exam_score']);
          final score = _intOf(map['score']);
          if (cs == 0 && es == 0 && score > 0) {
            es = score;
          }
          count++;
          classScore += cs;
          examScore += es;
          final subject = _mapOf(map['subject']);
          final subjectName = _asString(subject['name']).isNotEmpty ? _asString(subject['name']) : _asString(map['subject']);
          final lineGrade = _asString(map['grade']);
          if (grade.isEmpty) grade = lineGrade;
          final mark = ReportSubjectMark(
            subject: subjectName.isEmpty ? 'Subject $count' : subjectName,
            subjectId: _asString(map['subject_id'] ?? subject['id']),
            classScore: cs,
            examScore: es,
            grade: lineGrade.isEmpty ? '—' : lineGrade,
            remark: _asString(map['remark']),
          );
          if (mark.remark.isEmpty) mark.syncRemark();
          subjectMarks.add(mark);
      }
      if (count > 0) {
        classScore = (classScore / count).round();
        examScore = (examScore / count).round();
      }
      final line = ReportLine(
        studentId: '${row['student_id'] ?? student['id'] ?? ''}',
        student: _asString(student['full_name']),
        cardId: '${row['id'] ?? ''}',
        published: published,
        classScore: classScore,
        examScore: examScore,
        grade: grade.isEmpty ? '—' : grade,
        remark: _asString(row['teacher_remark']),
        headteacherRemark: _asString(row['headteacher_remark']),
        bill: billLabelFor(_asString(student['full_name'])),
        promote: _asString(row['promotion_status']).toLowerCase().contains('promot') ? true : null,
        promotedTo: _asString(row['promotion_status']),
        attendanceMade: '${row['attendance_days_attended'] ?? ''}',
        attendanceOutOf: '${row['attendance_days_available'] ?? ''}',
        subjects: subjectMarks,
      );
      final key = '${klass.isEmpty ? 'Class' : klass}|${term.isEmpty ? 'Term' : term}';
      final existing = grouped[key];
      final teacherName = () {
        final staff = ApiSession.instance.user?['staff'];
        if (staff is Map) {
          final name = _asString(staff['full_name']);
          if (name.isNotEmpty) return name;
        }
        return 'Class teacher';
      }();
      if (existing == null) {
        grouped[key] = AcademicReport(
          id: key,
          klass: klass.isEmpty ? 'Class' : klass,
          term: term.isEmpty ? 'Term' : term,
          year: year.isEmpty ? '' : year,
          teacher: teacherName,
          status: published ? 'sent_to_parent' : 'sent_to_admin',
          submittedAt: _asString(row['created_at']),
          classId: _studentClassId(student),
          termId: _asString(row['academic_term_id'] ?? termMap['id']),
          yearId: _asString(yearMap['id']),
          lines: [line],
        );
      } else {
        existing.lines.add(line);
        existing.status = existing.lines.every((item) => item.published) ? 'sent_to_parent' : 'sent_to_admin';
      }
    }
    return grouped.values.toList();
  }

  String _threadName(Map<String, dynamic> row) {
    if ('${row['kind'] ?? ''}' == 'system') return 'School System';
    final me = ApiSession.instance.user?['id']?.toString() ?? '';
    final participants = row['participants'];
    if (participants is List && participants.isNotEmpty) {
      for (final raw in participants) {
        if (raw is! Map) continue;
        if (me.isNotEmpty && '${raw['user_id']}' == me) continue;
        final name = '${raw['guardian_name'] ?? raw['staff_name'] ?? raw['email'] ?? ''}';
        if (name.trim().isNotEmpty) return name;
      }
      final first = participants.first;
      if (first is Map) {
        return '${first['guardian_name'] ?? first['staff_name'] ?? first['email'] ?? 'Chat'}';
      }
    }
    if (row['student'] is Map) return '${(row['student'] as Map)['full_name'] ?? 'Chat'}';
    return 'Chat';
  }

  Role _roleFromStaff(Map<String, dynamic> row) {
    final roles = row['roles'];
    if (roles is List) {
      final slugs = [
        for (final role in roles) role is Map ? '${role['slug']}' : '$role',
      ];
      if (slugs.contains('school_admin')) return Role.schoolAdmin;
      if (slugs.contains('deputy_admin')) return Role.admin;
      if (slugs.contains('teacher')) return Role.teacher;
      if (slugs.contains('bursar') || slugs.contains('cashier')) return Role.accountant;
    }
    return Role.teacher;
  }

  void openCatalog(String key, String title) {
    catalogKey = key;
    catalogTitle = title;
  }

  void clear() {
    stopLiveSync();
    dashboardSummary = null;
    _extrasLoadedAt = null;
    _cachedSchool = null;
    unawaited(_forgetCachedPayloads());
    students.clear();
    classes.clear();
    teachers.clear();
    departments.clear();
    parents.clear();
    roleAccounts.clear();
    invoices.clear();
    childFeeSummary.clear();
    accountants.clear();
    academics.clear();
    timetable.clear();
    reports.clear();
    teacherReports.clear();
    academicReports.clear();
    rollMarks.clear();
    // Keep chats/notices across re-login so parent/teacher/admin can verify
    // send + receive in the same demo session. Read receipts stay in prefs.
    tables = {};
    _apiNotificationIds.clear();
    schoolId = null;
    schoolName = null;
    schoolMotto = null;
    schoolLogoUrl = null;
    _logoRefused.clear();
    schoolCode = null;
    schoolAddress = null;
    schoolPhone = null;
    schoolPhoneSecondary = null;
    schoolEmail = null;
    schoolAccentColor = null;
    schoolCurrencyCode = null;
    schoolTimezone = null;
    schoolType = null;
    schoolStatus = null;
    syncError = null;
    reportCardsError = null;
    loading = false;
    _activeEmail = null;
    _activeRole = null;
    _activeDailyReportsEligible = false;
    focusedChildId = '';
    focusedClassId = '';
    MessageReadPrefs.instance.resetMemory();
    notifyListeners();
  }

  String _asString(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return '${value['value'] ?? value['name'] ?? value['slug'] ?? value['full_name'] ?? ''}';
    }
    return '$value';
  }

  String _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = _asString(value).trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  List<String> _roleSlugs(Map<String, dynamic> row) {
    final roles = row['roles'];
    if (roles is! List) return const [];
    return [
      for (final role in roles) role is Map ? _asString(role['slug']) : _asString(role),
    ];
  }

  /// True when a timetable slot belongs to [child]'s class — by class id when
  /// both sides have one, otherwise by class name ignoring case/spaces
  /// ("JHS 1 A" == "JHS 1A").
  bool slotMatchesChild(TimeSlot slot, Student child) {
    if (child.classId.isNotEmpty && slot.classId.isNotEmpty) return slot.classId == child.classId;
    String norm(String v) => v.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (child.klass.isEmpty || slot.className.isEmpty) return false;
    return norm(slot.className) == norm(child.klass);
  }

  String _classLabel(Map row) {
    final name = _asString(row['name']);
    final stream = _asString(row['stream']);
    if (stream.isEmpty) return name;
    return '$name $stream';
  }

  String _studentSchoolName(Map<String, dynamic> row) {
    if (row['school'] is Map) {
      final name = _asString((row['school'] as Map)['name']);
      if (name.isNotEmpty) return name;
    }
    return _asString(row['school_name']);
  }

  /// The API returns a `guardians` array per student (confirmed live) with
  /// `is_primary_contact` flagging which one to lead with — falls back to
  /// the first guardian if none is flagged.
  ({String name, String phone, String relationship}) _primaryGuardianOf(Map<String, dynamic> row) {
    final guardians = _listOf(row['guardians']);
    if (guardians.isEmpty) return (name: '', phone: '', relationship: '');
    final primary = guardians.firstWhere(
      (g) => g['is_primary_contact'] == true,
      orElse: () => guardians.first,
    );
    return (
      name: _asString(primary['full_name']),
      phone: _asString(primary['phone']),
      relationship: _asString(primary['relationship']),
    );
  }

  String _studentClassName(Map<String, dynamic> row) {
    // Prefer the enrollment's class record: it's formatted the same way
    // (`name` + `stream`, e.g. "Class 1 A") as every class list/filter
    // elsewhere in the app. The API's own `current_class` field is a
    // separate denormalized string (e.g. "Class 1A", no space) that never
    // matches those — falling back to it only when there's no enrollment
    // match avoids silently breaking class-roster matching app-wide.
    for (final item in _listOf(row['enrollments'])) {
      if (item['class'] is Map) return _classLabel(_mapOf(item['class']));
    }
    for (final enrollment in tables['enrollments'] ?? const <Map<String, dynamic>>[]) {
      if (_enrollmentStudentId(enrollment) != '${row['id']}') continue;
      if (enrollment['class'] is Map) return _classLabel(enrollment['class'] as Map);
    }
    return _asString(row['current_class']);
  }

  String _studentClassId(Map<String, dynamic> row) {
    for (final item in _listOf(row['enrollments'])) {
      final id = item['class_id'] ?? (item['class'] is Map ? item['class']['id'] : null);
      if (id != null) return '$id';
    }
    for (final enrollment in tables['enrollments'] ?? const <Map<String, dynamic>>[]) {
      if (_enrollmentStudentId(enrollment) != '${row['id']}') continue;
      final id = enrollment['class_id'] ?? (enrollment['class'] is Map ? (enrollment['class'] as Map)['id'] : null);
      if (id != null) return '$id';
    }
    // A guardian session has no `/enrollments` table at all (staff-only
    // endpoint) — its only source for a child's class is this top-level
    // `class_id`, added straight onto each guardian.students entry
    // specifically so Daily Reports (which need a real class UUID, not
    // just the class *name* `_studentClassName` already falls back to)
    // work for parents too.
    return _asString(row['class_id']);
  }

  String _studentUserId(Map<String, dynamic> row) {
    final direct = _asString(row['user_id']);
    if (direct.isNotEmpty) return direct;
    if (row['user'] is Map) return _asString((row['user'] as Map)['id']);
    return '';
  }

  String _enrollmentStudentId(Map<String, dynamic> enrollment) {
    if (enrollment['student_id'] != null) return '${enrollment['student_id']}';
    if (enrollment['student'] is Map) return '${(enrollment['student'] as Map)['id'] ?? ''}';
    return '';
  }

  int _outstandingFor(String studentId) {
    var total = 0;
    for (final bill in tables['bills'] ?? const <Map<String, dynamic>>[]) {
      final id = '${bill['student_id'] ?? (bill['student'] is Map ? (bill['student'] as Map)['id'] : '')}';
      if (id != studentId) continue;
      final status = _asString(bill['status']).toLowerCase();
      if (status == 'paid' || status == 'cancelled') continue;
      total += _moneyOf(bill['balance'] ?? bill['total_amount'] ?? bill['amount']).round();
    }
    return total;
  }

  int _attendancePercent(String studentId) {
    final rows = [
      for (final row in tables['attendance'] ?? const <Map<String, dynamic>>[])
        if ('${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}' == studentId) row,
    ];
    if (rows.isEmpty) return 0;
    final present = rows.where((row) {
      final status = _asString(row['status']).toLowerCase();
      return status == 'present' || status == 'late' || status == 'early_departure';
    }).length;
    return ((present / rows.length) * 100).round();
  }

  String _billStatusLabel(String status) {
    return switch (status.toLowerCase()) {
      'unpaid' => 'due',
      'partial' => 'partial',
      'paid' => 'paid',
      'overdue' => 'overdue',
      'cancelled' => 'cancelled',
      _ => status.isEmpty ? 'due' : status,
    };
  }

  String _billStatusApi(String status) {
    return switch (status.toLowerCase()) {
      'due' || 'unpaid' => 'unpaid',
      'paid' => 'paid',
      'overdue' => 'overdue',
      _ => 'unpaid',
    };
  }

  String _weekdayLabel(dynamic value) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    if (value is num && value >= 1 && value <= 7) return days[value.toInt()];
    final text = _asString(value).trim();
    final asInt = int.tryParse(text);
    if (asInt != null && asInt >= 1 && asInt <= 7) return days[asInt];
    if (text.isEmpty) return '';
    final normalized = text.toLowerCase();
    const aliases = {
      'mon': 'Monday',
      'tue': 'Tuesday',
      'tues': 'Tuesday',
      'wed': 'Wednesday',
      'thu': 'Thursday',
      'thur': 'Thursday',
      'thurs': 'Thursday',
      'fri': 'Friday',
      'sat': 'Saturday',
      'sun': 'Sunday',
    };
    return aliases[normalized] ??
        (normalized[0].toUpperCase() + normalized.substring(1));
  }

  String? _relationId(dynamic value) {
    if (value is Map) return _asString(value['id']);
    final text = _asString(value);
    return text.isEmpty ? null : text;
  }

  String? _relationLabel(dynamic value) {
    if (value is Map) {
      final text = _asString(value['name'] ?? value['full_name'] ?? value['title']);
      return text.isEmpty ? null : text;
    }
    final text = _asString(value);
    return text.isEmpty ? null : text;
  }

  /// Same naming as the website: breaks and lunch by name, lessons by subject.
  String _slotTitle(Map<String, dynamic> row) {
    final kind = _asString(row['kind']);
    if (kind == 'break') return 'Break';
    if (kind == 'lunch') return 'Lunch';
    return _relationLabel(row['subject']) ?? _asString(row['subject_name']);
  }

  /// Minutes after midnight for "08:00", "8:00", "1:05 PM"... so periods
  /// sort by real time (like the website), not as text.
  static int slotMinutes(String raw) {
    final m = RegExp(r'(\d{1,2})[:.](\d{2})\s*([AaPp][Mm])?').firstMatch(raw);
    if (m == null) return 24 * 60;
    var h = int.parse(m[1]!);
    final ampm = m[3]?.toLowerCase();
    if (ampm == 'pm' && h < 12) h += 12;
    if (ampm == 'am' && h == 12) h = 0;
    return h * 60 + int.parse(m[2]!);
  }

  static const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// One day's periods, in time order.
  static List<TimeSlot> slotsForDay(Iterable<TimeSlot> slots, String day) =>
      [for (final s in slots) if (s.day == day) s]..sort((a, b) => slotMinutes(a.start).compareTo(slotMinutes(b.start)));

  /// The signed-in teacher's own lessons (the website's "mine" view).
  List<TimeSlot> get myTimetable {
    final me = (sessionStaffId ?? '').trim();
    if (me.isEmpty) return List<TimeSlot>.of(timetable);
    return [for (final s in timetable) if (s.teacherId == me) s];
  }

  String _timeLabel(dynamic value) {
    final text = _asString(value);
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map && response['data'] != null) return response['data'];
    return response;
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map) {
      if (value['data'] is Map) return Map<String, dynamic>.from(value['data'] as Map);
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listOf(dynamic value) {
    final data = value is Map && value['data'] != null ? value['data'] : value;
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  NamedRecord? _classByName(String name) {
    for (final item in classes) {
      if (item.name == name) return item;
    }
    return null;
  }

  Student? _studentByName(String name) {
    for (final item in students) {
      if (item.name == name) return item;
    }
    return null;
  }

  NamedRecord? _staffByName(String name) {
    for (final item in [...teachers, ...accountants]) {
      if (item.name == name) return item;
    }
    return null;
  }

  NamedRecord? _departmentByName(String name) {
    for (final item in departments) {
      if (item.name == name) return item;
    }
    return null;
  }

  String _today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Map<String, String> _todayRollMarks() {
    final today = _today();
    final marks = <String, String>{};
    for (final row in tables['attendance'] ?? const <Map<String, dynamic>>[]) {
      final date = _asString(row['date']);
      if (date.isNotEmpty && !date.startsWith(today)) continue;
      final id = '${row['student_id'] ?? (row['student'] is Map ? (row['student'] as Map)['id'] : '')}';
      if (id.isEmpty) continue;
      marks[id] = _attendanceUi(_asString(row['status']));
    }
    return marks;
  }

  String _attendanceUi(String status) {
    final value = status.toLowerCase();
    // Same buckets as the website's attendance summary: excused stays
    // excused and left-early is its own status, not "absent".
    if (value == 'late') return 'late';
    if (value == 'absent') return 'absent';
    if (value == 'early_departure') return 'left_early';
    if (value == 'excused' || value == 'authorized_absence' || value == 'excuse') return 'excused';
    return 'present';
  }

  String _attendanceApi(String status) {
    return switch (status) {
      'late' => 'late',
      'absent' => 'absent',
      'excused' => 'authorized_absence',
      _ => 'present',
    };
  }

  String _guardianRelationship(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('mother') || lower == 'mom') return 'mother';
    if (lower.contains('father') || lower == 'dad') return 'father';
    return 'guardian';
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    try {
      await action();
      // The write already succeeded on the server by this point — the only
      // thing left is refreshing the local copy so the UI shows it. The
      // default syncFromApi() budget (3s) was too tight for admin's full
      // sync (15+ endpoints on a server that runs ~1.2-1.4s per request):
      // on any edit that took a bit longer, this silently timed out,
      // `catch (_)` never re-ran `applyBootstrap`, and the screen kept
      // showing pre-edit data while still reporting the save as a success.
      await syncFromApi(budget: const Duration(seconds: 20));
      return true;
    } on ApiException catch (error) {
      syncError = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      syncError = 'Could not save this record to the school API.';
      notifyListeners();
      return false;
    }
  }

  void updateTeacherReportStatus(String reportId, TeacherReportStatus status) {
    final index = teacherReports.indexWhere((r) => r.id == reportId);
    if (index >= 0) {
      teacherReports[index].status = status;
      notifyListeners();
    }
  }

  void addInvoice(Invoice invoice) {
    invoices.add(invoice);
    notifyListeners();
  }

  void updateStudent(Student student) {
    final index = students.indexWhere((s) => s.id == student.id);
    if (index >= 0) {
      students[index] = student;
      notifyListeners();
    }
  }

  Future<bool> deleteStudent(String studentId) {
    return _mutate(() async {
      await ApiClient.instance.delete('/students/$studentId');
    });
  }

  Future<bool> upsertStudent(Student student) {
    return _mutate(() async {
      final body = {
        'full_name': student.name,
        'status': const ['active', 'graduated', 'withdrawn'].contains(student.status) ? student.status : 'active',
        'residence_type': student.boarder ? 'boarding' : 'day',
        if (student.id.isEmpty) 'auto_generate_admission_number': true,
        // The API's update validation requires admission_number even though
        // it's never edited in this form — confirmed live: PUT/PATCH
        // /students/{id} both 422 with "The admission number field is
        // required." when it's left out. Existing students already have one.
        if (student.id.isNotEmpty && student.studentNumber.trim().isNotEmpty)
          'admission_number': student.studentNumber.trim(),
        if (student.dateOfBirth.trim().isNotEmpty) 'date_of_birth': student.dateOfBirth.trim(),
        if (student.gender.trim().isNotEmpty) 'gender': student.gender.trim(),
        if (student.emergencyContactPhone.trim().isNotEmpty)
          'emergency_contact_phone': student.emergencyContactPhone.trim(),
        if (student.allergies.trim().isNotEmpty) 'allergies': student.allergies.trim(),
        if (student.medicalNotes.trim().isNotEmpty) 'medical_notes': student.medicalNotes.trim(),
      };
      dynamic created;
      if (student.id.isEmpty) {
        created = _unwrap(await ApiClient.instance.post('/students', body));
      } else {
        created = _unwrap(await ApiClient.instance.put('/students/${student.id}', body));
      }
      final studentId = created is Map ? '${created['id'] ?? student.id}' : student.id;
      final classRecord = _classByName(student.klass);
      if (studentId.isNotEmpty && classRecord != null && academicYearId != null) {
        // Editing an existing student used to only create an enrollment the
        // first time — changing the Class dropdown on an already-enrolled
        // student silently did nothing. Now we also move their existing
        // enrollment when the chosen class actually changed.
        final currentEnrollment = (tables['enrollments'] ?? const <Map<String, dynamic>>[])
            .where((row) => _enrollmentStudentId(row) == studentId)
            .firstOrNull;
        final currentClassId = currentEnrollment == null
            ? ''
            : '${currentEnrollment['class_id'] ?? (currentEnrollment['class'] is Map ? (currentEnrollment['class'] as Map)['id'] : '')}';
        if (currentEnrollment == null) {
          await ApiClient.instance.post('/enrollments', {
            'student_id': studentId,
            'academic_year_id': academicYearId,
            'class_id': classRecord.id,
            'enrollment_date': _today(),
            'status': 'active',
          });
        } else if (currentClassId != classRecord.id) {
          final enrollmentId = '${currentEnrollment['id'] ?? ''}';
          if (enrollmentId.isNotEmpty) {
            await ApiClient.instance.put('/enrollments/$enrollmentId', {
              'student_id': studentId,
              'academic_year_id': currentEnrollment['academic_year_id'] ?? academicYearId,
              'class_id': classRecord.id,
              'enrollment_date': _asString(currentEnrollment['enrollment_date']).isEmpty
                  ? _today()
                  : currentEnrollment['enrollment_date'],
              'status': _asString(currentEnrollment['status']).isEmpty ? 'active' : currentEnrollment['status'],
            });
          }
        }
      }
    });
  }

  Future<bool> deleteInvoice(String invoiceId) {
    return _mutate(() async {
      await ApiClient.instance.delete('/bills/$invoiceId');
    });
  }

  Future<bool> upsertInvoice(Invoice invoice) {
    return _mutate(() async {
      final student = _studentByName(invoice.student);
      final studentId = invoice.studentId.isNotEmpty ? invoice.studentId : (student?.id ?? '');
      if (studentId.isEmpty) {
        throw ApiException('Choose a student before creating a bill.');
      }
      final body = {
        'student_id': studentId,
        if (academicTermId != null) 'academic_term_id': academicTermId,
        'title': invoice.description.isEmpty ? 'School fees' : invoice.description,
        'issued_date': _today(),
        'status': _billStatusApi(invoice.status),
        'category': 'school_fees',
        'line_items': [
          {
            'label': invoice.description.isEmpty ? 'School fees' : invoice.description,
            'amount': invoice.amount <= 0 ? 1 : invoice.amount,
            'category': 'school_fees',
          },
        ],
      };
      if (invoice.id.isEmpty) {
        await ApiClient.instance.post('/bills', body);
      } else {
        await ApiClient.instance.put('/bills/${invoice.id}', body);
      }
    });
  }

  Future<bool> saveAttendance(String klass, Map<String, String> attendance) async {
    // Never report a roll as saved unless the server has it: this used to
    // return "saved" when the school year hadn't loaded, so the app showed
    // marks the database and website never got.
    if (!ApiSession.instance.isSignedIn) {
      syncError = 'Sign in to submit attendance.';
      notifyListeners();
      return false;
    }
    if (academicYearId == null || academicYearId!.isEmpty) {
      syncError = 'The school year has not loaded yet. Pull down to refresh, then submit again.';
      notifyListeners();
      return false;
    }
    final ok = await _mutate(() async {
      final byClass = <String, List<Map<String, String>>>{};
      for (final entry in attendance.entries) {
        Student? student;
        for (final item in students) {
          if (item.id == entry.key) {
            student = item;
            break;
          }
        }
        if (student == null) continue;
        var classId = student.classId;
        if (classId.isEmpty) {
          classId = _classByName(student.klass.isEmpty ? klass : student.klass)?.id ?? '';
        }
        if (classId.isEmpty) continue;
        byClass.putIfAbsent(classId, () => []).add({
          'student_id': student.id,
          'status': _attendanceApi(entry.value),
        });
      }
      if (byClass.isEmpty) {
        throw ApiException('No students in this class could be saved.');
      }
      for (final entry in byClass.entries) {
        await ApiClient.instance.post('/attendance/class-register', {
          'class_id': entry.key,
          'academic_year_id': academicYearId,
          'date': _today(),
          'records': entry.value,
        });
      }
    });
    if (ok) {
      rollMarks.addAll(attendance);
      notifyListeners();
    }
    return ok;
  }

  static String sectionOf(String klass) {
    final match = RegExp(r'([A-C])$').firstMatch(klass.trim());
    return match?.group(1) ?? '';
  }

  int studentsIn(String klass) => students.where((s) => s.klass == klass).length;

  ExamStats examStatsFor({required String klass, required String subject, required String term}) {
    final marks = academics
        .where((m) => m.klass == klass && m.subject == subject && m.term == term)
        .toList();
    if (marks.isEmpty) {
      return const ExamStats(wrote: 0, passed: 0, failed: 0, highest: 0, lowest: 0, average: 0);
    }
    final scores = marks.map((m) => m.score).toList();
    final passed = scores.where((s) => s >= 50).length;
    return ExamStats(
      wrote: scores.length,
      passed: passed,
      failed: scores.length - passed,
      highest: scores.reduce((a, b) => a > b ? a : b),
      lowest: scores.reduce((a, b) => a < b ? a : b),
      average: scores.reduce((a, b) => a + b) / scores.length,
    );
  }

  void upsertMark(AcademicMark mark, {bool isNew = false}) {
    if (isNew || mark.id.isEmpty) {
      mark.id = 'm${DateTime.now().millisecondsSinceEpoch}';
      academics.add(mark);
    } else {
      final index = academics.indexWhere((item) => item.id == mark.id);
      if (index >= 0) {
        academics[index] = mark;
      } else {
        academics.add(mark);
      }
    }
    notifyListeners();
  }

  void deleteMark(String id) {
    academics.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  /// "7:30", "07:30", "7:30 PM" or "07:30:00" → "07:30:00" (the API's
  /// format); empty when it isn't a time.
  static String apiTime(String raw) {
    final m = RegExp(r'^(\d{1,2})[:.](\d{2})(?::\d{2})?\s*([AaPp][Mm])?$').firstMatch(raw.trim());
    if (m == null) return '';
    var h = int.parse(m[1]!);
    final min = int.parse(m[2]!);
    final ampm = m[3]?.toLowerCase();
    if (ampm == 'pm' && h < 12) h += 12;
    if (ampm == 'am' && h == 12) h = 0;
    if (h > 23 || min > 59) return '';
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:00';
  }

  /// Saves a timetable period on the school server (so it also shows on the
  /// website), then reloads. Returns '' on success, otherwise the reason.
  Future<String> saveTimetableSlot(TimeSlot slot) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in to save the timetable.';
    const weekdays = {'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4, 'Friday': 5, 'Saturday': 6, 'Sunday': 7};
    final classId = slot.classId.isNotEmpty
        ? slot.classId
        : classes.where((c) => c.name == slot.className).firstOrNull?.id ?? '';
    final subjectId = subjectRecords.where((s) => s.name == slot.subject).firstOrNull?.id ?? '';
    final teacherId = _staffByName(slot.teacher)?.id ?? '';
    final start = apiTime(slot.start);
    final end = apiTime(slot.end);
    if (classId.isEmpty) return 'Choose a class.';
    if (subjectId.isEmpty) return 'Choose a subject. Subjects are set up on the school website.';
    if (teacherId.isEmpty) return 'Choose a teacher.';
    if (start.isEmpty || end.isEmpty) return 'Enter the times like 07:30 and 08:15.';
    if (end.compareTo(start) <= 0) return 'The period must end after it starts.';
    final body = {
      'class_id': classId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'weekday': weekdays[slot.day] ?? 1,
      'start_time': start,
      'end_time': end,
      'room': slot.room.trim().isEmpty ? null : slot.room.trim(),
    };
    try {
      if (slot.id.isEmpty) {
        await ApiClient.instance.post('/timetable-entries', body);
      } else {
        await ApiClient.instance.put('/timetable-entries/${slot.id}', body);
      }
      await syncFromApi(budget: const Duration(seconds: 20));
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not save the period to the school server.';
    }
  }

  Future<String> deleteTimetableSlot(String id) async {
    if (!ApiSession.instance.isSignedIn) return 'Sign in to change the timetable.';
    try {
      await ApiClient.instance.delete('/timetable-entries/$id');
      timetable.removeWhere((item) => item.id == id);
      notifyListeners();
      unawaited(syncFromApi(budget: const Duration(seconds: 20)));
      return '';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not delete the period on the school server.';
    }
  }

  void addReport(SchoolReport report) {
    if (report.id.isEmpty) {
      report.id = 'sr${DateTime.now().millisecondsSinceEpoch}';
    }
    reports.add(report);
    notifyListeners();
  }

  void receiveReport(String id) {
    final index = reports.indexWhere((item) => item.id == id);
    if (index >= 0) {
      reports[index].received = true;
      notifyListeners();
    }
  }

  void deleteReport(String id) {
    reports.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void upsertTeacherReport(TeacherReport report, {bool isNew = false}) {
    if (isNew || report.id.isEmpty) {
      report.id = 'tr${DateTime.now().millisecondsSinceEpoch}';
      teacherReports.add(report);
    } else {
      final index = teacherReports.indexWhere((item) => item.id == report.id);
      if (index >= 0) {
        teacherReports[index] = report;
      } else {
        teacherReports.add(report);
      }
    }
    notifyListeners();
  }

  Future<bool> upsertClass(NamedRecord record) {
    return _mutate(() async {
      // Keep the class's stored name + stream unless it was actually renamed.
      // (This used to split any short last word off as the stream, so just
      // editing the capacity of "Basic 4" saved it as name "Basic", stream "4".)
      final original = record.id.isEmpty
          ? null
          : tableRows('school_classes').where((row) => '${row['id']}' == record.id).firstOrNull;
      final typed = record.name.trim();
      final renamed = original == null || _classLabel(original) != typed;
      final name = renamed ? typed : _asString(original['name']);
      final stream = renamed ? '' : _asString(original['stream']);
      // The form's "House" field: match it to one of the school's houses.
      final houseName = record.detail.trim().toLowerCase();
      final houseId = houseName.isEmpty
          ? null
          : tableRows('houses').where((h) => _asString(h['name']).toLowerCase() == houseName).firstOrNull?['id'];
      final teacher = _staffByName(record.link);
      final body = {
        'name': name,
        'stream': stream.isEmpty ? null : stream,
        if (int.tryParse(record.extra) != null) 'capacity': int.parse(record.extra),
        if (houseId != null) 'house_id': '$houseId',
        // The class teacher: the live API reads `teacher_ids` (it ignores
        // `class_teacher_id`), newer API versions read `class_teacher_id`.
        // Each ignores the key it doesn't know, so send both.
        if (teacher != null) 'teacher_ids': [teacher.id],
        if (teacher != null) 'class_teacher_id': teacher.id,
        'status': 'active',
      };
      if (record.id.isEmpty) {
        await ApiClient.instance.post('/school-classes', body);
      } else {
        await ApiClient.instance.put('/school-classes/${record.id}', body);
      }
    });
  }

  Future<bool> deleteClass(String id) => _mutate(() async {
        await ApiClient.instance.delete('/school-classes/$id');
      });

  Future<bool> upsertTeacher(NamedRecord record) {
    return _mutate(() => _upsertStaff(record, 'teacher', record.detail));
  }

  Future<bool> deleteTeacher(String id) => _mutate(() async {
        await ApiClient.instance.delete('/staff/$id');
      });

  Future<bool> upsertDepartment(NamedRecord record) {
    return _mutate(() async {
      final body = {
        'name': record.name,
        'description': record.detail,
        'status': 'active',
      };
      if (record.id.isEmpty) {
        await ApiClient.instance.post('/departments', body);
      } else {
        await ApiClient.instance.put('/departments/${record.id}', body);
      }
    });
  }

  Future<bool> deleteDepartment(String id) => _mutate(() async {
        await ApiClient.instance.delete('/departments/$id');
      });

  /// Saves the guardian's own profile, then links them to every child
  /// selected in [record.link] (comma-joined student ids — the same shape
  /// [applyBootstrap] reads the guardian's existing children back into).
  ///
  /// Previously this only ever wrote the guardian's own fields — the admin
  /// "Children" field was collected in the form but never sent anywhere, so
  /// a guardian created/edited here never actually got linked to a student.
  /// The messaging "Guardian is not linked to this student" errors traced
  /// back to exactly this: the link admin thought they'd made was never
  /// created. `POST /students/{id}/guardians` is the real attach endpoint
  /// (confirmed live) — each child is linked with its own call so one
  /// already-linked child (a 422/409) doesn't block the others.
  Future<bool> upsertParent(NamedRecord record) {
    return _mutate(() async {
      final relationship = _guardianRelationship(record.extra);
      if (record.phone.trim().isEmpty) throw ApiException("Enter the parent's phone number — it is how they sign in.");
      final body = {
        'full_name': record.name,
        'relationship': relationship,
        'phone': record.phone.replaceAll(RegExp(r'\s+'), ''),
        if (record.email.isNotEmpty) 'email': record.email,
        'status': 'active',
        'enable_phone_login': true,
      };
      var guardianId = record.id;
      if (guardianId.isEmpty) {
        final response = await ApiClient.instance.post('/guardians', body);
        guardianId = _idFromResponse(response) ?? '';
      } else {
        await ApiClient.instance.put('/guardians/$guardianId', body);
      }

      if (guardianId.isEmpty) return;
      final studentIds = {
        for (final id in record.link.split(','))
          if (id.trim().isNotEmpty) id.trim(),
      };
      for (final studentId in studentIds) {
        try {
          await ApiClient.instance.post('/students/$studentId/guardians', {
            'guardian_id': guardianId,
            'relationship': relationship,
            'is_primary_contact': true,
          });
        } catch (_) {
          // Already linked, or this particular child failed — the guardian
          // profile itself is already saved, so don't fail the whole edit.
        }
      }
    });
  }

  String? _idFromResponse(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'];
    if (data is Map && data['id'] != null) return '${data['id']}';
    if (response['id'] != null) return '${response['id']}';
    return null;
  }

  Future<bool> deleteParent(String id) => _mutate(() async {
        await ApiClient.instance.delete('/guardians/$id');
      });

  Future<bool> upsertAccountant(NamedRecord record) {
    return _mutate(() => _upsertStaff(record, 'accountant', record.extra.isEmpty ? 'Bursar' : record.extra));
  }

  Future<bool> deleteAccountant(String id) => _mutate(() async {
        await ApiClient.instance.delete('/staff/$id');
      });

  Future<void> _upsertStaff(NamedRecord record, String category, String position) async {
    final department = _departmentByName(record.link);
    // No email given → send none (the API accepts that) rather than
    // inventing an address and saving it on the real staff record.
    final email = record.email.trim();
    final body = {
      'full_name': record.name,
      'category': category,
      'position': position,
      if (email.isNotEmpty) 'email': email,
      if (record.phone.isNotEmpty) 'phone': record.phone.replaceAll(RegExp(r'\s+'), ''),
      if (department != null) 'department_id': department.id,
      'status': 'active',
      // No built-in password: every new staff member used to get "password",
      // and it also made saving fail for staff without an email. Logins are
      // set up on the school website.
    };
    if (record.id.isEmpty) {
      await ApiClient.instance.post('/staff', body);
    } else {
      await ApiClient.instance.put('/staff/${record.id}', body);
    }
  }

  Future<bool> upsertRoleAccount(RoleAccount account, {bool isNew = false}) async {
    if (account.role == Role.parent) {
      return upsertParent(
        NamedRecord(
          id: isNew ? '' : account.id,
          name: account.name,
          extra: 'guardian',
          email: account.email,
          phone: account.phone,
        ),
      );
    }
    final category = account.role == Role.accountant ? 'accountant' : (account.role == Role.teacher ? 'teacher' : 'admin');
    return _mutate(() => _upsertStaff(
          NamedRecord(
            id: isNew ? '' : account.id,
            name: account.name,
            extra: account.title,
            email: account.email,
            phone: account.phone,
          ),
          category,
          account.title.isEmpty ? account.role.label : account.title,
        ));
  }

  Future<bool> deleteRoleAccount(String id) {
    if (parents.any((item) => item.id == id)) return deleteParent(id);
    return _mutate(() async {
      await ApiClient.instance.delete('/staff/$id');
    });
  }
}

/// Provides [SchoolStore] without auto-rebuilding dependents on every
/// [SchoolStore.notifyListeners] (InheritedNotifier caused overlay
/// `_dependents.isEmpty` crashes when sending messages).
///
/// UI that must refresh should use [ListenableBuilder] on the store, or call
/// [of] under a parent that already rebuilds with the store.
class SchoolScope extends InheritedWidget {
  const SchoolScope({
    super.key,
    required this.store,
    required super.child,
  });

  final SchoolStore store;

  static SchoolStore of(BuildContext context) {
    final result = maybeOf(context);
    assert(result != null, 'No SchoolScope found in context');
    return result!;
  }

  /// Read without registering a dependency (safe inside dialogs/overlays).
  static SchoolStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SchoolScope>();
    assert(scope != null, 'No SchoolScope found in context');
    return scope!.store;
  }

  static SchoolStore? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SchoolScope>()?.store;
  }

  static SchoolStore? maybeRead(BuildContext context) {
    return context.getInheritedWidgetOfExactType<SchoolScope>()?.store;
  }

  @override
  bool updateShouldNotify(SchoolScope oldWidget) => store != oldWidget.store;
}
