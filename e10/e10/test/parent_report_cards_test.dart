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

const _parent = AppUser(email: 'p@s.test', displayName: 'Kofi', role: Role.parent, subtitle: 'Parent');

/// Shaped like the live `/report-cards` replies the website reads.
http.Response _reply(http.Request r) {
  final path = r.url.path.replaceFirst('/api/', '');
  if (path == 'report-cards') {
    return http.Response(
      jsonEncode({
        'data': [
          {
            'id': 'rc1',
            'student_id': 's1',
            'student': {'full_name': 'Joseph Ntierenyin'},
            'academic_term': {'name': 'Term 1'},
            'published_at': '2026-10-20T10:00:00Z',
            'teacher_remark': 'A hardworking pupil',
          },
          {
            'id': 'rc2',
            'student_id': 's1',
            'student': {'full_name': 'Joseph Ntierenyin'},
            'academic_term': {'name': 'Term 2'},
            'published_at': null,
          },
        ],
        'meta': {'last_page': 1},
      }),
      200,
    );
  }
  if (path == 'report-cards/rc1') {
    return http.Response(
      jsonEncode({
        'data': {
          'id': 'rc1',
          'issued_date': '2026-10-20',
          'attendance_days_attended': 58,
          'attendance_days_available': 60,
          'promotion_status': 'promoted',
          'teacher_remark': 'A hardworking pupil',
          'headteacher_remark': 'Keep it up',
          'lines': [
            {'subject': {'name': 'Mathematics'}, 'class_score': 25, 'exam_score': 60, 'score': 85, 'grade': 'A', 'remark': 'Excellent'},
          ],
        },
      }),
      200,
    );
  }
  return http.Response(jsonEncode({'data': []}), 200);
}

Future<void> _open(WidgetTester tester, AppScreen screen) async {
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
          home: E10App(debugUser: _parent, debugScreen: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  setUp(() => ApiSession.instance.token = 'test-token');
  tearDown(() => ApiSession.instance.token = null);

  testWidgets('report cards list like the website, published ones open', (tester) async {
    await http.runWithClient(() async {
      await _open(tester, AppScreen.parentReports);
      expect(find.text('Report cards for my children'), findsWidgets);
      expect(find.text('Term 1'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Available once the school publishes it.'), findsOneWidget);
      expect(find.text('View'), findsOneWidget); // only the published card

      await tester.tap(find.text('View'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('58/60'), findsOneWidget);
      expect(find.text('promoted'), findsOneWidget);
      expect(find.text('Keep it up'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
    }, () => MockClient((r) async => _reply(r)));
  });

  testWidgets("the parent's header menu has no Announcements", (tester) async {
    await http.runWithClient(() async {
      await _open(tester, AppScreen.parentReports);
      await tester.tap(find.byTooltip('Announcements, messages & notifications'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Announcements'), findsNothing);
    }, () => MockClient((r) async => _reply(r)));
  });
}
