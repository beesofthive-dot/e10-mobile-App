import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/school_life_screen.dart';

const _parent = AppUser(
  email: '',
  displayName: 'Test Guardian',
  role: Role.parent,
  subtitle: 'Parent',
);

void main() {
  testWidgets('parent Exams tab shows the score/grade/remark once published', (tester) async {
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
    store.tables['exams'] = [
      {
        'id': 'e1',
        'name': 'Mid-term Maths',
        'subject': {'name': 'Mathematics'},
        'class': {'name': 'Basic 4'},
        'exam_date': '2026-09-01',
        'published': true,
      },
    ];
    store.academics.add(AcademicMark(
      id: 'm1',
      student: 'Ama Owusu',
      klass: 'Basic 4',
      subject: 'Mathematics',
      term: 'Term 1',
      score: 87,
      grade: 'A',
      remark: 'Excellent work',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: SchoolLifeScreen(
            user: _parent,
            onBack: () {},
            onLogout: () {},
            initialTab: 'Exams',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Score 87%'), findsOneWidget);
    expect(find.textContaining('Grade A'), findsOneWidget);
    expect(find.textContaining('Excellent work'), findsOneWidget);
  });

  testWidgets('unpublished exam does not leak a score', (tester) async {
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
    store.tables['exams'] = [
      {
        'id': 'e1',
        'name': 'Mid-term Maths',
        'subject': {'name': 'Mathematics'},
        'class': {'name': 'Basic 4'},
        'exam_date': '2026-09-01',
        'published': false,
      },
    ];
    store.academics.add(AcademicMark(
      id: 'm1',
      student: 'Ama Owusu',
      klass: 'Basic 4',
      subject: 'Mathematics',
      term: 'Term 1',
      score: 87,
      grade: 'A',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: SchoolLifeScreen(
            user: _parent,
            onBack: () {},
            onLogout: () {},
            initialTab: 'Exams',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Score 87%'), findsNothing);
  });
}
