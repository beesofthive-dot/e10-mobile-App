import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/attendance_screen.dart';

void main() {
  testWidgets('parent attendance screen shows Total/Present/Absent/Late/Excused as a grid', (tester) async {
    final store = SchoolStore();
    store.students.add(const Student(
      id: 'kid-1',
      name: 'Ama Owusu',
      klass: 'Basic 4',
      avatar: 'A',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
    ));
    store.tables['attendance'] = [
      {'student_id': 'kid-1', 'status': 'present', 'date': '2026-09-01'},
      {'student_id': 'kid-1', 'status': 'late', 'date': '2026-09-02'},
      {'student_id': 'kid-1', 'status': 'absent', 'date': '2026-09-03'},
      {'student_id': 'kid-1', 'status': 'excused', 'date': '2026-09-04'},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: AttendanceScreen(role: Role.parent, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => d != null).toList();
    debugPrint('Texts: $texts');

    expect(find.textContaining('4 days recorded'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Excused'), findsOneWidget);
    // Same buckets as the website: Present is on-time only, Late on its own,
    // and excused is not folded into absent — one of each here.
    expect(find.text('1'), findsNWidgets(4));
    expect(find.text('2'), findsNothing);
  });
}
