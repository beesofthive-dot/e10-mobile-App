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
import 'package:e10/auth.dart';
import 'package:e10/models.dart';
import 'package:e10/plan_access.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_records.dart';
import 'package:e10/screens/department_screen.dart';
import 'package:e10/theme.dart';
import 'package:e10/widgets/teacher_drawer.dart';

const _allViews = ['students.view', 'staff.view', 'classes.view', 'attendance.view'];

const _mainHead = AppUser(
  email: 'head@s.test',
  displayName: 'Ama Head',
  role: Role.teacher,
  subtitle: 'Teacher',
  roleSlugs: ['teacher'],
  permissions: _allViews,
  departmentHeads: [DepartmentHeadship(departmentId: 'd1', departmentName: 'Primary', isMain: true)],
);

const _assistant = AppUser(
  email: 'asst@s.test',
  displayName: 'Kojo Assistant',
  role: Role.teacher,
  subtitle: 'Teacher',
  roleSlugs: ['teacher'],
  permissions: ['students.view', 'attendance.view'],
  departmentHeads: [DepartmentHeadship(departmentId: 'd1', departmentName: 'Primary')],
);

const _plainTeacher = AppUser(
  email: 't@s.test',
  displayName: 'Plain',
  role: Role.teacher,
  subtitle: 'Teacher',
  roleSlugs: ['teacher'],
  permissions: _allViews,
);

final _requests = <http.Request>[];
Map<String, dynamic>? _savedHeads;

Map<String, dynamic> _headsReply = {
  'data': [
    {'staff_id': 'st1', 'full_name': 'Ama Head', 'phone': '0244000000', 'is_main': true, 'notify_scans': false, 'notify_sms': false, 'permissions': []},
  ],
  'can_manage_main': true,
  'can_manage_assistants': true,
  'assistant_permissions': [
    {'name': 'exams.publish', 'label': 'Publish results', 'group': 'Exams'},
    {'name': 'attendance.view', 'label': 'View attendance', 'group': 'Attendance'},
  ],
};

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

/// A server that, like the live one, also hands the head their own class
/// and a colleague outside the department.
http.Response _reply(http.Request r) {
  _requests.add(r);
  final path = r.url.path.replaceFirst('/api/', '');
  final q = r.url.queryParameters;
  switch (path) {
    case 'school-classes':
      return _ok({
        'data': [
          {'id': 'c1', 'name': 'Basic 1', 'department_id': 'd1', 'teachers': [{'full_name': 'Ama Head'}]},
          {'id': 'c2', 'name': 'Basic 2', 'department': {'id': 'd1'}},
          {'id': 'c9', 'name': 'JHS 1', 'department_id': 'd2'},
        ],
        'meta': {'last_page': 1, 'total': 3},
      });
    case 'students':
      final all = [
        {'id': 's1', 'full_name': 'Kofi Mensah', 'class_id': 'c1'},
        {'id': 's2', 'full_name': 'Esi Owusu', 'class_id': 'c2'},
        {'id': 's9', 'full_name': 'Outside Pupil', 'class_id': 'c9'},
      ];
      final hits = [
        for (final s in all)
          if ((q['class_id'] ?? s['class_id']) == s['class_id'] && '${s['full_name']}'.toLowerCase().contains((q['search'] ?? '').toLowerCase())) s,
      ];
      return _ok({'data': hits, 'meta': {'last_page': 1, 'total': hits.length}});
    case 'staff':
      return _ok({
        'data': [
          {'id': 'st1', 'full_name': 'Ama Head', 'position': 'Headteacher', 'departments': [{'id': 'd1', 'name': 'Primary'}]},
          {'id': 'st2', 'full_name': 'Kojo Teacher', 'position': 'Teacher', 'department': {'id': 'd1', 'name': 'Primary'}, 'phone': '0200000000'},
          {'id': 'st9', 'full_name': 'Yaw Elsewhere', 'department_id': 'd2'},
        ],
        'meta': {'last_page': 1, 'total': 3},
      });
    case 'attendance':
      final staff = q['person_type'] == 'staff';
      return _ok({
        'data': staff
            ? [
                {'id': 'a2', 'status': 'late', 'check_in_at': '2026-10-30T08:10:00', 'staff': {'full_name': 'Kojo Teacher', 'position': 'Teacher', 'department': {'id': 'd1'}}},
                {'id': 'a3', 'status': 'present', 'staff': {'full_name': 'Yaw Elsewhere', 'department_id': 'd2'}},
              ]
            : [
                {'id': 'a1', 'status': 'present', 'student': {'full_name': 'Kofi Mensah', 'class_id': 'c1'}},
                {'id': 'a9', 'status': 'present', 'student': {'full_name': 'Outside Pupil', 'class_id': 'c9'}},
              ],
        'meta': {'last_page': 1, 'total': 1},
        'summary': {'total': 20, 'present': 15, 'absent': 3, 'late': 2, 'excused': 0, 'missing_checkout': staff ? 1 : 0},
      });
    case 'departments/d1/heads':
      if (r.method == 'PUT') {
        _savedHeads = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'message': 'Department heads saved.'});
      }
      return _ok(_headsReply);
    case 'departments':
      return _ok({
        'data': [
          {
            'id': 'd1',
            'name': 'Primary',
            'status': 'active',
            'heads': [
              {'staff_id': 'st1', 'full_name': 'Ama Head', 'is_main': true},
              {'staff_id': 'st2', 'full_name': 'Kojo Teacher', 'is_main': false},
            ],
          },
          {'id': 'd2', 'name': 'JHS', 'status': 'active', 'heads': []},
        ],
      });
    case 'auth/me':
      return _ok({'data': ApiSession.instance.user});
    default:
      return _ok({'data': [], 'meta': {'last_page': 1}});
  }
}

