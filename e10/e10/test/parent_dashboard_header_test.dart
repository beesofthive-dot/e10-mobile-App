import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/widgets/common.dart';

/// There is no bell/alert/notification icon anywhere in the app — only the
/// one combined comms icon (Announcements/Messages), for every role.
void main() {
  testWidgets('the header has exactly one icon — no separate alert bell, for any role', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppChrome(
          messageCount: 3,
          onMessages: () {},
          onAnnouncements: () {},
          child: const Scaffold(body: Center(child: HeaderChromeActions())),
        ),
      ),
    );

    // No bell icon at all, anywhere in the header.
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    // Exactly one comms icon.
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Announcements, messages & notifications · 3'));
    await tester.pumpAndSettle();

    // Its popup is strictly Announcements + Messages — nothing else.
    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Alerts'), findsNothing);
  });
}
