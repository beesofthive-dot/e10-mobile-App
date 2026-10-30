import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/widgets/student_profile_sheet.dart';

void main() {
  testWidgets('shows the student\'s safety-relevant and admission details', (tester) async {
    const student = Student(
      id: 'kid-1',
      name: 'Ama Owusu',
      klass: 'Basic 4',
      avatar: 'A',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
      dateOfBirth: '2016-03-12',
      gender: 'female',
      emergencyContactPhone: '0244000111',
      allergies: 'Peanuts',
      medicalNotes: 'Carries an inhaler',
      admissionDate: '2022-09-01',
      guardianName: 'Kojo Owusu',
      guardianRelationship: 'Father',
      guardianPhone: '0244000222',
    );

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: SchoolStore(),
          child: Builder(builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox());
          }),
        ),
      ),
    );

    showStudentProfileSheet(ctx, student);
    await tester.pumpAndSettle();

    expect(find.text('Ama Owusu'), findsOneWidget);
    expect(find.textContaining('Peanuts'), findsOneWidget);
    expect(find.textContaining('Carries an inhaler'), findsOneWidget);
    expect(find.text('0244000111'), findsOneWidget);
    expect(find.text('2016-03-12'), findsOneWidget);
    expect(find.text('Kojo Owusu'), findsOneWidget);
    expect(find.text('Father'), findsOneWidget);
  });

  testWidgets('no health notice banner when there is nothing to warn about', (tester) async {
    const student = Student(
      id: 'kid-1',
      name: 'Ama Owusu',
      klass: 'Basic 4',
      avatar: 'A',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
    );

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: SchoolStore(),
          child: Builder(builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox());
          }),
        ),
      ),
    );

    showStudentProfileSheet(ctx, student);
    await tester.pumpAndSettle();

    expect(find.text('Health notice'), findsNothing);
  });
}
