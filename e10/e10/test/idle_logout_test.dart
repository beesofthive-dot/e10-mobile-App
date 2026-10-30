import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/main.dart';

const _cashier = {
  'id': 'u1',
  'email': 'cash@school.test',
  'roles': ['cashier'],
  'permissions': ['payments.collect', 'feeding.collect'],
  'staff': {'full_name': 'Esi'},
  'school': {'id': 's1', 'name': 'Hill School', 'currency_code': 'GHS'},
};

/// A signed-in user who does nothing for 3 minutes is signed out and lands
/// on the landing page; a session left closed longer than that is not
/// restored.
void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  tearDown(() {
    ApiSession.instance.token = null;
    ApiSession.instance.user = null;
  });

  http.Response reply(http.Request r) {
    final path = r.url.path;
    if (path.endsWith('/auth/me')) return http.Response(jsonEncode({'data': _cashier}), 200);
    if (path.endsWith('/cashier/my-day')) {
      return http.Response(jsonEncode({'data': {'payments': [], 'not_paid_feeding': [], 'cash_to_hand_over': '0'}}), 200);
    }
    return http.Response(jsonEncode({'data': []}), 200);
  }

  testWidgets('3 minutes without a tap signs out to the landing page', (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 't', 'auth_user': jsonEncode(_cashier)});
    await http.runWithClient(() async {
      await tester.pumpWidget(const E10Root());
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('Today'), findsOneWidget); // the Counter

      await tester.pump(const Duration(minutes: 2));
      expect(find.text('Today'), findsOneWidget); // not yet

      await tester.pump(const Duration(minutes: 1, seconds: 5));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(ApiSession.instance.isSignedIn, isFalse);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      await tester.pump(const Duration(seconds: 10)); // let the notice time out
    }, () => MockClient((r) async => reply(r)));
  });

  testWidgets('a session closed for more than 3 minutes is not restored', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 't',
      'auth_user': jsonEncode(_cashier),
      'e10.last_active_at': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const E10Root());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(ApiSession.instance.isSignedIn, isFalse);
      expect(find.text('Get started'), findsOneWidget);
    }, () => MockClient((r) async => reply(r)));
  });
}
