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

/// "Resend code" on the one-time-code login: waits 30 s after a send, then
/// asks the same request-code endpoint again without clearing the form.
void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'));

  for (final role in [Role.teacher, Role.parent]) {
    testWidgets('resend code for ${role.name}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 900) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final requests = <String>[];
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && !path.contains('verify')) {
          requests.add(path);
          return http.Response(jsonEncode({'message': 'Code sent.', 'data': {'otc': '11111${requests.length}'}}), 200);
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
                home: LoginScreen(onLogin: (_) async {}, initialRole: role),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        await tester.enterText(find.byType(TextField).first, role == Role.parent ? '0241234567' : 'teacher@school.edu');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        final send = role == Role.parent ? find.textContaining(RegExp('code', caseSensitive: false)).last : find.text('Send my code');
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pump(const Duration(milliseconds: 500));
        expect(requests.length, 1);

        // Right after sending, resend waits.
        expect(find.text('Resend code in 30s'), findsOneWidget);
        await tester.tap(find.text('Resend code in 30s'), warnIfMissed: false);
        await tester.pump();
        expect(requests.length, 1);

        await tester.pump(const Duration(seconds: 31));
        expect(find.text('Resend code'), findsOneWidget);
        await tester.ensureVisible(find.text('Resend code'));
        await tester.tap(find.text('Resend code'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(requests.length, 2);
        expect(requests[1], requests[0]);
        // The new dev code replaces the old one and the wait starts again.
        expect(find.text('111112'), findsOneWidget);
        expect(find.textContaining('Resend code in'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 31));
      }, () => client);
    });
  }
}
