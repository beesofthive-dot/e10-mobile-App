import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('academic year labels come from the API `year` field', () {
    final store = SchoolStore();
    store.academicYearId = 'y2';
    store.tables['academic_years'] = [
      {'id': 'y2', 'year': '2026/2027', 'is_current': true},
      {'id': 'y1', 'year': '2025/2026'},
    ];
    expect(store.currentYearLabel, '2026/2027');
    expect(store.yearLabels, ['2026/2027', '2025/2026']);
    expect(store.yearLabelFor('y1'), '2025/2026');
  });

  test('a roll is never reported as saved when it was not sent', () async {
    final store = SchoolStore();
    final ok = await store.saveAttendance('Basic 4', {'s1': 'present'});
    expect(ok, isFalse);
    expect(store.rollOf('s1'), '');
    expect(store.syncError, isNotNull);
  });
}
