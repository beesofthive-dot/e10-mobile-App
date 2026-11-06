import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_home.dart';

void main() {
  testWidgets('admin dashboard renders every section with an empty school', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolScope(
            store: SchoolStore(),
            child: AdminHome(user: const AppUser(email: 'admin@school.test', displayName: 'Ama Mensah', role: Role.schoolAdmin, subtitle: 'School Admin'), onNav: (_) {}, onLogout: () {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Total students'), findsOneWidget);

    await tester.drag(find.text('Total students'), const Offset(0, -1200));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Attendance today'), findsOneWidget);
    expect(find.text('Exams & reports'), findsOneWidget);
    expect(find.text('Jump in'), findsOneWidget);
  });

  testWidgets('Staff card next to Classes opens the staff page', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final store = SchoolStore();
    store.tables['staff'] = [
      {'id': 's1', 'full_name': 'Ama Boateng', 'category': 'teacher'},
      {'id': 's2', 'full_name': 'Yaw Darko', 'category': 'driver'},
    ];
    AppScreen? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolScope(
            store: store,
            child: AdminHome(
              user: const AppUser(email: 'admin@school.test', displayName: 'Ama Mensah', role: Role.schoolAdmin, subtitle: 'School Admin'),
              onNav: (s) => opened = s,
              onLogout: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final card = find.text('Staff details');
    await tester.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(card);
    await tester.pump();
    expect(opened, AppScreen.adminStaff);
    expect(tester.takeException(), isNull);
  });
}
