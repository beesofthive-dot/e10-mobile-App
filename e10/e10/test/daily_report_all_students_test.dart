import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/teacher_daily_reports_screen.dart';

const _caregiver = AppUser(
  email: '',
  displayName: 'Afia Mensah',
  role: Role.teacher,
  subtitle: 'After-school care',
  dailyReportsEligible: true,
);

void main() {
  testWidgets('a teacher with no homeroom class lands on "All students" instead of a dead end', (tester) async {
    final store = SchoolStore();
    store.classes.addAll([
      NamedRecord(id: 'c1', name: 'Basic 1'),
      NamedRecord(id: 'c2', name: 'Basic 2'),
    ]);
    store.students.addAll(const [
      Student(id: 's1', name: 'Kojo Ansah', klass: 'Basic 1', classId: 'c1', avatar: 'K', attendance: 0, fees: 0, outstanding: 0, status: 'active'),
      Student(id: 's2', name: 'Ama Boadi', klass: 'Basic 2', classId: 'c2', avatar: 'A', attendance: 0, fees: 0, outstanding: 0, status: 'active'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: TeacherDailyReportsScreen(user: _caregiver, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No more "not set as class teacher" dead end.
    expect(find.textContaining('not set as the class teacher'), findsNothing);
    // Both classes' students are visible, spanning homerooms.
    expect(find.text('All students'), findsOneWidget);
    expect(find.text('Kojo Ansah'), findsOneWidget);
    expect(find.text('Ama Boadi'), findsOneWidget);
  });

  testWidgets('switching the class picker to a specific class filters the roster', (tester) async {
    final store = SchoolStore();
    store.classes.addAll([
      NamedRecord(id: 'c1', name: 'Basic 1'),
      NamedRecord(id: 'c2', name: 'Basic 2'),
    ]);
    store.students.addAll(const [
      Student(id: 's1', name: 'Kojo Ansah', klass: 'Basic 1', classId: 'c1', avatar: 'K', attendance: 0, fees: 0, outstanding: 0, status: 'active'),
      Student(id: 's2', name: 'Ama Boadi', klass: 'Basic 2', classId: 'c2', avatar: 'A', attendance: 0, fees: 0, outstanding: 0, status: 'active'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: TeacherDailyReportsScreen(user: _caregiver, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All students'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic 1').last);
    await tester.pumpAndSettle();

    expect(find.text('Kojo Ansah'), findsOneWidget);
    expect(find.text('Ama Boadi'), findsNothing);
  });
}