Future<SchoolStore> _open(WidgetTester tester, AppUser user, AppScreen screen, {Size size = const Size(420, 900)}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final store = SchoolStore();
  addTearDown(store.stopLiveSync);
  await tester.pumpWidget(
    AppPrefsScope(
      prefs: AppPrefs(),
      child: SchoolScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
          home: E10App(debugUser: user, debugScreen: screen),
        ),
      ),
    ),
  );
  await _settle(tester);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Lets a snack-bar style notice time out before the test ends.
Future<void> _finish(WidgetTester tester) => tester.pump(const Duration(seconds: 10));

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  setUp(() {
    _requests.clear();
    _savedHeads = null;
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

  group('who is a department head', () {
    test('reads department_heads from the login reply', () {
      final user = Auth.userFromApi({
        'email': 'x@s.test',
        'roles': ['teacher'],
        'staff': {'id': 'st1', 'full_name': 'Ama'},
        'permissions': _allViews,
        'department_heads': [
          {'department_id': 'd1', 'department_name': 'Primary', 'is_main': true},
          {'department_id': 'd2', 'department': {'name': 'JHS'}, 'is_main': 0},
          {'is_main': true},
        ],
      });
      expect(user.departmentHeads.map((h) => h.departmentId), ['d1', 'd2']);
      expect(user.departmentHeads.map((h) => h.departmentName), ['Primary', 'JHS']);
      expect(user.departmentHeads.map((h) => h.isMain), [true, false]);
      expect(user.isDepartmentHead, isTrue);
      expect(user.isMainDepartmentHead, isTrue);
    });

    test('a login reply without the field is an ordinary teacher', () {
      final user = Auth.userFromApi({'roles': ['teacher'], 'staff': {'id': 'st1'}});
      expect(user.departmentHeads, isEmpty);
      expect(user.isDepartmentHead, isFalse);
      for (final screen in departmentScreens) {
        expect(user.canOpen(screen), isFalse, reason: '$screen');
      }
    });

    test('each page needs the same permission as on the website', () {
      expect(_mainHead.canOpen(AppScreen.departmentHome), isTrue);
      expect(_mainHead.canOpen(AppScreen.departmentStaff), isTrue);
      expect(_mainHead.canOpen(AppScreen.departmentHeads), isTrue);
      expect(_assistant.canOpen(AppScreen.departmentHome), isTrue);
      expect(_assistant.canOpen(AppScreen.departmentStudents), isTrue);
      expect(_assistant.canOpen(AppScreen.departmentAttendance), isTrue);
      expect(_assistant.canOpen(AppScreen.departmentStaff), isFalse);
      expect(_assistant.canOpen(AppScreen.departmentClasses), isFalse);
      expect(_assistant.canOpen(AppScreen.departmentHeads), isFalse);
    });

    test('the role alone never opens a department page', () {
      for (final role in Role.values) {
        for (final screen in departmentScreens) {
          expect(role.canOpen(screen), isFalse, reason: '$role $screen');
        }
      }
    });

    test('school admins and parents are not in head mode', () {
      const admin = AppUser(
        email: '',
        displayName: '',
        role: Role.schoolAdmin,
        subtitle: '',
        departmentHeads: [DepartmentHeadship(departmentId: 'd1', isMain: true)],
      );
      const parent = AppUser(
        email: '',
        displayName: '',
        role: Role.parent,
        subtitle: '',
        departmentHeads: [DepartmentHeadship(departmentId: 'd1', isMain: true)],
      );
      expect(admin.isDepartmentHead, isFalse);
      expect(parent.isDepartmentHead, isFalse);
    });

    test('a non-teacher staff head is still a head', () {
      const librarian = AppUser(
        email: '',
        displayName: '',
        role: Role.librarian,
        subtitle: '',
        permissions: _allViews,
        departmentHeads: [DepartmentHeadship(departmentId: 'd1')],
      );
      expect(librarian.canOpen(AppScreen.departmentStudents), isTrue);
      expect(librarian.canOpen(AppScreen.departmentHeads), isFalse);
    });
  });

  group('menu', () {
    Future<void> drawer(WidgetTester tester, AppUser user) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
        home: AppPrefsScope(
          prefs: AppPrefs(),
          child: Scaffold(body: TeacherDrawer(user: user, active: AppScreen.teacherHome, onNav: (_) {}, onLogout: () {})),
        ),
      ));
      await tester.pump();
    }

    testWidgets('a main head gets My department with every page', (tester) async {
      await drawer(tester, _mainHead);
      expect(find.text('MY DEPARTMENT'), findsOneWidget);
      for (final label in ['Students', 'Staff', 'Classes', 'Department attendance', 'Department heads']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('My Classes'), findsNothing);
    });

    testWidgets('an assistant gets only what they were given', (tester) async {
      await drawer(tester, _assistant);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Department attendance'), findsOneWidget);
      expect(find.text('Staff'), findsNothing);
      expect(find.text('Classes'), findsNothing);
      expect(find.text('Department heads'), findsNothing);
    });

    testWidgets('an ordinary teacher keeps My Classes', (tester) async {
      await drawer(tester, _plainTeacher);
      expect(find.text('MY DEPARTMENT'), findsNothing);
      expect(find.text('My Classes'), findsOneWidget);
    });
  });

  group('My department', () {
    testWidgets('overview shows the counts, using one-row requests', (tester) async {
      await http.runWithClient(() async {
        await _open(tester, _mainHead, AppScreen.departmentHome);
        expect(find.text('My department'), findsOneWidget);
        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('2 classes'), findsOneWidget); // JHS 1 is not theirs
        expect(find.text('17 in · 3 absent today'), findsOneWidget);
        final counts = _requests.where((r) => r.url.path.endsWith('/students') || r.url.path.endsWith('/staff'));
        expect(counts, isNotEmpty);
        for (final r in counts) {
          expect(r.url.queryParameters['per_page'], '1', reason: '${r.url}');
        }
        await tester.tap(find.text('Staff'));
        await _settle(tester);
        expect(find.text('Kojo Teacher'), findsOneWidget);
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('students stay in the department and search goes to the server', (tester) async {
      await http.runWithClient(() async {
        await _open(tester, _mainHead, AppScreen.departmentStudents);
        expect(find.text('Kofi Mensah'), findsOneWidget);
        expect(find.text('Esi Owusu'), findsOneWidget);
        expect(find.text('Outside Pupil'), findsNothing);

        await tester.enterText(find.byType(TextField), 'kofi');
        await tester.pump(const Duration(milliseconds: 500));
        await _settle(tester);
        expect(_requests.last.url.queryParameters['search'], 'kofi');
        expect(find.text('Kofi Mensah'), findsOneWidget);
        expect(find.text('Esi Owusu'), findsNothing);
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('staff stay in the department and open their details', (tester) async {
      await http.runWithClient(() async {
        await _open(tester, _mainHead, AppScreen.departmentStaff);
        expect(find.text('Ama Head'), findsOneWidget);
        expect(find.text('Kojo Teacher'), findsOneWidget);
        expect(find.text('Yaw Elsewhere'), findsNothing);
        await tester.tap(find.text('Kojo Teacher'));
        await _settle(tester);
        expect(find.text('Primary'), findsOneWidget);
        expect(find.text('0200000000'), findsWidgets);
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('classes stay in the department and list their students', (tester) async {
      await http.runWithClient(() async {
        await _open(tester, _mainHead, AppScreen.departmentClasses);
        expect(find.text('Basic 1'), findsOneWidget);
        expect(find.text('Basic 2'), findsOneWidget);
        expect(find.text('JHS 1'), findsNothing);
        expect(find.text('Class teacher: Ama Head'), findsOneWidget);
        await tester.tap(find.text('Basic 1'));
        await _settle(tester);
        expect(_requests.last.url.queryParameters['class_id'], 'c1');
        expect(find.text('Kofi Mensah'), findsOneWidget);
        expect(find.text('Esi Owusu'), findsNothing);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await _settle(tester);
        expect(find.text('Basic 2'), findsOneWidget);
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('attendance shows students and staff for the department only', (tester) async {
      await http.runWithClient(() async {
        await _open(tester, _mainHead, AppScreen.departmentAttendance);
        expect(find.text('Kofi Mensah'), findsOneWidget);
        expect(find.text('Outside Pupil'), findsNothing);
        expect(find.text('Total 20'), findsOneWidget);
        expect(find.text('Present 15'), findsOneWidget);

        await tester.tap(find.text('Staff'));
        await _settle(tester);
        final last = _requests.lastWhere((r) => r.url.path.endsWith('/attendance'));
        expect(last.url.queryParameters['person_type'], 'staff');
        expect(find.text('Kojo Teacher'), findsOneWidget);
        expect(find.text('Late'), findsOneWidget);
        expect(find.text('Yaw Elsewhere'), findsNothing);
        expect(find.text('1 with no check-out'), findsOneWidget);

        await tester.tap(find.text('Absent 3'));
        await _settle(tester);
        final filtered = _requests.lastWhere((r) => r.url.path.endsWith('/attendance'));
        expect(filtered.url.queryParameters['status'], 'absent');
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('a server error can be retried', (tester) async {
      var fail = true;
      await http.runWithClient(() async {
        await _open(tester, _mainHead, AppScreen.departmentStaff);
        expect(find.text('Try again'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('Try again'));
        await _settle(tester);
        expect(find.text('Kojo Teacher'), findsOneWidget);
      }, () => MockClient((r) async {
            if (fail && r.url.path.endsWith('/staff')) {
              return http.Response(jsonEncode({'message': 'Not allowed'}), 403);
            }
            return _reply(r);
          }));
    });

    testWidgets('no overflow on small and sideways phones', (tester) async {
      await http.runWithClient(() async {
        for (final size in const [Size(320, 568), Size(800, 360), Size(380, 460)]) {
          for (final screen in departmentScreens) {
            final store = await _open(tester, _mainHead, screen, size: size);
            expect(tester.takeException(), isNull, reason: '$screen $size');
            store.stopLiveSync();
          }
        }
      }, () => MockClient((r) async => _reply(r)));
    });
  });

  group('setting heads', () {
    testWidgets('an admin sees the departments and their heads after the first sync', (tester) async {
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({});
        ApiSession.instance.user = {'roles': ['school_admin'], 'permissions': ['departments.view']};
        final store = SchoolStore()
          ..applyUserSchool(const AppUser(email: 'a@s.test', displayName: 'A', role: Role.schoolAdmin, subtitle: ''));
        addTearDown(store.stopLiveSync);
        await store.syncFromApi();
        for (var i = 0; i < 10 && store.departments.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        store.stopLiveSync();
        expect(store.departments.map((d) => d.name), ['Primary', 'JHS']);
        expect(store.departments.first.link, 'Ama Head, Kojo Teacher (assistant)');
        expect(store.departments.last.link, '');
        await tester.pump(const Duration(seconds: 1));
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('from the admin dashboard to the heads form', (tester) async {
      const admin = AppUser(
        email: 'a@s.test',
        displayName: 'Admin',
        role: Role.schoolAdmin,
        subtitle: 'School Admin',
        roleSlugs: ['school_admin'],
        permissions: ['departments.update'],
      );
      await http.runWithClient(() async {
        final store = await _open(tester, admin, AppScreen.adminHome, size: const Size(420, 3000));
        store.departments.add(NamedRecord(id: 'd1', name: 'Primary', link: 'Ama Head'));
        await tester.tap(find.text('Set who heads each department'));
        await _settle(tester);
        expect(find.text('Head: Ama Head'), findsOneWidget);
        await tester.tap(find.byType(IconButton).last);
        await _settle(tester);
        await tester.tap(find.text('Department heads'));
        await _settle(tester);
        await _settle(tester);
        expect(find.text('Heads of Primary'), findsOneWidget);
        expect(find.text('Save heads'), findsOneWidget);
        store.stopLiveSync();
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('admin department list offers the heads form only with permission', (tester) async {
      Future<void> show(bool canManage) async {
        final store = SchoolStore()
          ..departments.add(NamedRecord(id: 'd1', name: 'Primary', link: 'Ama Head'));
        await tester.pumpWidget(AppPrefsScope(
          prefs: AppPrefs(),
          child: SchoolScope(
            store: store,
            child: MaterialApp(
              theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
              home: Scaffold(body: AdminRecordsScreen(kind: AdminRecordKind.departments, onLogout: () {}, canManageHeads: canManage)),
            ),
          ),
        ));
        await tester.pump();
        expect(find.text('Head: Ama Head'), findsOneWidget);
        await tester.tap(find.byType(IconButton).last);
        await tester.pump(const Duration(milliseconds: 400));
      }

      await show(false);
      expect(find.text('Department heads'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await show(true);
      expect(find.text('Department heads'), findsOneWidget);
    });

    Future<SchoolStore> openForm(WidgetTester tester) async {
      final store = SchoolStore();
      addTearDown(store.stopLiveSync);
      tester.view.physicalSize = const Size(840, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(AppPrefsScope(
        prefs: AppPrefs(),
        child: SchoolScope(
          store: store,
          child: MaterialApp(
            theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showDepartmentHeadsSheet(context, departmentId: 'd1', departmentName: 'Primary'),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);
      return store;
    }

    testWidgets('adding an assistant with ticks sends what the website sends', (tester) async {
      _headsReply = {..._headsReply, 'can_manage_main': true, 'can_manage_assistants': true};
      await http.runWithClient(() async {
        final store = await openForm(tester);
        expect(find.text('Heads of Primary'), findsOneWidget);
        expect(find.text('Ama Head'), findsOneWidget);
        final save = find.widgetWithText(FilledButton, 'Save heads');
        expect(tester.widget<FilledButton>(save).onPressed, isNull); // nothing changed

        await tester.enterText(find.byType(TextField), 'Kojo');
        await tester.pump(const Duration(milliseconds: 500));
        await _settle(tester);
        expect(_requests.last.url.queryParameters['search'], 'Kojo');
        await tester.tap(find.text('Kojo Teacher'));
        await _settle(tester);
        expect(find.text('Add Kojo Teacher as:'), findsOneWidget);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Assistant'));
        await _settle(tester);

        await tester.tap(find.text('Publish results'));
        await tester.pump();
        expect(find.text('What this assistant can do (1 ticked)'), findsOneWidget);

        // Scan alerts on the main head, then SMS with them.
        await tester.tap(find.text('Notify on every teacher scan').first);
        await tester.pump();
        await tester.tap(find.text('Also by SMS').first);
        await tester.pump();

        await tester.ensureVisible(save);
        await tester.pump();
        await tester.tap(save);
        await _settle(tester);
        final heads = (_savedHeads!['heads'] as List).cast<Map<String, dynamic>>();
        expect(heads[0], {'staff_id': 'st1', 'is_main': true, 'notify_scans': true, 'notify_sms': true, 'permissions': <String>[]});
        expect(heads[1], {'staff_id': 'st2', 'is_main': false, 'notify_scans': false, 'notify_sms': false, 'permissions': ['exams.publish']});
        await _finish(tester);
        store.stopLiveSync();
      }, () => MockClient((r) async => _reply(r)));
    });

    testWidgets('a main head without the admin power adds assistants only', (tester) async {
      _headsReply = {..._headsReply, 'can_manage_main': false, 'can_manage_assistants': true};
      await http.runWithClient(() async {
        await openForm(tester);
        // Cannot remove or demote the main head.
        expect(find.text('Remove'), findsNothing);
        await tester.enterText(find.byType(TextField), 'Kojo');
        await tester.pump(const Duration(milliseconds: 500));
        await _settle(tester);
        await tester.tap(find.text('Kojo Teacher'));
        await _settle(tester);
        expect(find.widgetWithText(OutlinedButton, 'Main head'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Assistant'), findsOneWidget);
      }, () => MockClient((r) async => _reply(r)));
      _headsReply = {..._headsReply, 'can_manage_main': true};
    });

    testWidgets('a refused save shows why and keeps the form open', (tester) async {
      await http.runWithClient(() async {
        await openForm(tester);
        await tester.tap(find.text('Remove'));
        await tester.pump();
        expect(find.text('No heads yet.'), findsOneWidget);
        final save = find.widgetWithText(FilledButton, 'Save heads');
        await tester.ensureVisible(save);
        await tester.pump();
        await tester.tap(save);
        await _settle(tester);
        expect(find.textContaining('A department needs a main head'), findsOneWidget);
        expect(find.text('Heads of Primary'), findsOneWidget);
      }, () => MockClient((r) async {
            if (r.method == 'PUT') return http.Response(jsonEncode({'message': 'A department needs a main head.'}), 422);
            return _reply(r);
          }));
    });
  });
}
