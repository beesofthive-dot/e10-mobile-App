import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_home.dart';
import 'package:e10/widgets/motion.dart';

void main() {
  const admin = AppUser(email: 'admin@school.test', displayName: 'Admin', role: Role.schoolAdmin, subtitle: 'School Admin');

  Widget app(SchoolStore store) => MaterialApp(
        home: Scaffold(
          body: SchoolScope(
            store: store,
            child: AdminHome(user: admin, onNav: (_) {}, onLogout: () {}),
          ),
        ),
      );

  testWidgets('first load shows placeholders, then the real dashboard animates in', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final store = SchoolStore()..loading = true;
    await tester.pumpWidget(app(store));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Total students'), findsNothing);

    store
      ..loading = false
      ..notifyListeners();
    await tester.pumpWidget(app(store));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(DashboardSkeleton), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Total students'), findsOneWidget);
  });

  testWidgets('numbers count up and land on the exact value and format', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Column(children: [CountUpText('1,234'), CountUpText('GHS 12.5K'), CountUpText('87%'), CountUpText('No staff')]),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1,234'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('GHS 12.5K'), findsOneWidget);
    expect(find.text('87%'), findsOneWidget);
    expect(find.text('No staff'), findsOneWidget);
  });
}
