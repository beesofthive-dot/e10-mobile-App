import 'package:e10/app_prefs.dart';
import 'package:e10/message_read_prefs.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_home.dart';
import 'package:e10/screens/parent_home.dart';
import 'package:e10/screens/teacher_home.dart';
import 'package:e10/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _dashboard(SchoolStore store, Widget home) {
  final prefs = AppPrefs();
  return AppPrefsScope(
    prefs: prefs,
    child: SchoolScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light, seed: const Color(0xFFD97706)),
        home: ListenableBuilder(
          listenable: store,
          builder: (_, child) => Scaffold(body: home),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MessageReadPrefs.instance.resetMemory();
  });

  test('remembered thread stays read after prefs reload', () async {
    final prefs = MessageReadPrefs.instance;
    await prefs.load('e:parent@demo.school');
    prefs.remember(['m-1'], "Ama performed very well in today's test. Keep it up!");
    await prefs.save();

    prefs.resetMemory();
    await prefs.load('e:parent@demo.school');
    expect(
      prefs.isRead(['m-1'], "Ama performed very well in today's test. Keep it up!"),
      isTrue,
    );
    expect(prefs.isRead(['m-1'], 'A new reply arrived'), isFalse);
    expect(prefs.isRead(['m-2'], "Ama performed very well in today's test. Keep it up!"), isFalse);
  });

  testWidgets('parent, teacher and admin dashboards show a read conversation as Read', (tester) async {
    tester.view.physicalSize = const Size(448, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> expectDashboardShowsRead({
      required Role role,
      required Widget Function(AppUser user) home,
    }) async {
      final user = AppUser(email: 'someone@school.test', displayName: 'Test User', role: role, subtitle: role.label);
      final store = SchoolStore()..applyUserSchool(user);
      store.messages.add(ChatPreview(
        id: 'thread-1',
        from: 'Kojo Owusu',
        role: 'Parent',
        time: DateTime.now().toIso8601String(),
        preview: 'Thank you for the update.',
        unread: false,
        avatar: 'K',
        audience: [role],
      ));

      await tester.pumpWidget(_dashboard(store, home(user)));
      await tester.pump();
      final list = find.byType(Scrollable);
      if (list.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(find.text('Open chats'), 200, scrollable: list.first, maxScrolls: 60);
        await tester.pump();
      }
      expect(find.text('Open chats'), findsWidgets, reason: '$role dashboard should show messages');
      expect(find.text('Read'), findsWidgets, reason: '$role dashboard should show Read');
    }

    await expectDashboardShowsRead(
      role: Role.parent,
      home: (user) => ParentHome(user: user, onNav: (_) {}, onLogout: () {}),
    );
    await expectDashboardShowsRead(
      role: Role.teacher,
      home: (user) => TeacherHome(user: user, onNav: (_) {}, onLogout: () {}),
    );
    await expectDashboardShowsRead(
      role: Role.schoolAdmin,
      home: (user) => AdminHome(user: user, onNav: (_) {}, onLogout: () {}),
    );
  });
}
