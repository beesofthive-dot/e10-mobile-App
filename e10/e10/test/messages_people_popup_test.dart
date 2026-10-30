import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:e10/api/api_session.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/messages_screen.dart';

const _admin = AppUser(
  email: '',
  displayName: 'Test Admin',
  role: Role.schoolAdmin,
  subtitle: 'Admin',
);
const _parent = AppUser(
  email: '',
  displayName: 'Kojo Owusu',
  role: Role.parent,
  subtitle: 'Parent',
);
const _teacher = AppUser(
  email: '',
  displayName: 'Afia Mensah',
  role: Role.teacher,
  subtitle: 'Teacher',
);

void main() {
  testWidgets('New message opens as a centered pop-up and sends to the picked student\'s guardian', (tester) async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api');
    ApiSession.instance.token = 'test-token';
    addTearDown(() => ApiSession.instance.token = null);
    final store = SchoolStore();
    store.students.add(const Student(
      id: '01a0d810-0000-7000-8000-00000000000a',
      name: 'Ama Owusu',
      klass: 'Basic 4',
      avatar: 'A',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
    ));
    store.tables['guardians'] = [
      {
        'id': 'g1',
        'user_id': '01a0d810-0000-7000-8000-00000000000b',
        'full_name': 'Kojo Owusu',
        'relationship': 'Father',
        'students': [
          {'id': '01a0d810-0000-7000-8000-00000000000a', 'full_name': 'Ama Owusu', 'class_name': 'Basic 4'},
        ],
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: MessagesScreen(user: _admin, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The page title under the school name says Messages.
    expect(find.text('Messages'), findsWidgets);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    // A centered Dialog with the shared pop-up header, not a bottom sheet.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('New message'), findsOneWidget);
    // No mode picker at all — admin only ever messages parents/guardians
    // here (school-wide messages to teachers are gone).
    expect(find.text('Parents'), findsNothing);
    expect(find.text('Teachers'), findsNothing);
    expect(find.text('About which student? *'), findsOneWidget);
    expect(find.text('Choose a student first'), findsOneWidget);

    await tester.tap(find.text('Select…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ama Owusu').last);
    await tester.pumpAndSettle();

    // The guardian is filled in from the chosen student.
    expect(find.text('Kojo Owusu'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Please pick up Ama at 3pm today.');
    await tester.pumpAndSettle();
    // The school server accepts it (a fake server here).
    await http.runWithClient(() async {
      await tester.tap(find.text('Send'));
      // Nothing should throw here — this is the exact send-then-close path
      // that used to race the store's deferred notifyListeners() against the
      // route pop and trip Flutter's InheritedElement assertion.
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'data': {'id': '01a0d810-0000-7000-8000-00000000000c'}}), 201);
      }
      return http.Response(jsonEncode({'data': []}), 200);
    }));

    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsNothing);
    // The confirmation shows on top, then clears itself.
    expect(find.text('Message sent.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('Message sent.'), findsNothing);
  });

  testWidgets('a teacher gets the same form as admin, limited to students in the classes they teach', (tester) async {
    final store = SchoolStore();
    // The server only returns a teacher's own classes (class + subject).
    store.classes.add(NamedRecord(id: 'c1', name: 'Basic 4'));
    store.students.addAll([
      const Student(
        id: 'kid-1',
        name: 'Ama Owusu',
        klass: 'Basic 4',
        classId: 'c1',
        avatar: 'A',
        attendance: 0,
        fees: 0,
        outstanding: 0,
        status: 'active',
      ),
      const Student(
        id: 'kid-2',
        name: 'Yaw Boateng',
        klass: 'Basic 5',
        classId: 'c2',
        avatar: 'Y',
        attendance: 0,
        fees: 0,
        outstanding: 0,
        status: 'active',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: MessagesScreen(user: _teacher, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    // Exactly admin's steps — no extra mode chips.
    expect(find.text('About which student? *'), findsOneWidget);
    expect(find.text("Send to (student's guardian) *"), findsOneWidget);
    expect(find.text('Class parents'), findsNothing);
    expect(find.text('Homework'), findsNothing);

    await tester.tap(find.text('Select…'));
    await tester.pumpAndSettle();
    expect(find.text('Ama Owusu'), findsWidgets);
    expect(find.text('Yaw Boateng'), findsNothing);
  });

  testWidgets('a parent gets the same form, picking their child then a teacher or admin', (tester) async {
    final store = SchoolStore();
    store.students.add(const Student(
      id: 'kid-1',
      name: 'Ama Owusu',
      klass: 'Basic 4',
      classId: 'c1',
      avatar: 'A',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
    ));
    store.tables['staff'] = [
      {'id': 's1', 'user_id': 'u-teacher', 'full_name': 'Afia Mensah', 'position': 'Teacher'},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: MessagesScreen(user: _parent, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(find.text('About which child? *'), findsOneWidget);
    expect(find.text('Send to (teacher or admin) *'), findsOneWidget);
    // Their only child and the first teacher are already picked.
    expect(find.text('Ama Owusu'), findsOneWidget);
    expect(find.text('Afia Mensah'), findsOneWidget);
  });

  testWidgets("a teacher picking a student gets that student's guardian from the student record", (tester) async {
    final store = SchoolStore();
    store.classes.add(NamedRecord(id: 'c1', name: 'Basic 4'));
    store.students.add(const Student(
      id: 'kid-1',
      name: 'Ama Owusu',
      klass: 'Basic 4',
      classId: 'c1',
      avatar: 'A',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
    ));
    // A teacher never downloads /guardians — only /students with guardians inside.
    store.tables['students'] = [
      {
        'id': 'kid-1',
        'full_name': 'Ama Owusu',
        'guardians': [
          {'id': 'g1', 'user_id': 'u1', 'full_name': 'Kojo Owusu', 'relationship': 'Father'},
        ],
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: MessagesScreen(user: _teacher, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ama Owusu').last);
    await tester.pumpAndSettle();

    expect(find.text('Kojo Owusu'), findsOneWidget);
    expect(find.text('No guardian found'), findsNothing);
  });
}
