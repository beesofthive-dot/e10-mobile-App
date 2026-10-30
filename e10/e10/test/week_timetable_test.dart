import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_timetable.dart';
import 'package:e10/widgets/home_cards.dart';

TimeSlot _slot(String day, String start, String subject, {String kind = 'lesson', String teacherId = '', String klass = 'JHS 2A'}) =>
    TimeSlot(id: '$day$start', className: klass, day: day, start: start, end: '', subject: subject, teacher: 'T', room: '', kind: kind, teacherId: teacherId);

Widget _app(SchoolStore store, Widget child) =>
    MaterialApp(home: Scaffold(body: SchoolScope(store: store, child: SingleChildScrollView(child: child))));

void main() {
  tearDown(() => ApiSession.instance.user = null);

  test('periods sort by real time, not as text', () {
    final day = SchoolStore.slotsForDay([
      _slot('Monday', '10:00', 'Science'),
      _slot('Monday', '8:00', 'Maths'),
      _slot('Monday', '1:05 PM', 'History'),
      _slot('Tuesday', '07:00', 'Not Monday'),
    ], 'Monday');
    expect(day.map((s) => s.subject), ['Maths', 'Science', 'History']);
  });

  testWidgets('dashboard timetable is arranged by day, Monday to Friday', (tester) async {
    final slots = [
      _slot('Monday', '10:30', 'Break', kind: 'break'),
      _slot('Monday', '08:00', 'Maths'),
      _slot('Tuesday', '09:00', 'English'),
    ];
    await tester.pumpWidget(_app(SchoolStore(), WeekTimetableCard(slots: slots, onOpen: () {})));

    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      expect(find.textContaining(d), findsWidgets);
    }
    // No weekend tabs when the school has no weekend lessons.
    expect(find.textContaining('Sat'), findsNothing);

    await tester.tap(find.textContaining('Mon').first);
    await tester.pump();
    expect(find.textContaining('Maths'), findsOneWidget);
    expect(find.textContaining('Break'), findsOneWidget);
    expect(find.textContaining('English'), findsNothing);
    expect(tester.getTopLeft(find.textContaining('Maths')).dy, lessThan(tester.getTopLeft(find.textContaining('Break')).dy));

    await tester.tap(find.textContaining('Tue').first);
    await tester.pump();
    expect(find.textContaining('English'), findsOneWidget);
    expect(find.textContaining('Maths'), findsNothing);

    await tester.tap(find.textContaining('Wed').first);
    await tester.pump();
    expect(find.text('Nothing scheduled on Wednesday.'), findsOneWidget);
  });

  testWidgets('a teacher\'s timetable opens on their own lessons, like the website\'s "mine"', (tester) async {
    ApiSession.instance.user = {
      'id': 'u1',
      'staff': {'id': 'me'},
    };
    final store = SchoolStore();
    store.classes.add(NamedRecord(id: 'c1', name: 'JHS 2A'));
    store.timetable.addAll([
      _slot('Monday', '08:00', 'My Maths', teacherId: 'me'),
      _slot('Monday', '09:00', 'Their French', teacherId: 'other'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SchoolScope(
          store: store,
          child: AdminTimetableScreen(onBack: () {}, onLogout: () {}, viewOnly: true, teacherView: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('My Maths'), findsOneWidget);
    expect(find.text('Their French'), findsNothing);

    await tester.tap(find.text('Class timetable'));
    await tester.pumpAndSettle();
    expect(find.text('Their French'), findsOneWidget);
  });
}
