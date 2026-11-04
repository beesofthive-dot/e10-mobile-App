import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/app_prefs.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/login_screen.dart';
import 'package:e10/theme.dart';

/// Forgot password, end to end against a fake server: one code request,
/// then the reset with `code` (not `token`), as the website sends it.
void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'));

  testWidgets('forgot password sends one code, then resets with that code', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final calls = <(String, Map<String, dynamic>)>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method != 'POST') return http.Response('{}', 404);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      calls.add((path, body));
      if (path.endsWith('auth/password/forgot')) {
        return http.Response(jsonEncode({'message': 'A reset code has been sent.', 'data': {'otc': '482913'}}), 200);
      }
      if (path.endsWith('auth/password/reset')) {
        return body['code'] == '482913'
            ? http.Response(jsonEncode({'message': 'Password reset.'}), 200)
            : http.Response(jsonEncode({'message': 'That code is invalid or has expired.'}), 422);
      }
      return http.Response('{}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        AppPrefsScope(
          prefs: AppPrefs(),
          child: SchoolScope(
            store: SchoolStore(),
            child: MaterialApp(
              theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
              home: LoginScreen(onLogin: (_) async {}, initialRole: Role.teacher),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Reachable from the default staff mode (one-time code), not only Password.
      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(find.text('Reset your password'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'teacher@school.edu');
      await tester.tap(find.text('Send reset code'));
      await tester.pumpAndSettle();

      // The dev code the server returned is filled in for the user.
      expect(find.textContaining('your code is 482913'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'New password (at least 8 characters)'), 'NewPass123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'NewPass123');
      await tester.tap(find.text('Reset password'));
      await tester.pumpAndSettle();
    }, () => client);

    expect(calls.where((c) => c.$1.endsWith('forgot')).length, 1, reason: 'the code must be requested once');
    final reset = calls.singleWhere((c) => c.$1.endsWith('reset')).$2;
    expect(reset, {
      'email': 'teacher@school.edu',
      'code': '482913',
      'password': 'NewPass123',
      'password_confirmation': 'NewPass123',
    });
    // Back on the login form, on the password tab with the email filled in.
    expect(find.text('Reset your password'), findsNothing);
    expect(find.text('Password reset. Sign in with your new password.'), findsOneWidget);
  });
}
