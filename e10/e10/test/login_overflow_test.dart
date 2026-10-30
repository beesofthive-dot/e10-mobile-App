import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/app_prefs.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/login_screen.dart';
import 'package:e10/theme.dart';

/// The sign-in screen, both tabs, on every phone/window shape — no
/// overflow stripes.
void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'));
  const sizes = {
    'landscape': Size(800, 360),
    'portrait': Size(360, 760),
    'small phone': Size(320, 568),
    'narrow window': Size(380, 460),
    'small landscape': Size(568, 320),
  };

  for (final entry in sizes.entries) {
    for (final tab in ['PARENT', 'STAFF']) {
      testWidgets('login $tab ${entry.key}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = entry.value * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed')) {
            overflows.add(text.split('\n').first);
          } else {
            previous?.call(details);
          }
        };
        addTearDown(() => FlutterError.onError = previous);

        await tester.pumpWidget(
          AppPrefsScope(
            prefs: AppPrefs(),
            child: SchoolScope(
              store: SchoolStore(),
              child: MaterialApp(
                theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
                home: LoginScreen(onLogin: (_) async {}, onRegisterSchool: () {}),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final tabFinder = find.textContaining(tab);
        if (tabFinder.evaluate().isNotEmpty) {
          await tester.tap(tabFinder.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 400));
        }

        FlutterError.onError = previous;
        expect(overflows, isEmpty, reason: overflows.toSet().join('\n'));
      });
    }
  }
}
