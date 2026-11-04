import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';

void main() {
  group('attendanceTermSummaryFor', () {
    test('buckets on-time/late/absent/excused and totals present', () {
      final store = SchoolStore();
      store.academicTermId = 'term-1';
      store.tables['attendance'] = [
        {'student_id': 'kid-1', 'status': 'present', 'academic_term_id': 'term-1', 'date': '2026-09-01'},
        {'student_id': 'kid-1', 'status': 'present', 'academic_term_id': 'term-1', 'date': '2026-09-02'},
        {'student_id': 'kid-1', 'status': 'late', 'academic_term_id': 'term-1', 'date': '2026-09-03'},
        {'student_id': 'kid-1', 'status': 'absent', 'academic_term_id': 'term-1', 'date': '2026-09-04'},
        {'student_id': 'kid-1', 'status': 'excused', 'academic_term_id': 'term-1', 'date': '2026-09-05'},
        // A different student's rows must never leak into kid-1's counts.
        {'student_id': 'kid-2', 'status': 'present', 'academic_term_id': 'term-1', 'date': '2026-09-01'},
      ];

      final summary = store.attendanceTermSummaryFor('kid-1');

      expect(summary.onTime, 2);
      expect(summary.late, 1);
      expect(summary.absent, 1);
      expect(summary.excused, 1);
      expect(summary.present, 3); // onTime + late
      expect(summary.totalDays, 5);
    });

    test('scopes to the current term when rows carry a term id', () {
      final store = SchoolStore();
      store.academicTermId = 'term-2';
      store.tables['attendance'] = [
        {'student_id': 'kid-1', 'status': 'present', 'academic_term_id': 'term-1', 'date': '2026-05-01'},
        {'student_id': 'kid-1', 'status': 'absent', 'academic_term_id': 'term-1', 'date': '2026-05-02'},
        {'student_id': 'kid-1', 'status': 'present', 'academic_term_id': 'term-2', 'date': '2026-09-01'},
      ];

      final summary = store.attendanceTermSummaryFor('kid-1');

      // Only the term-2 row should count, not the two term-1 rows.
      expect(summary.totalDays, 1);
      expect(summary.onTime, 1);
      expect(summary.absent, 0);
    });

    test('falls back to all rows when nothing carries a term id', () {
      final store = SchoolStore();
      store.academicTermId = 'term-1';
      store.tables['attendance'] = [
        {'student_id': 'kid-1', 'status': 'present', 'date': '2026-09-01'},
        {'student_id': 'kid-1', 'status': 'late', 'date': '2026-09-02'},
      ];

      final summary = store.attendanceTermSummaryFor('kid-1');

      expect(summary.totalDays, 2);
      expect(summary.onTime, 1);
      expect(summary.late, 1);
    });

    test('left early is its own bucket, never absent (as on the website)', () {
      final store = SchoolStore();
      store.tables['attendance'] = [
        {'student_id': 'kid-1', 'status': 'early_departure', 'date': '2026-09-01'},
        {'student_id': 'kid-1', 'status': 'authorized_absence', 'date': '2026-09-02'},
      ];
      final summary = store.attendanceTermSummaryFor('kid-1');
      expect(summary.leftEarly, 1);
      expect(summary.absent, 0);
      expect(summary.excused, 1);
      expect(summary.onTime, 0);
      expect(summary.present, 1); // attended, though not "Present"
    });

    test('empty history reports zero totals, not a crash', () {
      final store = SchoolStore();
      final summary = store.attendanceTermSummaryFor('no-such-kid');
      expect(summary.totalDays, 0);
      expect(summary.present, 0);
      expect(summary.presentPercent, 0);
    });
  });
}
