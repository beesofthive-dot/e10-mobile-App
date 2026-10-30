import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'package:e10/core/config/api_config.dart';
import 'api_exception.dart';
import 'api_session.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();
  static const _timeout = Duration(seconds: 30); // mobile data can be slow

  /// One client for the whole app so connections (and their TLS handshake,
  /// several round trips on a slow mobile link) are reused instead of being
  /// set up again for every request. Created lazily, after main() has
  /// installed the app's trusted roots. Kept per zone so code (and tests)
  /// running under `http.runWithClient` still get that zone's client.
  final _clients = Expando<http.Client>('e10.http');
  http.Client get _client => _clients[Zone.current] ??= http.Client();

  /// At most this many requests on the wire at once; the rest wait their
  /// turn. Firing ~20 requests together on slow mobile data made them all
  /// time out.
  static const _maxInFlight = 6;
  int _inFlight = 0;
  final _waiting = <Completer<void>>[];

  Future<void> _acquire() {
    if (_inFlight < _maxInFlight) {
      _inFlight++;
      return Future.value();
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    return turn.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete(); // hand the slot straight on
    } else {
      _inFlight--;
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return ApiConfig.endpoint(path).replace(queryParameters: query);
  }

  Map<String, String> _headers({bool auth = true}) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (auth && ApiSession.instance.token != null) 'Authorization': 'Bearer ${ApiSession.instance.token}',
    };
  }

  /// Reads are retried on a dropped connection or timeout; writes are not,
  /// so a save or a payment can never be sent twice.
  Future<dynamic> get(String path, {Map<String, String>? query, Duration? timeout}) {
    final uri = _uri(path, query);
    return _request(() => _getStreamed(uri), timeout: const Duration(minutes: 3), retry: true, label: 'GET ${uri.path}?${uri.query}');
  }

  /// A GET that only gives up when the server stops sending: 30s for the
  /// reply to start, then 20s without a single byte. A big list trickling
  /// in over slow mobile data (~100 KB/s, shared by several requests) keeps
  /// going instead of being cut off at a fixed total time and restarted.
  Future<http.Response> _getStreamed(Uri uri, {String? accept}) async {
    final request = http.Request('GET', uri)..headers.addAll(_headers());
    if (accept != null) request.headers['Accept'] = accept;
    final sentAt = DateTime.now();
    final streamed = await _client.send(request).timeout(_timeout);
    final wait = DateTime.now().difference(sentAt);
    if (wait.inSeconds >= 5) debugPrint('e10.api slow first byte ${wait.inSeconds}s GET ${uri.path}');
    final body = BytesBuilder(copy: false);
    final done = Completer<Uint8List>();
    Timer? idle;
    late final StreamSubscription<List<int>> sub;
    void rearm() {
      idle?.cancel();
      idle = Timer(const Duration(seconds: 20), () {
        sub.cancel();
        if (!done.isCompleted) done.completeError(TimeoutException('No data from the school API for 20s'));
      });
    }

    sub = streamed.stream.listen(
      (chunk) {
        body.add(chunk);
        rearm();
      },
      onError: (Object error, StackTrace stack) {
        idle?.cancel();
        if (!done.isCompleted) done.completeError(error, stack);
      },
      onDone: () {
        idle?.cancel();
        if (!done.isCompleted) done.complete(body.takeBytes());
      },
      cancelOnError: true,
    );
    rearm();
    return http.Response.bytes(
      await done.future,
      streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  /// Downloads a protected file (e.g. the school logo) as raw bytes. `url`
  /// is absolute; it's retried like any other read.
  Future<Uint8List> getBytes(String url, {String accept = 'image/*'}) async {
    final uri = Uri.parse(url);
    final result = await _request(
      () => _getStreamed(uri, accept: accept),
      timeout: const Duration(minutes: 2),
      retry: true,
      bytes: true,
      label: 'GET ${uri.path}',
    );
    return result as Uint8List;
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body, Duration? timeout]) {
    return _request(() => _client.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})), timeout: timeout);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body, Duration? timeout]) {
    return _request(() => _client.put(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})), timeout: timeout);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body, Duration? timeout]) {
    return _request(() => _client.patch(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})), timeout: timeout);
  }

  Future<dynamic> delete(String path, {Duration? timeout}) {
    return _request(() => _client.delete(_uri(path), headers: _headers()), timeout: timeout);
  }

  /// Multipart upload (a photo attachment, etc). `fileField` is the form
  /// field name the API expects the file under.
  Future<dynamic> postMultipart(
    String path, {
    required String fileField,
    required List<int> bytes,
    required String filename,
    Map<String, String>? fields,
    Duration? timeout,
  }) {
    return _request(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers()..remove('Content-Type'));
      if (fields != null) request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes(fileField, bytes, filename: filename));
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    }, timeout: timeout ?? const Duration(seconds: 30));
  }

  /// Several files in one multipart request, all under [fileField]
  /// (e.g. `photos[]`).
  Future<dynamic> postMultipartFiles(
    String path, {
    required String fileField,
    required List<({List<int> bytes, String filename})> files,
    Map<String, String>? fields,
    Duration? timeout,
  }) {
    return _request(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers()..remove('Content-Type'));
      if (fields != null) request.fields.addAll(fields);
      for (final f in files) {
        request.files.add(http.MultipartFile.fromBytes(fileField, f.bytes, filename: f.filename));
      }
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    }, timeout: timeout ?? const Duration(seconds: 60));
  }

  static const _retryDelays = [Duration(milliseconds: 1500), Duration(seconds: 4)];

  Future<dynamic> _request(Future<http.Response> Function() send, {Duration? timeout, bool retry = false, bool bytes = false, String label = ''}) async {
    for (var attempt = 0;; attempt++) {
      final canRetry = retry && attempt < _retryDelays.length;
      ApiException? failure;
      var retryThis = true; // timeouts are retried; errors only if transient
      // The time limit starts once the request actually goes out, not while
      // it waits for a free slot.
      await _acquire();
      try {
        final response = await send().timeout(timeout ?? _timeout);
        developer.log(
          'API ${response.request?.method ?? 'REQUEST'} ${response.request?.url.path} -> ${response.statusCode}',
          name: 'e10.api',
        );
        if (bytes && response.statusCode >= 200 && response.statusCode < 300) return response.bodyBytes;
        return _send(response);
      } on ApiException {
        rethrow;
      } on TimeoutException {
        developer.log('API request timed out', name: 'e10.api');
        debugPrint('e10.api timeout${canRetry ? ' (retrying)' : ''} $label');
        failure = ApiException('The school API is taking too long to answer. Check your connection and try again.');
      } catch (error, stackTrace) {
        developer.log('API request failed', name: 'e10.api', error: error, stackTrace: stackTrace);
        // Also in release builds (visible in `adb logcat`), so a phone-only
        // failure isn't hidden behind the generic message.
        final cause = '$error';
        // Only a real network hiccup is worth another try; anything else
        // (bad config, a bug) would just fail the same way again.
        final transient = cause.contains('SocketException') ||
            cause.contains('ClientException') ||
            cause.contains('Connection reset') ||
            cause.contains('Connection closed') ||
            cause.contains('HttpException');
        retryThis = transient;
        debugPrint('e10.api failed${canRetry && transient ? ' (retrying)' : ''}: ${cause.length > 200 ? cause.substring(0, 200) : cause}');
        if (cause.contains('CERTIFICATE_VERIFY_FAILED') || cause.contains('HandshakeException')) {
          throw ApiException('Secure connection to the school API failed on this device.');
        }
        failure = cause.contains('Failed host lookup') || cause.contains('Network is unreachable')
            ? ApiException('No internet connection. Check your mobile data or Wi-Fi.')
            : ApiException('Cannot reach the school API.');
      } finally {
        _release();
      }
      if (!canRetry || !retryThis) throw failure;
      // Brief network drops (Wi-Fi ↔ mobile data) usually clear in seconds.
      await Future.delayed(_retryDelays[attempt]);
    }
  }

  dynamic _send(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (response.statusCode == 401) {
      ApiSession.instance.clear();
    }
    final errors = _errorsOf(decoded);
    if (response.statusCode >= 400) {
      debugPrint('e10.api ${response.request?.method ?? ''} ${response.request?.url.path} -> ${response.statusCode}');
      // Surface the exact rejection reason in the console — the browser's own
      // "PUT ... 422" log line never includes the response body, so without
      // this a validation failure is silent apart from a generic toast.
      developer.log(
        'API ${response.request?.method ?? 'REQUEST'} ${response.request?.url.path} -> ${response.statusCode}: '
        '${errors ?? decoded}',
        name: 'e10.api',
      );
    }
    throw ApiException(_message(decoded, response.statusCode, errors), status: response.statusCode, errors: errors);
  }

  Map<String, List<String>>? _errorsOf(dynamic decoded) {
    if (decoded is! Map) return null;
    final errors = decoded['errors'];
    if (errors is! Map || errors.isEmpty) return null;
    return {
      for (final entry in errors.entries)
        '${entry.key}': entry.value is List
            ? [for (final item in entry.value as List) item.toString()]
            : [entry.value.toString()],
    };
  }

  String _message(dynamic decoded, int status, Map<String, List<String>>? errors) {
    if (errors != null) {
      // Join every rejected field, not just the first, so e.g. a student
      // update missing two required fields shows both instead of hiding one.
      final summary = errors.entries.map((e) => e.value.isEmpty ? e.key : e.value.first).join(' · ');
      if (summary.isNotEmpty) return summary;
    }
    if (decoded is Map) {
      if (decoded['message'] is String && (decoded['message'] as String).isNotEmpty) {
        return decoded['message'] as String;
      }
    }
    if (status == 401) return 'Session expired. Sign in again.';
    if (status == 400) return 'The API rejected the request. Check the submitted data.';
    if (status == 403) return 'You do not have permission to perform this action.';
    if (status == 404) return 'The requested API endpoint was not found.';
    if (status == 402) return 'Your school’s subscription needs renewing. Contact the office.';
    if (status == 429) return 'Too many attempts. Wait a moment and try again.';
    if (status == 422) return 'Some submitted fields are invalid.';
    if (status >= 500) return 'The school API had an error ($status).';
    return 'Request failed ($status).';
  }
}
