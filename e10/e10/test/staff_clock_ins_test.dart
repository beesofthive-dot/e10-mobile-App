import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_home.dart';

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

void main() {
  test("staffAttendanceToday keeps only today's staff rows, newest first", () {
    final store = SchoolStore();
    final day = _today();
    store.tables['attendance'] = [
      {'id': 'a', 'staff_id': 's1', 'date': day, 'check_in_at': '${day}T07:10:00', 'staff': {'full_name': 'Kofi Boateng'}},
      {'id': 'b', 'staff_id': 's2', 'date': day, 'check_in_at': '${day}T07:40:00', 'status': 'late'},
      {'id': 'c', 'student_id': 'k1', 'date': day, 'check_in_at': '${day}T07:00:00'},
      {'id': 'd', 'staff_id': 's1', 'date': '2020-01-01', 'check_in_at': '2020-01-01T07:00:00'},
    ];
    final rows = store.staffAttendanceToday();
    expect(rows.map((r) => r['id']), ['b', 'a']);
    expect(store.staffNameOf(rows.last), 'Kofi Boateng');
    expect(store.staffNameOf(rows.first), 'Staff member');
  });

  testWidgets('admin clock-ins card summarises and lists the latest scans', (tester) async {
    final day = _today();
    final rows = [
      {'id': 'b', 'staff_id': 's2', 'status': 'late', 'check_in_at': '${day}T07:40:00', 'staff': {'full_name': 'Ama Owusu'}},
      {'id': 'a', 'staff_id': 's1', 'status': 'present', 'check_in_at': '${day}T07:10:00', 'source': 'palm', 'staff': {'full_name': 'Kofi Boateng'}},
    ];
    final store = SchoolStore();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StaffClockInsCard(rows: rows, nameOf: store.staffNameOf, staffTotal: 5, onOpen: () {}),
      ),
    ));
    expect(find.text('Staff clock-ins today'), findsOneWidget);
    expect(find.text('2 of 5 staff in · 1 late · 0 clocked out · 3 not in yet'), findsOneWidget);
    expect(find.text('Kofi Boateng'), findsOneWidget);
    expect(find.text('Palm scan'), findsOneWidget);
    expect(find.textContaining('Late ·'), findsOneWidget);
  });
}
