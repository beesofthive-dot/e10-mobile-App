import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/attendance_screen.dart';

const _teacher = AppUser(
  email: '',
  displayName: 'Afia Mensah',
  role: Role.teacher,
  subtitle: 'Class teacher',
);

void main() {
  testWidgets('a class teacher can reach and mark the Boarders roster', (tester) async {
    final store = SchoolStore();
    // `link` matching the teacher's display name (case-insensitively) is
    // how isHomeroomClass recognizes a homeroom without needing a live
    // session — see school_store.dart's isHomeroomClass.
    store.classes.add(NamedRecord(id: 'c1', name: 'Basic 4', link: 'Afia Mensah'));
    store.students.addAll(const [
      Student(id: 's1', name: 'Kojo Ansah', klass: 'Basic 4', classId: 'c1', avatar: 'K', attendance: 0, fees: 0, outstanding: 0, status: 'active', boarder: true),
      Student(id: 's2', name: 'Ama Boadi', klass: 'Basic 5', classId: 'c2', avatar: 'A', attendance: 0, fees: 0, outstanding: 0, status: 'active', boarder: true),
      Student(id: 's3', name: 'Yaw Serwaa', klass: 'Basic 4', classId: 'c1', avatar: 'Y', attendance: 0, fees: 0, outstanding: 0, status: 'active'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: AttendanceScreen(role: Role.teacher, user: _teacher, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The picker offers a "Boarders" entry alongside the teacher's homeroom.
    expect(find.text('Boarders'), findsOneWidget);

    await tester.tap(find.text('Boarders'));
    await tester.pumpAndSettle();

    // Boarders from every class show up, not just the teacher's own homeroom.
    expect(find.text('Kojo Ansah'), findsOneWidget);
    expect(find.text('Ama Boadi'), findsOneWidget);
    expect(find.text('Yaw Serwaa'), findsNothing);

    // It must actually be editable, not silently read-only — the P/L/A tap
    // targets only render when canEdit is true.
    expect(find.text('P'), findsWidgets);
  });
}
