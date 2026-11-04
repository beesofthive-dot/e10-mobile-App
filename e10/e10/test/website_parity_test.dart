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
import 'package:e10/plan_access.dart';
import 'package:e10/school_store.dart';
import 'package:e10/theme.dart';
import 'package:e10/widgets/money_dashboard_card.dart';

const _bursar = AppUser(
  email: 'b@s.test',
  displayName: 'Bursar',
  role: Role.accountant,
  subtitle: 'Bursar',
  roleSlugs: ['bursar'],
  permissions: ['payments.view'],
);

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
  displayName: 'Admin',
  role: Role.schoolAdmin,
  subtitle: 'School Admin',
  roleSlugs: ['school_admin'],
  permissions: ['report-cards.view', 'report-cards.create', 'report-cards.update', 'report-cards.publish'],
);

final _posts = <String, Object?>{};
final _gets = <String>[];

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

Map<String, dynamic> _moneyFor(String? period) => {
      'label': period == 'today' ? 'Today' : 'Term 1',
      'collected': period == 'today' ? 50 : 1200.5,
      'collected_count': 3,
      'fees_collected': 1000,
      'fees_count': 2,
      'feeding_collected': 200.5,
      'feeding_count': 1,
      'billed': 5000,
      'outstanding': 3800,
      'students_owing': 12,
      'collection_rate': 24,
      'collection_term': 'Term 1',
      'expenses': 300,
      'expenses_count': 4,
      'net': 900.5,
    };

