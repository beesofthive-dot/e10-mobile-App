import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/admin_records.dart';
import 'package:e10/widgets/popups.dart';

void main() {
  testWidgets('View → Edit on a record closes one form and opens the next without errors', (tester) async {
    final store = SchoolStore();
    store.classes.add(NamedRecord(id: 'c1', name: 'Basic 4', extra: '30'));
    await tester.pumpWidget(MaterialApp(
      home: SchoolScope(
        store: store,
        child: Scaffold(body: AdminRecordsScreen(kind: AdminRecordKind.classes, onLogout: () {}, viewOnly: false)),
      ),
    ));

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.text('Class size (capacity)'), findsOneWidget);

    // Edit closes the view form (its text fields still animating out) and
    // opens the edit form — the view form's controllers must outlive that.
    await tester.tap(find.text('Edit').last);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Update'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a closing form keeps its text fields alive until the close animation ends', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final name = TextEditingController(text: 'Basic 4');
              await showAppSheet<void>(
                context: context,
                title: 'Edit class',
                builder: (ctx) => Column(children: [
                  TextField(controller: name),
                  TextButton(onPressed: () => closeRoute(ctx), child: const Text('Update')),
                ]),
              );
              disposeAfterClose([name]);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Edit class'), findsNothing);
  });
}
