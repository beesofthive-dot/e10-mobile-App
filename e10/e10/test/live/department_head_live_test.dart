@Tags(['live'])
library;

import 'dart:io';

import 'package:e10/api/api_session.dart';
import 'package:e10/auth.dart';
import 'package:e10/department_head.dart';
import 'package:e10/models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Read-only check of "My department" against a REAL server with a real
/// department head's login. It changes nothing on the server.
///
///   E2E_API=https://e10.beesofthive.pro/api E2E_HEAD_EMAIL=... E2E_HEAD_PASSWORD=... flutter test test/live/department_head_live_test.dart --tags live
///
/// Skipped unless all three are set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final api = env['E2E_API'];
  final email = env['E2E_HEAD_EMAIL'];
  final password = env['E2E_HEAD_PASSWORD'];
  final skip = api == null || email == null || password == null ? 'Set E2E_API, E2E_HEAD_EMAIL and E2E_HEAD_PASSWORD' : null;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=${api ?? ''}');
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
  });

  test('a head only reaches their own department', () async {
    final signedIn = await Auth.signIn(email: email!, password: password!);
    expect(signedIn.ok, isTrue, reason: signedIn.error);
    final user = signedIn.user!;
    expect(user.isDepartmentHead, isTrue, reason: 'This login is not a department head');
    final scope = DepartmentScope(user.departmentHeads);
    // ignore: avoid_print
    print('Heads: ${user.departmentHeads.map((h) => '${h.departmentName} (${h.departmentId}) main=${h.isMain}').join(', ')}');
    // ignore: avoid_print
    print('Permissions: ${user.permissions.join(', ')}');

    if (user.canOpen(AppScreen.departmentClasses)) {
      final classes = await DepartmentApi.classes();
      // ignore: avoid_print
      print('Classes: ${classes.total} (${classes.rows.where(scope.hasClass).length} in the department)');
      if (classes.rows.isNotEmpty) {
        // ignore: avoid_print
        print('Class fields: ${classes.rows.first.keys.join(', ')}');
      }
    }
    if (user.canOpen(AppScreen.departmentStaff)) {
      final staff = await DepartmentApi.staff();
      // ignore: avoid_print
      print('Staff: ${staff.total} (${staff.rows.where(scope.hasStaff).length} of the first page in the department)');
      if (staff.rows.isNotEmpty) {
        // ignore: avoid_print
        print('Staff fields: ${staff.rows.first.keys.join(', ')}');
      }
    }
    if (user.canOpen(AppScreen.departmentStudents)) {
      final students = await DepartmentApi.students();
      // ignore: avoid_print
      print('Students: ${students.total}');
      if (students.rows.isNotEmpty) {
        // ignore: avoid_print
        print('Student fields: ${students.rows.first.keys.join(', ')}; class id read: "${departmentStudentClassId(students.rows.first)}"');
      }
    }
    if (user.canOpen(AppScreen.departmentAttendance)) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final page = await DepartmentApi.attendance(date: today, personType: 'student');
      // ignore: avoid_print
      print('Attendance summary: ${page.summary}');
    }
    for (final head in user.departmentHeads.where((h) => h.isMain)) {
      final info = await DepartmentApi.heads(head.departmentId);
      // ignore: avoid_print
      print('Heads of ${head.departmentId}: ${info.heads.length}, manage main=${info.canManageMain}, assistants=${info.canManageAssistants}');
    }
    await Auth.logout();
    expect(ApiSession.instance.isSignedIn, isFalse);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