http.Response _reply(http.Request r) {
  final path = r.url.path.replaceFirst('/api/', '');
  if (r.method == 'POST') _posts[path] = r.body.isEmpty ? null : jsonDecode(r.body);
  if (r.method == 'GET') _gets.add(path);
  switch (path) {
    case 'dashboard/money':
      return _ok({'data': _moneyFor(r.url.queryParameters['period'])});
    case 'dashboard/summary':
      return _ok({
        'data': {
          'students': {'data': [], 'meta': {'total': 640}},
          'classes': {'data': [{}, {}, {}]},
          'clocking_staff': {'data': [], 'meta': {'total': 40}},
          'student_attendance': {'summary': {'total': 600, 'present': 500, 'late': 20, 'absent': 70, 'excused': 10}},
          'staff_attendance': {'summary': {'present': 30, 'late': 2, 'early_departure': 1}},
        },
      });
    case 'report-cards':
      return _ok({
        'data': [
          {'id': 'rc1', 'student_id': 's1', 'student': {'full_name': 'Kofi Mensah'}, 'academic_term_id': 't1', 'academic_term': {'name': 'Term 1', 'status': 'current'}, 'submitted': false, 'published_at': null},
        ],
        'meta': {'last_page': 1},
      });
    case 'report-cards/rc1':
      return _ok({
        'data': {
          'id': 'rc1',
          'student_id': 's1',
          'academic_term_id': 't1',
          'lines': [
            {'subject_id': 'm', 'subject': {'name': 'Mathematics'}, 'class_score': null, 'exam_score': null, 'grade': null, 'remark': 'Great'},
            {'subject_id': 'e', 'subject': {'name': 'English'}, 'class_score': 10, 'exam_score': 20, 'grade': 'C', 'remark': 'Mine'},
          ],
        },
      });
    case 'students':
      return _ok({'data': [{'id': 's1', 'full_name': 'Kofi Mensah'}], 'meta': {'last_page': 1}});
    case 'academic-terms':
      return _ok({'data': [{'id': 't1', 'name': 'Term 1', 'status': 'current'}], 'meta': {'last_page': 1}});
    case 'subjects':
      return _ok({'data': [{'id': 'm', 'name': 'Mathematics'}, {'id': 'e', 'name': 'English'}], 'meta': {'last_page': 1}});
    case 'school-classes':
      return _ok({'data': [{'id': 'c1', 'name': 'Basic 1', 'teacher_ids': ['st1']}, {'id': 'c2', 'name': 'Basic 2'}], 'meta': {'last_page': 1}});
    case 'enrollments':
      return _ok({'data': [{'student_id': 's1', 'class_id': 'c1'}], 'meta': {'last_page': 1}});
    case 'report-cards/fill-class':
      return _ok({'message': 'Filled.'});
    case 'report-cards/fill-preview':
      return _ok({
        'data': {
          'class_score_weight': 30,
          'lines': [
            {'subject_id': 'm', 'class_score': 27, 'exam_score': 60.5, 'grade': 'A', 'remark': 'From the server'},
            {'subject_id': 'sci', 'subject_name': 'Science', 'class_score': 20, 'exam_score': 50, 'grade': 'B', 'remark': null},
          ],
        },
      });
    default:
      return _ok({'data': [], 'meta': {'last_page': 1}});
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(WidgetTester tester, Widget home, {Size size = const Size(420, 2000)}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final store = SchoolStore();
  addTearDown(store.stopLiveSync);
  await tester.pumpWidget(AppPrefsScope(
    prefs: AppPrefs(),
    child: SchoolScope(
      store: store,
      child: MaterialApp(theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey), home: home),
    ),
  ));
  await _settle(tester);
}

/// Newer website features the app now shares: the server's dashboard figures
/// and filling report cards from assessments.
void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  setUp(() {
    _posts.clear();
    _gets.clear();
    ApiSession.instance.token = 'test-token';
    ApiSession.instance.user = {
      'staff': {'id': 'st1'},
    };
  });
  tearDown(() {
    ApiSession.instance.token = null;
    ApiSession.instance.user = null;
    PlanAccess.user = null;
  });

  group('dashboard summary', () {
    test('reads the website shape', () {
      final s = DashboardSummary.fromJson({
        'students': {'data': [], 'meta': {'total': 640}},
        'classes': {'data': [{}, {}, {}]},
        'clocking_staff': {'data': [], 'meta': {'total': 40}},
        'student_attendance': {'summary': {'present': 500, 'late': 20, 'absent': 70, 'excused': 10}},
        'staff_attendance': {'summary': {'present': 30, 'late': 2, 'early_departure': 1}},
      });
      expect(s.students, 640);
      expect(s.classes, 3);
      expect(s.clockingStaff, 40);
      expect(s.studentsIn, 520);
      expect(s.studentsAway, 80);
      expect(s.staffIn, 33);
    });

    test('missing pieces stay unknown instead of zero', () {
      final s = DashboardSummary.fromJson(const {});
      expect(s.students, isNull);
      expect(s.studentsIn, isNull);
      expect(s.staffIn, isNull);
    });

    testWidgets('the admin dashboard shows the server figures', (tester) async {
      await http.runWithClient(() async {
        await _pump(tester, const E10App(debugUser: _admin, debugScreen: AppScreen.adminHome));
        final store = SchoolScope.read(tester.element(find.byType(E10App)));
        store.applyUserSchool(_admin);
        await store.refreshDashboardSummary();
        await _settle(tester);
        expect(_gets, contains('dashboard/summary'));
        expect(store.dashboardSummary?.students, 640);
        expect(find.text('640'), findsOneWidget);
        expect(find.text('520'), findsOneWidget);
        expect(find.text('Staff present'), findsOneWidget);
        expect(find.text('33'), findsOneWidget);
        expect(find.text('of 40 today'), findsOneWidget);
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('a teacher never asks for it', (tester) async {
      await http.runWithClient(() async {
        final store = SchoolStore()..applyUserSchool(_teacher);
        await store.refreshDashboardSummary();
        store.stopLiveSync();
        expect(_gets, isNot(contains('dashboard/summary')));
      }, () => MockClient((r) async => _reply(r)));
    });
  });

  group('money card', () {
    Widget card(AppUser user) => Scaffold(body: SingleChildScrollView(child: MoneyDashboardCard(user: user)));

    testWidgets('shows the server totals and changes period', (tester) async {
      await http.runWithClient(() async {
        await _pump(tester, card(_bursar));
        expect(find.text('Money · Term 1'), findsOneWidget);
        expect(find.text('GHS 1,200.50'), findsOneWidget);
        expect(find.text('24%'), findsOneWidget);
        expect(find.text('12 students owing'), findsOneWidget);
        await tester.tap(find.text('Today'));
        await _settle(tester);
        expect(find.text('Money · Today'), findsOneWidget);
        expect(find.text('GHS 50.00'), findsOneWidget);
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('stays hidden without permission, plan module or a reply', (tester) async {
      await http.runWithClient(() async {
        await _pump(tester, card(_teacher));
        expect(find.textContaining('Money'), findsNothing);
        expect(_gets, isNot(contains('dashboard/money')));

        PlanAccess.user = const AppUser(email: '', displayName: '', role: Role.accountant, subtitle: '', schoolModules: ['attendance']);
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, card(_bursar));
        expect(find.textContaining('Money'), findsNothing);
        expect(_gets, isNot(contains('dashboard/money')));
        PlanAccess.user = null;
      }, () => MockClient((r) async => _reply(r)));

      await http.runWithClient(() async {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, card(_bursar));
        expect(find.textContaining('Money'), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => MockClient((r) async => http.Response(jsonEncode({'message': 'No'}), 403)));
    });

    testWidgets('fits a small phone', (tester) async {
      await http.runWithClient(() async {
        await _pump(tester, card(_bursar), size: const Size(320, 568));
        expect(tester.takeException(), isNull);
      }, () => MockClient((r) async => _reply(r)));
    });
  });

  group('fill from assessments', () {
    Future<void> filterClass(WidgetTester tester, String klass) async {
      await tester.tap(find.text('All classes'));
      await _settle(tester);
      await tester.tap(find.text(klass).last);
      await _settle(tester);
    }

    testWidgets('a class teacher fills their own class, after confirming', (tester) async {
      await http.runWithClient(() async {
        await _pump(tester, const E10App(debugUser: _teacher, debugScreen: AppScreen.teacherMyReports));
        expect(find.text('Fill class from assessments'), findsNothing); // no class chosen
        await filterClass(tester, 'Basic 1');
        await tester.tap(find.text('Fill class from assessments'));
        await _settle(tester);
        expect(find.text('Fill the class from assessments?'), findsOneWidget);
        await tester.tap(find.text('Fill class'));
        await _settle(tester);
        expect(_posts['report-cards/fill-class'], {'class_id': 'c1', 'academic_term_id': 't1'});
        await tester.pump(const Duration(seconds: 10));
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('fills one card: scores in, a written remark kept, new subjects added', (tester) async {
      await http.runWithClient(() async {
        await _pump(tester, const E10App(debugUser: _admin, debugScreen: AppScreen.teacherReports));
        await tester.tap(find.text('Edit'));
        await _settle(tester);
        await tester.tap(find.text('Fill from assessments'));
        await _settle(tester);
        expect(_posts['report-cards/fill-preview'], {'student_id': 's1', 'academic_term_id': 't1'});
        expect(find.text('Science'), findsOneWidget);
        expect(find.text('60.5'), findsOneWidget);
        expect(find.text('27'), findsOneWidget);
        expect(find.text('Great'), findsOneWidget); // written remark kept
        expect(find.text('From the server'), findsNothing);
        expect(find.text('Mine'), findsOneWidget); // a subject not filled is untouched
        await tester.pump(const Duration(seconds: 10));
      }, () => MockClient((r) async => _reply(r)));
    });
  });
}
