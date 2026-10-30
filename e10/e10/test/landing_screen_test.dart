import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/screens/landing_screen.dart';
import 'package:e10/theme.dart';

/// The signed-out landing page: fits every phone size and only moves on
/// when "Get started" is tapped.
void main() {
  const sizes = {
    'landscape': Size(800, 360),
    'portrait': Size(360, 760),
    'small phone': Size(320, 568),
    'narrow window': Size(380, 460),
  };

  for (final entry in sizes.entries) {
    testWidgets('landing fits ${entry.key} and Get started moves on', (tester) async {
      tester.view.physicalSize = entry.value * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      var started = 0;
      var register = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
        home: Scaffold(
          body: LandingScreen(onGetStarted: () => started++, onRegisterSchool: () => register++),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(started, 0); // never moves on by itself
      await tester.ensureVisible(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.ensureVisible(find.textContaining('Register here', findRichText: true));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Register here', findRichText: true));
      expect(started, 1);
      expect(register, 1);
    });
  }
}
