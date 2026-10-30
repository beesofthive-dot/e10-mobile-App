import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/app.dart';
import 'package:e10/app_prefs.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/theme.dart';

const _teacher = AppUser(
  email: 't@s.test',
  displayName: 'Ama',
  role: Role.teacher,
  subtitle: 'Teacher',
  roleSlugs: ['teacher'],
  permissions: ['report-cards.view', 'report-cards.create', 'report-cards.update'],
);

const _admin = AppUser(
  email: 'a@s.test',
  displayName: 'Head',
  role: Role.schoolAdmin,
  subtitle: 'School Admin',
  roleSlugs: ['school_admin'],
  permissions: ['report-cards.view', 'report-cards.create', 'report-cards.update', 'report-cards.delete', 'report-cards.publish'],
);

final _posts = <String>[];

http.Response _reply(http.Request r) {
  final path = r.url.path.replaceFirst('/api/', '');
  if (r.method == 'POST') _posts.add(path);
  Object data;
  switch (path) {
    case 'report-cards':
      data = [
        {'id': 'rc1', 'student_id': 's1', 'student': {'full_name': 'Kofi Mensah'}, 'academic_term_id': 't1', 'academic_term': {'name': 'Term 1', 'status': 'current'}, 'submitted': false, 'published_at': null},
        {'id': 'rc2', 'student_id': 's2', 'student': {'full_name': 'Esi Owusu'}, 'academic_term_id': 't1', 'academic_term': {'name': 'Term 1', 'status': 'current'}, 'submitted': true, 'published_at': null},
      ];
    case 'students':
      data = [
        {'id': 's1', 'full_name': 'Kofi Mensah'},
        {'id': 's2', 'full_name': 'Esi Owusu'},
      ];
    case 'academic-terms':
      data = [
        {'id': 't1', 'name': 'Term 1', 'status': 'current'},
      ];
    case 'subjects':
      data = [
        {'id': 'm', 'name': 'Mathematics'},
        {'id': 'e', 'name': 'English'},
      ];
    case 'school-classes':
      data = [
        {'id': 'c1', 'name': 'Basic 1', 'teacher_ids': ['st1']},
      ];
    case 'enrollments':
      data = [
        {'student_id': 's1', 'class_id': 'c1'},
        {'student_id': 's2', 'class_id': 'c1'},
      ];
    default:
      data = [];
  }
  return http.Response(jsonEncode({'data': data, 'meta': {'last_page': 1}}), 200);
}

Future<void> _open(WidgetTester tester, AppUser user, AppScreen screen) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppPrefsScope(
      prefs: AppPrefs(),
      child: SchoolScope(
        store: SchoolStore(),
        child: MaterialApp(
          theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
          home: E10App(debugUser: user, debugScreen: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The website's report-card workflow: a class teacher fills and submits,
/// an admin publishes.
void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  setUp(() {
    _posts.clear();
    ApiSession.instance.token = 'test-token';
    ApiSession.instance.user = {
      'staff': {'id': 'st1'},
    };
  });
  tearDown(() {
    ApiSession.instance.token = null;
    ApiSession.instance.user = null;
  });

  testWidgets('a class teacher creates and submits cards for their class', (tester) async {
    await http.runWithClient(() async {
      await _open(tester, _teacher, AppScreen.teacherMyReports);
      expect(find.text('Create report card'), findsOneWidget);
      expect(find.text('Kofi Mensah'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Ready for review'), findsOneWidget);
      expect(find.text('Submit for review'), findsOneWidget); // only the draft
      expect(find.text('Publish'), findsNothing); // teachers don't publish

      await tester.tap(find.text('Submit for review'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_posts, contains('report-cards/rc1/submit'));

      await tester.tap(find.text('Create report card'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Select a student to load subjects.'), findsOneWidget);
      expect(find.textContaining('As class teacher for Basic 1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10)); // let the notice time out
    }, () => MockClient((r) async => _reply(r)));
  });

  testWidgets('an admin publishes', (tester) async {
    await http.runWithClient(() async {
      await _open(tester, _admin, AppScreen.teacherReports);
      expect(find.text('Publish'), findsNWidgets(2));
      expect(find.text('Submit for review'), findsNothing);
      await tester.tap(find.text('Publish').first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_posts, contains('report-cards/rc1/publish'));
      await tester.pump(const Duration(seconds: 10)); // let the notice time out
    }, () => MockClient((r) async => _reply(r)));
  });
}
