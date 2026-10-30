
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:e10/api/api_client.dart';
import 'package:e10/api/api_exception.dart';

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'));

  test('a read survives a brief network drop', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) throw http.ClientException("Failed host lookup: 'example.test'");
      return http.Response('{"data":[{"id":1}]}', 200);
    });
    final result = await http.runWithClient(() => ApiClient.instance.get('/bills'), () => client);
    expect(calls, 2);
    expect((result as Map)['data'], isNotEmpty);
  });

  test('a write is never retried (no double payment)', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      throw http.ClientException('Connection reset by peer');
    });
    await expectLater(
      http.runWithClient(() => ApiClient.instance.post('/students/1/pay-balance/pay-intents', {'amount': 1}), () => client),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  test('offline reads say so plainly', () async {
    final client = MockClient((request) async => throw http.ClientException("Failed host lookup: 'example.test'"));
    await expectLater(
      http.runWithClient(() => ApiClient.instance.get('/bills'), () => client),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('No internet connection'))),
    );
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('no more than 6 requests are on the wire at once', () async {
    var active = 0, peak = 0;
    final client = MockClient((request) async {
      active++;
      if (active > peak) peak = active;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active--;
      return http.Response('{"data":[]}', 200);
    });
    await http.runWithClient(
      () => Future.wait([for (var i = 0; i < 20; i++) ApiClient.instance.get('/notifications')]),
      () => client,
    );
    expect(peak, lessThanOrEqualTo(6));
  });
}
