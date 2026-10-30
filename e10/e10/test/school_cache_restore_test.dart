import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a restarted app shows the last saved school data when the server is unreachable', () async {
    SharedPreferences.setMockInitialValues({
      'school_cache.v1.u1': jsonEncode({
        'school': {'name': 'Cached Academy'},
        'tables': {
          'students': [
            {'id': 's1', 'full_name': 'Ama Owusu', 'status': 'active'},
          ],
          'school_classes': [
            {'id': 'c1', 'name': 'Basic 4'},
          ],
        },
      }),
    });
    ApiSession.instance
      ..token = 'test-token'
      ..user = {'id': 'u1'};

    final store = SchoolStore()
      ..applyUserSchool(const AppUser(email: 'admin@school.test', displayName: 'Admin', role: Role.schoolAdmin, subtitle: 'School Admin'));
    await store.syncFromApi(budget: const Duration(seconds: 20));
    store.stopLiveSync();

    expect(store.students.map((s) => s.name), contains('Ama Owusu'));
    expect(store.classes.map((c) => c.name), contains('Basic 4'));

    store.clear();
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('school_cache.')), isEmpty);
    ApiSession.instance
      ..token = null
      ..user = null;
  });

  test('when the server is unreachable and nothing is saved, no made-up school data appears', () async {
    SharedPreferences.setMockInitialValues({});
    ApiSession.instance
      ..token = 'test-token'
      ..user = {'id': 'u2'};

    final store = SchoolStore()
      ..applyUserSchool(const AppUser(email: 'admin@school.test', displayName: 'Admin', role: Role.schoolAdmin, subtitle: 'School Admin'));
    await store.syncFromApi(budget: const Duration(seconds: 20));
    store.stopLiveSync();

    expect(store.students, isEmpty);
    expect(store.classes, isEmpty);
    expect(store.teachers, isEmpty);
    expect(store.messages, isEmpty);
    ApiSession.instance
      ..token = null
      ..user = null;
  });
}
