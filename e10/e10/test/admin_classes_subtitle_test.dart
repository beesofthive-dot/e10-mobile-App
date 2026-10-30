import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_records.dart';

void main() {
  testWidgets('empty class records show an empty-state message',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolScope(
            store: SchoolStore(),
            child: AdminRecordsScreen(
                kind: AdminRecordKind.classes, onLogout: () {}),
          ),
        ),
      ),
    );

    expect(find.text('No classes yet.'), findsOneWidget);
  });

  testWidgets('class rows show readable details, never the database id',
      (tester) async {
    const uuid = '01a08697-3ff2-707a-bcf7-3fa2616e5780';
    final store = SchoolStore();
    store.classes.add(NamedRecord(
        id: uuid,
        name: 'Basic 4',
        detail: 'Red',
        extra: '30',
        link: 'Mr. Owusu'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolScope(
            store: store,
            child: AdminRecordsScreen(
                kind: AdminRecordKind.classes, onLogout: () {}),
          ),
        ),
      ),
    );

    expect(find.textContaining(uuid), findsNothing);
    expect(find.text('Class teacher: Mr. Owusu · 0 of 30 students · Red House'),
        findsOneWidget);
  });
}
