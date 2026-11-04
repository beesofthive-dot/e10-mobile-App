import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';

Student _kid(String id, {bool boarder = false, String status = 'active', String classId = 'c1'}) => Student(
      id: id,
      name: 'Kid $id',
      klass: 'Basic 4',
      classId: classId,
      avatar: 'K',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: status,
      boarder: boarder,
    );

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'));

  test('day students with no record today are the ones to mark absent', () async {
    final store = SchoolStore();
    store.students.addAll([
      _kid('s1'), // scanned in
      _kid('s2'), // no record → absent
      _kid('s3', boarder: true), // boarders: class teacher's register
      _kid('s4', status: 'withdrawn'), // not at school any more
      _kid('s5', classId: 'c2'), // other class
    ]);
    final client = MockClient((request) async => http.Response(
        jsonEncode({
          'data': [
            {'id': 'a1', 'student_id': 's1', 'status': 'present'},
          ],
          'meta': {'current_page': 1, 'last_page': 1},
        }),
        200));
    final all = await http.runWithClient(() => store.dayStudentsNotScanned('2026-11-04'), () => client);
    expect(all!.map((s) => s.id), ['s2', 's5']);
    final one = await http.runWithClient(() => store.dayStudentsNotScanned('2026-11-04', classId: 'c1'), () => client);
    expect(one!.map((s) => s.id), ['s2']);
  });

  test('marking sends Absent "No palm scan" like the website and counts failures', () async {
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sent.add(body);
        if (body['staff_id'] == 't2') {
          return http.Response(jsonEncode({'message': 'Manual teacher attendance is limited to teachers.'}), 422);
        }
        return http.Response(jsonEncode({'data': {'id': 'x'}}), 201);
      }
      return http.Response(jsonEncode({'data': []}), 200);
    });
    final store = SchoolStore();
    final result = await http.runWithClient(
      () => store.markNotScannedAbsent([('staff', 't1'), ('staff', 't2'), ('student', 's2')], '2026-11-04'),
      () => client,
    );
    expect(result.marked, 2);
    expect(result.failed, 1);
    expect(result.error, contains('limited to teachers'));
    expect(sent.first, {
      'person_type': 'staff',
      'staff_id': 't1',
      'date': '2026-11-04',
      'status': 'absent',
      'note': 'No palm scan',
    });
    expect(sent.last['student_id'], 's2');
    expect(sent.last.containsKey('staff_id'), isFalse);
  });
}
