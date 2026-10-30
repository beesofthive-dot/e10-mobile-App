import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/screens/admin_forms.dart';
import 'package:e10/widgets/popups.dart';

void main() {
  testWidgets('a message raised inside an open form shows on top of it, near the top', (tester) async {
    late BuildContext formContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                title: 'New message',
                builder: (ctx) {
                  formContext = ctx;
                  return const Text('form body');
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    showSnack(formContext, 'Could not send: the guardian has no login account yet.');
    await tester.pump(const Duration(milliseconds: 300));

    final message = find.text('Could not send: the guardian has no login account yet.');
    expect(message, findsOneWidget);
    // Nothing covers it: a tap on the message reaches the message itself.
    expect(message.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(message).dy, lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio / 3));

    // Tapping dismisses it.
    await tester.tap(message);
    await tester.pump();
    expect(message, findsNothing);
  });
}
