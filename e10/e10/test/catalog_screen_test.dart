import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/catalog_screen.dart';

void main() {
  testWidgets('resolves a nested relation instead of dropping it, and shows full detail on tap', (tester) async {
    final store = SchoolStore();
    store.catalogKey = 'academic_terms';
    store.catalogTitle = 'Terms';
    store.tables['academic_terms'] = [
      {
        'id': 't1',
        'name': 'Term 1',
        'academic_year': {'id': 'y1', 'name': '2026/2027'},
        'status': 'current',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: CatalogScreen(onBack: () {}, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The nested academic_year relation must show up on the row, not be dropped.
    expect(find.textContaining('2026/2027'), findsOneWidget);

    await tester.tap(find.text('Term 1'));
    await tester.pumpAndSettle();

    expect(find.text('2026/2027'), findsOneWidget);
    expect(find.text('Academic Year'), findsOneWidget);
  });
}
