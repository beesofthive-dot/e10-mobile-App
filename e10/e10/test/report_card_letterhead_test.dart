import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/widgets/assessment_report_sheet.dart';
import 'package:e10/widgets/report_card_view.dart';

ReportLine _line() => ReportLine(
      studentId: 'kid-1',
      student: 'Ama Owusu',
      remark: 'Respectful and calm',
      headteacherRemark: 'More room for improvement',
      subjects: [ReportSubjectMark(subject: 'Mathematics', classScore: 40, examScore: 45)],
    );

AcademicReport _report() => AcademicReport(
      id: 'r1',
      klass: 'Basic 4',
      term: 'Term 1',
      year: '2026/2027',
      teacher: 'Mrs. Darko',
      lines: [_line()],
    );

void main() {
  testWidgets('input form and read-only view share the same school letterhead', (tester) async {
    final store = SchoolStore();
    store.schoolName = 'New College';

    Future<void> pump(Widget child) => tester.pumpWidget(
          MaterialApp(
            home: SchoolScope(
              store: store,
              child: Scaffold(body: SingleChildScrollView(child: child)),
            ),
          ),
        );

    await pump(AssessmentReportSheet(report: _report(), line: _line(), canEditScores: true));
    await tester.pumpAndSettle();
    expect(find.text('NEW COLLEGE'), findsOneWidget);
    expect(find.text('Official academic report'), findsOneWidget);

    await pump(ReportCardView(report: _report(), line: _line()));
    await tester.pumpAndSettle();
    expect(find.text('NEW COLLEGE'), findsOneWidget);
    expect(find.text('Official academic report'), findsOneWidget);
  });

  testWidgets('the old generic app-logo GES header is gone', (tester) async {
    final store = SchoolStore();
    store.schoolName = 'New College';

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AssessmentReportSheet(report: _report(), line: _line(), canEditScores: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GHANA EDUCATION SERVICE'), findsNothing);
  });

  testWidgets('remarks render above the score table in both the view and the input form', (tester) async {
    final store = SchoolStore();
    store.schoolName = 'New College';

    Future<void> pump(Widget child) => tester.pumpWidget(
          MaterialApp(
            home: SchoolScope(
              store: store,
              child: Scaffold(body: SingleChildScrollView(child: child)),
            ),
          ),
        );

    await pump(ReportCardView(report: _report(), line: _line()));
    await tester.pumpAndSettle();
    expect(find.text('TEACHER REMARK'), findsOneWidget);
    expect(find.text('HEADTEACHER REMARK'), findsOneWidget);
    final viewRemarkY = tester.getTopLeft(find.text('TEACHER REMARK')).dy;
    final viewTableY = tester.getTopLeft(find.text('SUBJECT')).dy;
    expect(viewRemarkY, lessThan(viewTableY));

    await pump(AssessmentReportSheet(report: _report(), line: _line(), canEditScores: true, canEditHead: true));
    await tester.pumpAndSettle();
    expect(find.text('TEACHER REMARK'), findsOneWidget);
    expect(find.text('HEADTEACHER REMARK'), findsOneWidget);
    final inputRemarkY = tester.getTopLeft(find.text('TEACHER REMARK')).dy;
    final inputTableY = tester.getTopLeft(find.text('SUBJECT')).dy;
    expect(inputRemarkY, lessThan(inputTableY));
  });
}
