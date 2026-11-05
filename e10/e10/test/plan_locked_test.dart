import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/app.dart';
import 'package:e10/app_prefs.dart';
import 'package:e10/auth.dart';
import 'package:e10/data.dart';
import 'package:e10/models.dart';
import 'package:e10/plan_access.dart';
import 'package:e10/school_store.dart';
import 'package:e10/theme.dart';

Future<void> _open(WidgetTester tester, AppUser user, AppScreen screen) async {
  SharedPreferences.setMockInitialValues({});
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
}

void main() {
  test('reads plan modules and access level from the auth reply', () {
    final user = Auth.userFromApi({
      'roles': ['teacher'],
      'staff': {'full_name': 'Ama'},
      'school': {
        'id': 's1',
        'name': 'Hill School',
        'modules': ['attendance', 'messages'],
        'plan': {'grade': 'C', 'name': 'Starter'},
      },
      'subscription_access': {'access_level': 'full'},
    });
    expect(user.schoolModules, ['attendance', 'messages']);
    expect(user.planGrade, 'C');
    expect(user.planName, 'Starter');
    expect(user.accessLevel, 'full');
    expect(Auth.userFromApi({'roles': ['teacher'], 'staff': {}}).schoolModules, isNull);
  });

  testWidgets('a module outside the plan explains itself', (tester) async {
    const user = AppUser(
      email: 't@school.test',
      displayName: 'Ama',
      role: Role.teacher,
      subtitle: 'Teacher',
      schoolModules: ['attendance'],
      planName: 'Starter',
    );
    await _open(tester, user, AppScreen.homework);
    expect(find.text('Not part of your plan'), findsWidgets);
    expect(find.textContaining("Timetable & assignments is not included in your school's Starter plan"), findsOneWidget);
  });

  testWidgets('a module in the plan opens normally', (tester) async {
    const user = AppUser(
      email: 't@school.test',
      displayName: 'Ama',
      role: Role.teacher,
      subtitle: 'Teacher',
      schoolModules: ['messages'],
    );
    await _open(tester, user, AppScreen.messages);
    expect(find.text('Not part of your plan'), findsNothing);
  });

  testWidgets('a locked school says so on every screen', (tester) async {
    const user = AppUser(
      email: 'p@school.test',
      displayName: 'Kofi',
      role: Role.parent,
      subtitle: 'Parent',
      school: 'Hill School',
      accessLevel: 'none',
    );
    await _open(tester, user, AppScreen.parentHome);
    expect(find.text('Temporarily unavailable'), findsOneWidget);
    expect(find.textContaining('e10 is temporarily unavailable for Hill School'), findsOneWidget);
  });

  group('modules outside the plan are hidden, not shown as errors', () {
    tearDown(() => PlanAccess.user = null);

    testWidgets('teacher: no homework, timetable or messages links', (tester) async {
      const user = AppUser(
        email: 't@school.test',
        displayName: 'Ama',
        role: Role.teacher,
        subtitle: 'Teacher',
        schoolModules: ['attendance'],
      );
      await _open(tester, user, AppScreen.teacherHome);
      expect(find.text('Homework'), findsNothing);
      expect(find.text('Set homework'), findsNothing);
      expect(find.text('My timetable'), findsNothing);
      expect(find.text('Open chats'), findsNothing);
      expect(find.text('Not part of your plan'), findsNothing);
    });

    testWidgets('teacher on a full plan still sees them', (tester) async {
      const user = AppUser(email: 't@school.test', displayName: 'Ama', role: Role.teacher, subtitle: 'Teacher');
      await _open(tester, user, AppScreen.teacherHome);
      expect(find.text('Homework'), findsWidgets);
    });

    testWidgets('parent: no fees or reports without those modules', (tester) async {
      const user = AppUser(
        email: 'p@school.test',
        displayName: 'Kofi',
        role: Role.parent,
        subtitle: 'Parent',
        schoolModules: ['attendance', 'announcements'],
      );
      await _open(tester, user, AppScreen.parentHome);
      expect(find.text('Fees'), findsNothing);
      expect(find.text('Reports'), findsNothing);
      expect(find.text('Timetable'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('admin: no transactions or finance card without fees', (tester) async {
      const user = AppUser(
        email: 'a@school.test',
        displayName: 'Esi',
        role: Role.schoolAdmin,
        subtitle: 'Admin',
        schoolModules: ['attendance'],
      );
      await _open(tester, user, AppScreen.adminHome);
      expect(find.text('Transactions'), findsNothing);
      expect(find.text('Fees in'), findsNothing);
      expect(find.text('Students present'), findsOneWidget);
    });

    for (final role in [Role.schoolAdmin, Role.parent, Role.teacher]) {
      for (final size in const [Size(360, 760), Size(800, 360)]) {
        testWidgets('${role.name} home with only core modules lays out at $size', (tester) async {
          tester.view.physicalSize = size * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final user = AppUser(email: 'x@school.test', displayName: 'X', role: role, subtitle: 'X', schoolModules: const []);
          await _open(tester, user, homeFor(role));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  for (final role in [Role.schoolAdmin, Role.teacher, Role.parent]) {
    testWidgets('${role.name} Messages shows chats only', (tester) async {
      final user = AppUser(email: 'x@school.test', displayName: 'X', role: role, subtitle: 'X');
      await _open(tester, user, AppScreen.messages);
      expect(find.text('Chats'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Messages'), findsWidgets);
    });
  }
}
