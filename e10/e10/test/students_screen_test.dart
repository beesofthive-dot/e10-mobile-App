import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/students_screen.dart';

void main() {
  testWidgets('empty student list shows an empty-state message',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolScope(
            store: SchoolStore(),
            child: StudentsScreen(onLogout: () {}),
          ),
        ),
      ),
    );

    expect(find.text('No students yet.'), findsOneWidget);
  });
}
