import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/main.dart';

void main() {
  testWidgets('splash shows the brand while loading', (tester) async {
    await tester.pumpWidget(const E10Root());
    await tester.pump();
    expect(find.text('SCHOOL SYSTEMS'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('splash moves on to the landing page, Get started opens sign-in', (tester) async {
    // main() loads .env before runApp; the login screen reads it.
    dotenv.testLoad(fileInput: '');
    await tester.pumpWidget(const E10Root());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);

    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
