import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists which message threads this device has already opened, keyed by user.
/// Preview text is stored so a later reply on the same thread can show as unread.
class MessageReadPrefs {
  MessageReadPrefs._();
  static final MessageReadPrefs instance = MessageReadPrefs._();

  static const _prefix = 'messages.read.v1.';

  final Map<String, String> _previews = {};
  String? _viewer;

  Future<void> load(String viewer) async {
    final key = viewer.trim();
    if (key.isEmpty) return;
    if (_viewer == key) return;
    _viewer = key;
    _previews.clear();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((id, value) {
        _previews['$id'] = '$value';
      });
    } catch (_) {}
  }

  void remember(Iterable<String> keys, String preview) {
    final body = preview.trim();
    for (final raw in keys) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      _previews[id] = body;
    }
  }

  bool isRead(Iterable<String> keys, String preview) {
    final body = preview.trim();
    for (final raw in keys) {
      final id = raw.trim();
      if (id.isEmpty || !_previews.containsKey(id)) continue;
      final stored = _previews[id]!.trim();
      if (stored.isEmpty || stored == body) return true;
    }
    return false;
  }

  Future<void> save() async {
    final viewer = _viewer;
    if (viewer == null || viewer.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$viewer', jsonEncode(_previews));
  }

  void resetMemory() {
    _viewer = null;
    _previews.clear();
  }
}
