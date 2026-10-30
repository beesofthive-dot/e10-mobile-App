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
    expect(find.text('Students'), findsOneWidget);

    await tester.drag(find.text('Students'), const Offset(0, -600));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Attendance today'), findsOneWidget);
    expect(find.text('Exams & reports'), findsOneWidget);
    expect(find.text('Jump in'), findsOneWidget);
  });
}
