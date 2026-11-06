import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_staff_screen.dart';

Future<void> _pump(WidgetTester tester, {Size size = const Size(400, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = SchoolStore();
  store.tables['staff'] = [
    {
      'id': 's1',
      'full_name': 'Ama Boateng',
      'category': 'teacher',
      'position': 'Mathematics Teacher',
      'phone': '0241234567',
      'email': 'ama@example.com',
      'status': 'active',
      'department': {'name': 'Upper Primary'},
      'roles': [
        {'name': 'Teacher', 'slug': 'teacher'},
      ],
    },
    {
      'id': 's2',
      'full_name': 'Kwesi Mensah',
      'category': 'accountant',
      'position': 'Bursar',
      'phone': '0209876543',
      'status': 'on_leave',
    },
    {'id': 's3', 'full_name': 'Yaw Darko', 'category': 'driver', 'status': 'active'},
  ];
  store.tables['school_classes'] = [
    {'id': 'c1', 'name': 'Basic 5', 'stream': 'A', 'teacher_ids': ['s1']},
  ];
  await tester.pumpWidget(
    MaterialApp(
      home: SchoolScope(store: store, child: Scaffold(body: AdminStaffScreen(onBack: () {}))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every staff member with category filters', (tester) async {
    await _pump(tester);
    expect(find.text('Ama Boateng'), findsOneWidget);
    expect(find.text('Kwesi Mensah'), findsOneWidget);
    expect(find.text('Yaw Darko'), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('On leave'), findsOneWidget);

    await tester.tap(find.text('Driver (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Yaw Darko'), findsOneWidget);
    expect(find.text('Ama Boateng'), findsNothing);
  });

  testWidgets('search filters by position', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'bursar');
    await tester.pumpAndSettle();
    expect(find.text('Kwesi Mensah'), findsOneWidget);
    expect(find.text('Ama Boateng'), findsNothing);
  });

  testWidgets('tapping a staff member opens their details', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Ama Boateng'));
    await tester.pumpAndSettle();
    expect(find.text('Staff details'), findsOneWidget);
    expect(find.text('ama@example.com'), findsOneWidget);
    expect(find.text('Upper Primary'), findsOneWidget);
    expect(find.text('Basic 5 · A'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow on a small phone', (tester) async {
    await _pump(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ama Boateng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
