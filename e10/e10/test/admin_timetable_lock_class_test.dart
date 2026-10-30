import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_timetable.dart';

void main() {
  testWidgets('lockClass hides the class picker and shows only that class\'s periods', (tester) async {
    final store = SchoolStore();
    store.classes.addAll([
      NamedRecord(id: 'c1', name: 'Basic 3'),
      NamedRecord(id: 'c2', name: 'Basic 4'),
    ]);
    store.timetable.addAll([
      TimeSlot(id: 't1', className: 'Basic 3', day: 'Monday', start: '08:00', end: '08:45', subject: 'Maths', teacher: 'Mr. A', room: 'Rm 1'),
      TimeSlot(id: 't2', className: 'Basic 4', day: 'Monday', start: '09:00', end: '09:45', subject: 'English', teacher: 'Mrs. B', room: 'Rm 2'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: AdminTimetableScreen(
            onBack: () {},
            onLogout: () {},
            viewOnly: true,
            lockClass: 'Basic 4',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Locked to the child's class: no class dropdown to browse other classes.
    expect(find.text('Class'), findsNothing);
    // Only the locked class's period shows, not another class's.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Maths'), findsNothing);
  });

  testWidgets('without lockClass the class picker is shown (staff view)', (tester) async {
    final store = SchoolStore();
    store.classes.addAll([
      NamedRecord(id: 'c1', name: 'Basic 3'),
      NamedRecord(id: 'c2', name: 'Basic 4'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: AdminTimetableScreen(
            onBack: () {},
            onLogout: () {},
            viewOnly: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Class'), findsOneWidget);
  });
}
