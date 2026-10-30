import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/homework_screen.dart';

const _parent = AppUser(
  email: '',
  displayName: 'Test Guardian',
  role: Role.parent,
  subtitle: 'Parent',
);

void main() {
  testWidgets('homework instructions are shown, not just the title', (tester) async {
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
    store.tables['assignments'] = [
      {
        'id': 'a1',
        'title': 'Fractions worksheet',
        'subject': {'name': 'Mathematics'},
        'student_id': 'kid-1',
        'deadline': '2026-09-20',
        'instructions': 'Complete pages 12-14 and show your working.',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: HomeworkScreen(user: _parent, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fractions worksheet'), findsOneWidget);
    expect(find.textContaining('Complete pages 12-14'), findsOneWidget);
  });
}
