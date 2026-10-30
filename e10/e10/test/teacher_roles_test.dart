import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/academic_report_screen.dart';
import 'package:e10/screens/homework_screen.dart';
import 'package:e10/screens/teacher_home.dart';

const _me = 'staff-me';
const _mathsId = '01a0d810-0000-7000-8000-0000000000a1';
const _scienceId = '01a0d810-0000-7000-8000-0000000000a2';
const _jhs2a = '01a0d810-0000-7000-8000-0000000000c1';
const _jhs2b = '01a0d810-0000-7000-8000-0000000000c2';
const _pupil = '01a0d810-0000-7000-8000-0000000000e1';

const _teacher = AppUser(email: 'afia@school.test', displayName: 'Afia Mensah', role: Role.teacher, subtitle: 'Teacher');

/// A teacher who teaches Maths in JHS 2A and Science in JHS 2B, and is
/// optionally the class teacher of JHS 2A — one account either way.
SchoolStore _store({required bool teachesSubjects, required bool classTeacher}) {
  ApiSession.instance.user = {
    'id': 'user-me',
    'staff': {'id': _me},
  };
  final store = SchoolStore();
  store.classes.addAll([
    NamedRecord(id: _jhs2a, name: 'JHS 2A', userId: classTeacher ? 'user-me' : ''),
    NamedRecord(id: _jhs2b, name: 'JHS 2B'),
  ]);
  store.tables['school_classes'] = [
    {'id': _jhs2a, 'name': 'JHS 2A', if (classTeacher) 'class_teacher_id': _me},
    {'id': _jhs2b, 'name': 'JHS 2B'},
  ];
  store.tables['subjects'] = [
    {'id': _mathsId, 'name': 'Mathematics'},
    {'id': _scienceId, 'name': 'Science'},
    {'id': 'other', 'name': 'French'},
  ];
  store.tables['teacher_subject_assignments'] = [
    if (teachesSubjects) ...[
      {'staff_id': _me, 'class_id': _jhs2a, 'subject_id': _mathsId, 'subject': {'name': 'Mathematics'}, 'class': {'name': 'JHS 2A'}},
      {'staff_id': _me, 'class_id': _jhs2b, 'subject_id': _scienceId, 'subject': {'name': 'Science'}, 'class': {'name': 'JHS 2B'}},
    ],
    // Another teacher's assignment in the same class (visible to a class teacher).
    {'staff_id': 'someone-else', 'class_id': _jhs2a, 'subject_id': 'other', 'subject': {'name': 'French'}, 'class': {'name': 'JHS 2A'}},
  ];
  return store;
}

