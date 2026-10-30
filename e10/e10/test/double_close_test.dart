import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/widgets/common.dart';
import 'package:e10/widgets/popups.dart';

void main() {
  testWidgets('closing a form twice only closes the form, never the dashboard underneath', (tester) async {
    late BuildContext formContext;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) {
                formContext = ctx;
                return const Dialog(child: Text('edit form'));
              },
            ),
            child: const Text('dashboard'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('dashboard'));
    await tester.pumpAndSettle();

    // Two saves finishing at the same moment both try to close the form.
    closeRoute(formContext);
    closeRoute(formContext);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('edit form'), findsNothing);
    expect(find.text('dashboard'), findsOneWidget);

    // Closing on the dashboard itself (the app's only screen) does nothing.
    closeRoute(tester.element(find.text('dashboard')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('dashboard'), findsOneWidget);
  });

  testWidgets('a double-tapped Save runs the save once and shows a spinner meanwhile', (tester) async {
    var saves = 0;
    final done = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HoneyButton(
          label: 'Update',
          onPressed: () async {
            saves++;
            await done.future;
          },
        ),
      ),
    ));

    await tester.tap(find.text('Update'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(HoneyButton));
    await tester.pump();
    expect(saves, 1);

    done.complete();
    await tester.pump();
    expect(find.text('Update'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
