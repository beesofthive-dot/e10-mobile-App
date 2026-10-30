import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/feeding.dart';
import 'package:e10/screens/parent_feeding_pay.dart';
import 'package:e10/theme.dart';

final _status = {'set_up': true, 'rate': '10.00', 'unpaid_days': 2, 'unpaid_amount': '20.00'};

/// Parent feeding payment: hidden until the server has the route; then the
/// MoMo flow ends with the reference and receipt filled in by the server.
void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiSession.instance.token = 'test-token';
    FeedingApi.resetPayAvailability();
  });
  tearDown(() => ApiSession.instance.token = null);

  test('a server without the route keeps Pay hidden', () async {
    final ok = await http.runWithClient(
      () => FeedingApi.parentPayAvailable('s1'),
      () => MockClient((_) async => http.Response(jsonEncode({'message': 'Not found'}), 404)),
    );
    expect(ok, isFalse);
  });

  test('a server with the route (empty request refused) shows Pay', () async {
    final ok = await http.runWithClient(
      () => FeedingApi.parentPayAvailable('s1'),
      () => MockClient((_) async => http.Response(jsonEncode({'message': 'The provider field is required.'}), 422)),
    );
    expect(ok, isTrue);
  });

  testWidgets('paying ends with the reference and receipt', (tester) async {
    Map<String, dynamic>? sent;
    var checks = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
        home: Scaffold(body: SingleChildScrollView(child: FeedingPayForm(studentId: 's1', status: _status, phone: '0241234567', currency: 'GHS'))),
      ));
      expect(find.text('Unpaid days only'), findsOneWidget);
      expect(find.textContaining('About GHS 20.00'), findsOneWidget);

      await tester.tap(find.text('Pay with mobile money'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(sent?['option'], 'arrears');
      expect(sent?['provider'], 'mtn_momo');
      expect(find.text('Approve the payment on your phone'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 200));
      expect(checks, 1);
      expect(find.text('Feeding paid · GHS 20.00'), findsOneWidget);
      expect(find.text('Reference MP12345'), findsOneWidget);
      expect(find.text('Receipt FD-0042'), findsOneWidget);
      expect(find.text('View receipt'), findsOneWidget);
    }, () => MockClient((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/students/s1/feeding/pay-intents')) {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'data': {'id': 'pi1', 'status': 'pending', 'amount': '20.00', 'reference': 'MP12345'}}), 201);
      }
      if (r.url.path.endsWith('/payment-intents/pi1')) {
        checks++;
        return http.Response(
          jsonEncode({
            'data': {'id': 'pi1', 'status': 'successful', 'amount': '20.00', 'reference': 'MP12345', 'receipt_number': 'FD-0042', 'feeding_payment_id': 'fp9'},
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'data': []}), 200);
    }));
  });
}
