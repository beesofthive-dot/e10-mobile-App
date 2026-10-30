import 'dart:convert';

import 'package:e10/api/api_session.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _student = '01a0d810-0000-7000-8000-000000000001';
const _teacher = '01a0d810-0000-7000-8000-000000000002';
const _thread = '01a0d810-0000-7000-8000-000000000003';

/// Messages live only on the school server: a send either reaches it or is
/// reported as not sent — never kept on the phone looking "sent".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  setUp(() => ApiSession.instance.token = 'test-token');
  tearDown(() => ApiSession.instance.token = null);

  Future<String> send(SchoolStore store) => store.startDirectMessage(
        studentId: _student,
        participantUserId: _teacher,
        body: 'Hello teacher',
        participantName: 'Afia Mensah',
        participantRole: 'Class teacher',
        fromName: 'Kojo Owusu',
        fromRole: Role.parent,
      );

  test('a message the server accepts shows in the conversation list', () async {
    final store = SchoolStore();
    final error = await http.runWithClient(
      () => send(store),
      () => MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/message-threads')) {
          return http.Response(jsonEncode({'data': {'id': _thread}}), 201);
        }
        return http.Response(jsonEncode({'data': []}), 200);
      }),
    );

    expect(error, isEmpty);
    expect(store.messages.where((m) => m.preview == 'Hello teacher'), isNotEmpty);
  });

  test('a message that cannot reach the server is reported as not sent and not kept', () async {
    final store = SchoolStore();
    final error = await http.runWithClient(
      () => send(store),
      () => MockClient((_) async => throw http.ClientException('offline')),
    );

    expect(error, contains('not sent'));
    expect(store.messages, isEmpty);
  });

  test('a message the server refuses shows the reason and is not kept', () async {
    final store = SchoolStore();
    final error = await http.runWithClient(
      () => send(store),
      () => MockClient((_) async => http.Response(jsonEncode({'message': 'Guardian is not linked to this student.'}), 422)),
    );

    expect(error, contains('not linked'));
    expect(store.messages, isEmpty);
  });

  test('signed out, nothing is sent or stored', () async {
    ApiSession.instance.token = null;
    final store = SchoolStore();
    expect(await send(store), 'Sign in to send messages.');
    expect(store.messages, isEmpty);
  });

  test('a reply that does not reach the server is taken back out of the chat', () async {
    final store = SchoolStore();
    store.messages.add(ChatPreview(
      id: _thread,
      threadId: _thread,
      from: 'Afia Mensah',
      role: 'Teacher',
      time: '',
      preview: 'Earlier message',
      unread: false,
      avatar: 'A',
      audience: const [Role.parent],
    ));

    final error = await http.runWithClient(
      () => store.sendThreadReply(threadId: _thread, from: 'Kojo Owusu', fromRole: Role.parent, body: 'Following up'),
      () => MockClient((_) async => throw http.ClientException('offline')),
    );

    expect(error, contains('not sent'));
    expect(store.messages.first.lines.any((line) => line.body == 'Following up'), isFalse);
  });

  test('a reply the server accepts stays in the chat', () async {
    final store = SchoolStore();
    store.messages.add(ChatPreview(
      id: _thread,
      threadId: _thread,
      from: 'Afia Mensah',
      role: 'Teacher',
      time: '',
      preview: 'Earlier message',
      unread: false,
      avatar: 'A',
      audience: const [Role.parent],
    ));

    final error = await http.runWithClient(
      () => store.sendThreadReply(threadId: _thread, from: 'Kojo Owusu', fromRole: Role.parent, body: 'Following up'),
      () => MockClient((_) async => http.Response(jsonEncode({'data': {'id': 'm1'}}), 201)),
    );

    expect(error, isEmpty);
    expect(store.messages.first.lines.any((line) => line.body == 'Following up'), isTrue);
  });
}
