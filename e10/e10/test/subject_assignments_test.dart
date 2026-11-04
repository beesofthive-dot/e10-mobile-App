import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/subject_assignments_screen.dart';

void main() {
  testWidgets('subject assignments lists every teacher and their homeroom', (tester) async {
    final store = SchoolStore();
    store.teachers.add(NamedRecord(id: 't1', name: 'Afia Mensah', extra: 'Primary'));
    store.classes.add(NamedRecord(id: 'c1', name: 'Basic 4', link: 'Afia Mensah'));
    await tester.pumpWidget(MaterialApp(
      home: SchoolScope(store: store, child: const Scaffold(body: SubjectAssignmentsScreen())),
    ));
    await tester.pump();
    expect(find.text('Afia Mensah'), findsOneWidget);
    expect(find.text('Class teacher: Basic 4'), findsOneWidget);
    expect(find.text('No subjects assigned'), findsOneWidget);
  });
}
