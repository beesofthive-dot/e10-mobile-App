import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ApiSession {
  ApiSession._();
  static final ApiSession instance = ApiSession._();

  String? token;
  Map<String, dynamic>? user;

  bool get isSignedIn => token != null && token!.isNotEmpty;

  void save(String token, Map<String, dynamic> user) {
    this.token = token;
    this.user = user;
    _persist(token, user);
  }

  void clear() {
    token = null;
    user = null;
    _clearPersisted();
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    final storedUser = prefs.getString('auth_user');
    if (storedToken == null || storedToken.isEmpty || storedUser == null) return;
    try {
      final decoded = jsonDecode(storedUser);
      if (decoded is Map) {
        token = storedToken;
        user = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      await prefs.remove('auth_token');
      await prefs.remove('auth_user');
    }
  }

  Future<void> _persist(String value, Map<String, dynamic> currentUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', value);
    await prefs.setString('auth_user', jsonEncode(currentUser));
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
  }
}