Widget _app(SchoolStore store, Widget child) => MaterialApp(home: Scaffold(body: SchoolScope(store: store, child: child)));

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    ApiSession.instance.user = null;
    ApiSession.instance.token = null;
  });

  group('the teacher dashboard shows functions by real assignment', () {
    Future<void> pumpHome(WidgetTester tester, SchoolStore store) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(store, TeacherHome(user: _teacher, onNav: (_) {}, onLogout: () {})));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('Case A — subject teacher only: My Subjects, no My Class', (tester) async {
      await pumpHome(tester, _store(teachesSubjects: true, classTeacher: false));
      expect(find.text('My Subjects'), findsOneWidget);
      expect(find.text('Mathematics · JHS 2A'), findsOneWidget);
      expect(find.text('Science · JHS 2B'), findsOneWidget);
      expect(find.text('French · JHS 2A'), findsNothing);
      expect(find.text('My Class'), findsNothing);
      expect(find.text('Mark work'), findsOneWidget);
    });

    testWidgets('Case B — class teacher only: My Class, no subjects', (tester) async {
      await pumpHome(tester, _store(teachesSubjects: false, classTeacher: true));
      expect(find.text('My Class'), findsOneWidget);
      expect(find.text('JHS 2A — Class Teacher'), findsOneWidget);
      expect(find.text('JHS 2B — Class Teacher'), findsNothing);
      expect(find.text('My Subjects'), findsNothing);
      expect(find.text('Set homework'), findsNothing);
    });

    testWidgets('Case C — both, on one dashboard', (tester) async {
      await pumpHome(tester, _store(teachesSubjects: true, classTeacher: true));
      expect(find.text('My Subjects'), findsOneWidget);
      expect(find.text('Mathematics · JHS 2A'), findsOneWidget);
      expect(find.text('My Class'), findsOneWidget);
      expect(find.text('JHS 2A — Class Teacher'), findsOneWidget);
    });
  });

  testWidgets('a subject teacher can only pick their own subjects for a class', (tester) async {
    final store = _store(teachesSubjects: true, classTeacher: false);
    await tester.pumpWidget(_app(store, HomeworkScreen(user: _teacher, onLogout: () {})));
    await tester.tap(find.text('Create Assignment'));
    await tester.pumpAndSettle();

    // All four kinds of class work.
    expect(find.text('Type'), findsOneWidget);
    await tester.tap(find.text('Homework').last);
    await tester.pumpAndSettle();
    for (final t in ['Assignment', 'Exercise', 'Class test']) {
      expect(find.text(t), findsWidgets);
    }
    await tester.tap(find.text('Class test').last);
    await tester.pumpAndSettle();
    expect(find.text('MARKED OUT OF'), findsOneWidget);

    // Subjects follow the chosen class: Maths in JHS 2A, never French.
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Science'), findsNothing);
    expect(find.text('French'), findsNothing);
  });

  testWidgets('a teacher sees only their own work; another teacher\'s never shows', (tester) async {
    final store = _store(teachesSubjects: true, classTeacher: false);
    store.tables['assignments'] = [
      {'id': 'a1', 'title': 'Fractions', 'type': 'exercise', 'teacher_id': _me, 'class_id': _jhs2a, 'subject_id': _mathsId, 'subject': {'name': 'Mathematics'}},
      {'id': 'a2', 'title': 'French verbs', 'type': 'homework', 'teacher_id': 'someone-else', 'class_id': _jhs2a, 'subject_id': 'other', 'subject': {'name': 'French'}},
    ];
    await tester.pumpWidget(_app(store, HomeworkScreen(user: _teacher, onLogout: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Fractions'), findsOneWidget);
    expect(find.text('French verbs'), findsNothing);
    // Not a class teacher: no class-wide view either.
    expect(find.text('My class (all subjects)'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Mark'), findsOneWidget);
  });

  testWidgets('a class teacher can review every subject\'s work in their class, read-only', (tester) async {
    final store = _store(teachesSubjects: true, classTeacher: true);
    store.tables['assignments'] = [
      {'id': 'a1', 'title': 'Fractions', 'type': 'exercise', 'teacher_id': _me, 'class_id': _jhs2a, 'subject_id': _mathsId, 'subject': {'name': 'Mathematics'}},
      {'id': 'a2', 'title': 'French verbs', 'type': 'homework', 'teacher_id': 'someone-else', 'class_id': _jhs2a, 'subject_id': 'other', 'subject': {'name': 'French'}},
      {'id': 'a3', 'title': 'Other class work', 'type': 'homework', 'teacher_id': 'someone-else', 'class_id': _jhs2b, 'subject_id': 'other', 'subject': {'name': 'French'}},
    ];
    await tester.pumpWidget(_app(store, HomeworkScreen(user: _teacher, onLogout: () {})));
    await tester.pumpAndSettle();

    // Default "Mine": only their own.
    expect(find.text('Fractions'), findsOneWidget);
    expect(find.text('French verbs'), findsNothing);

    await tester.tap(find.text('My class (all subjects)'));
    await tester.pumpAndSettle();
    expect(find.text('Fractions'), findsOneWidget);
    expect(find.text('French verbs'), findsOneWidget);
    expect(find.text('Other class work'), findsNothing);
    // Another teacher's work: no Edit / Delete / Mark menu.
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  testWidgets('the dashboard homework count is only the teacher\'s own work', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final store = _store(teachesSubjects: true, classTeacher: false);
    store.tables['assignments'] = [
      {'id': 'a1', 'title': 'Mine', 'teacher_id': _me, 'class_id': _jhs2a, 'subject_id': _mathsId},
      {'id': 'a2', 'title': 'Theirs', 'teacher_id': 'someone-else', 'class_id': _jhs2a, 'subject_id': 'other'},
      {'id': 'a3', 'title': 'Theirs too', 'teacher_id': 'someone-else', 'class_id': _jhs2a, 'subject_id': 'other'},
    ];
    await tester.pumpWidget(_app(store, TeacherHome(user: _teacher, onNav: (_) {}, onLogout: () {})));
    await tester.pump(const Duration(seconds: 1));
    final homeworkStat = find.ancestor(of: find.text('Homework'), matching: find.byType(Column)).first;
    expect(find.descendant(of: homeworkStat, matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: homeworkStat, matching: find.text('3')), findsNothing);
  });

  testWidgets('a subject teacher sees how their marks reach the report, with no report form', (tester) async {
    final store = _store(teachesSubjects: true, classTeacher: false);
    await tester.pumpWidget(_app(store, AcademicReportScreen(user: _teacher, onBack: () {}, onLogout: () {})));
    await tester.pump();
    expect(find.textContaining('automatically contribute to the class report'), findsOneWidget);
    expect(find.text('Send records to class teacher'), findsNothing);
    expect(find.text('Input report'), findsNothing);
  });

  testWidgets('a class teacher gets the report form', (tester) async {
    final store = _store(teachesSubjects: false, classTeacher: true);
    await tester.pumpWidget(_app(store, AcademicReportScreen(user: _teacher, onBack: () {}, onLogout: () {})));
    await tester.pump();
    expect(find.text('Input report'), findsOneWidget);
  });

  test('class work comes from the school server, with the school\'s split', () async {
    final store = _store(teachesSubjects: false, classTeacher: true);
    ApiSession.instance.token = 'test-token';
    store.academicTermId = '01a0d810-0000-7000-8000-0000000000f1';
    final work = await http.runWithClient(
      () => store.fetchClassWork(classId: _jhs2a),
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/report-cards/class-work'));
        expect(request.url.queryParameters['class_id'], _jhs2a);
        return http.Response(
          jsonEncode({
            'data': {
              'class_score_weight': 40,
              'students': [
                {
                  'student_id': _pupil,
                  'subjects': [
                    {'subject_id': _mathsId, 'class_score': 32, 'percent': 80, 'items': 3},
                  ],
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    expect(work.error, isEmpty);
    expect(work.weight, 40);
    expect(store.classScoreWeight, 40);
    expect(work.scores[_pupil]?[_mathsId], 32);
  });

  test('marks are saved to the school server and must fit the maximum', () async {
    final store = _store(teachesSubjects: true, classTeacher: false);
    ApiSession.instance.token = 'test-token';
    final sent = <Map<String, dynamic>>[];
    final error = await http.runWithClient(
      () => store.saveSubmissionMarks(
        assignmentId: 'a1',
        maxScore: 10,
        scores: {_pupil: 8, 'blank': null},
        existing: const [],
      ),
      () => MockClient((request) async {
        if (request.method == 'POST') sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'data': {'id': 'x'}}), request.method == 'POST' ? 201 : 200);
      }),
    );
    expect(error, isEmpty);
    expect(sent.single, containsPair('student_id', _pupil));
    expect(sent.single, containsPair('score', 8));
    expect(sent.single, containsPair('max_score', 10));
    expect(sent.single, containsPair('status', 'marked'));

    expect(await store.saveSubmissionMarks(assignmentId: 'a1', maxScore: 10, scores: {_pupil: 12}, existing: const []), contains('between 0 and 10'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    store.stopLiveSync();
  });
}
