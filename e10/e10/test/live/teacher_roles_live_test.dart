@Tags(['live'])
library;

import 'dart:io';

import 'package:e10/api/api_session.dart';
import 'package:e10/auth.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's own API client, parser and store against a REAL backend (a
/// local server with the teacher-roles test accounts), not a mock:
///
///   E2E_API=http://127.0.0.1:8010/api flutter test test/live --tags live
///
/// Skipped unless E2E_API is set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = Platform.environment['E2E_API'];

  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=${api ?? ''}');
    SharedPreferences.setMockInitialValues({});
    // Real network, not flutter_test's blocked HttpClient.
    HttpOverrides.global = null;
  });

  Future<(SchoolStore, AppUser)> signedIn(String email) async {
    final result = await Auth.signIn(email: email, password: 'password');
    expect(result.ok, isTrue, reason: result.error);
    final store = SchoolStore()..applyUserSchool(result.user!);
    await store.syncFromApi(budget: const Duration(seconds: 60));
    store.stopLiveSync();
    return (store, result.user!);
  }

  test('Case C in the app: subject work and class report on one account', () async {
    final (store, user) = await signedIn('teacher.c@e2e.test');

    // Subject side, from the real assignment data.
    final subjects = store.mySubjectAssignments;
    expect(subjects.map((a) => '${a.subjectName} · ${a.className}'), ['E2E Science · E2E JHS 2A']);
    final jhs2a = subjects.single.classId;

    final error = await store.createAssignment(
      classId: jhs2a,
      subjectId: subjects.single.subjectId,
      title: 'App live exercise',
      type: 'exercise',
    );
    expect(error, isEmpty);
    final row = store.tableRows('assignments').firstWhere((r) => r['title'] == 'App live exercise');
    expect(row['type'], 'exercise');
    final kofi = store.studentsInClass(jhs2a).firstWhere((s) => s.name == 'E2E Kofi Boateng');
    final existing = await store.fetchSubmissions('${row['id']}');
    expect(existing.error, isEmpty);
    expect(
      await store.saveSubmissionMarks(assignmentId: '${row['id']}', maxScore: 10, scores: {kofi.id: 7}, existing: existing.rows),
      isEmpty,
    );

    // Class side: they are class teacher of 2B, not of 2A.
    final myClasses = store.classes.where((c) => store.isHomeroomClass(c, user)).map((c) => c.name);
    expect(myClasses, ['E2E JHS 2B']);
    final work2b = await store.fetchClassWork(classId: store.classes.firstWhere((c) => c.name == 'E2E JHS 2B').id);
    expect(work2b.error, isEmpty);
    expect(work2b.weight, 30);
    final work2a = await store.fetchClassWork(classId: jhs2a);
    expect(work2a.error, isNotEmpty); // not their class
  }, skip: api == null ? 'set E2E_API to run against a real backend' : false);

  test('Case B in the app: the class report is filled from subject teachers\' marks', () async {
    final (store, _) = await signedIn('teacher.b@e2e.test');
    expect(store.mySubjectAssignments, isEmpty);
    final jhs2a = store.classes.firstWhere((c) => c.name == 'E2E JHS 2A');
    final work = await store.fetchClassWork(classId: jhs2a.id);
    expect(work.error, isEmpty);
    final ama = store.students.firstWhere((s) => s.name == 'E2E Ama Owusu');
    // Maths marks from the subject teacher (Case A run): 75% of 30.
    expect(work.scores[ama.id]?.values, contains(22.5));
  }, skip: api == null ? 'set E2E_API to run against a real backend' : false);

  tearDownAll(() => ApiSession.instance.clear());
}
