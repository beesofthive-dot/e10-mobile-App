import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:e10/api/api_exception.dart';
import 'package:http/http.dart' as http;

import 'api/api_client.dart';
import 'package:e10/core/config/api_config.dart';
import 'api/api_session.dart';
import 'models.dart';

class AuthResult {
  const AuthResult._({this.user, this.error, this.info, this.otc});

  factory AuthResult.ok(AppUser user) => AuthResult._(user: user);
  factory AuthResult.error(String error) => AuthResult._(error: error);
  factory AuthResult.pending(String info, {String? otc}) => AuthResult._(info: info, otc: otc);

  final AppUser? user;
  final String? error;
  final String? info;
  final String? otc;

  bool get ok => error == null && user != null;
  bool get isSuccess => ok;
}

class Auth {
  static Role roleFromApi(Map<String, dynamic> json) {
    // A platform super admin (BeeSoft Hive staff) isn't scoped to any one
    // school, so this has to win before any school-role/staff-category
    // check below — those are all meaningless above the school level.
    if (json['is_super_admin'] == true) return Role.platformAdmin;
    if (json['guardian'] is Map) return Role.parent;
    final roles = _roleSlugs(json);
    if (roles.contains('school_admin')) return Role.schoolAdmin;
    if (roles.contains('deputy_admin')) return Role.admin;
    if (roles.contains('teacher')) return Role.teacher;
    if (roles.contains('bursar')) return Role.accountant;
    if (roles.contains('cashier')) return Role.cashier;
    if (roles.contains('exam_officer')) return Role.examOfficer;
    if (roles.contains('registrar')) return Role.secretary;
    if (roles.contains('librarian')) return Role.librarian;
    if (roles.contains('nurse')) return Role.nurse;
    if (json['staff'] is Map) {
      final staff = Map<String, dynamic>.from(json['staff'] as Map);
      final category = '${staff['category'] ?? ''}'.toLowerCase();
      if (category == 'accountant') return Role.accountant;
      if (category == 'cashier') return Role.cashier;
      if (category == 'admin') return Role.admin;
      return Role.teacher;
    }
    if (json['student'] is Map) return Role.parent;
    return Role.parent;
  }

  static List<String> _roleSlugs(Map<String, dynamic> json) {
    final raw = json['roles'];
    if (raw is! List) return const [];
    return [
      for (final role in raw)
        if (role is Map)
          '${role['slug'] ?? role['name'] ?? ''}'
        else
          role.toString(),
    ].where((s) => s.isNotEmpty).toList();
  }

  static AppUser userFromApi(Map<String, dynamic> json, {String password = ''}) {
    final staff = json['staff'] is Map ? Map<String, dynamic>.from(json['staff'] as Map) : null;
    final guardian = json['guardian'] is Map ? Map<String, dynamic>.from(json['guardian'] as Map) : null;
    final school = json['school'] is Map ? Map<String, dynamic>.from(json['school'] as Map) : null;
    final student = json['student'] is Map ? Map<String, dynamic>.from(json['student'] as Map) : null;
    final role = roleFromApi(json);
    final name = (staff?['full_name'] ??
            guardian?['full_name'] ??
            student?['full_name'] ??
            json['email'] ??
            'User')
        .toString();
    final position = '${staff?['position'] ?? ''}'.trim();
    final departmentJson = staff?['department'];
    final department = departmentJson is Map
        ? '${departmentJson['name'] ?? ''}'.trim()
        : '${departmentJson ?? ''}'.trim();
    final email = '${json['email'] ?? ''}'.toString();
    final appearance = '${json['appearance'] ?? 'light'}'.toLowerCase();
    final modules = school?['modules'];
    final plan = _mapOf(school?['plan']);
    final access = _mapOf(json['subscription_access']);
    return AppUser(
      email: email.endsWith('@phone-login.internal') ? '' : email,
      password: password,
      displayName: name,
      role: role,
      subtitle: position.isNotEmpty ? position : role.label,
      schoolId: '${school?['id'] ?? json['school_id'] ?? ''}',
      school: (school?['name'] ?? '').toString(),
      schoolCode: (school?['code'] ?? '').toString(),
      schoolLogoUrl: (school?['logo_url'] ?? '').toString(),
      permissions: [for (final item in (json['permissions'] as List? ?? const [])) item.toString()],
      roleSlugs: _roleSlugs(json),
      phone: (json['phone'] ?? guardian?['phone'] ?? staff?['phone'] ?? '').toString(),
      appearance: appearance == 'dark' ? 'dark' : 'light',
      department: department,
      dailyReportsEligible: json['daily_reports_eligible'] == true,
      schoolModules: modules is List ? [for (final m in modules) m.toString()] : null,
      planName: '${plan?['name'] ?? ''}'.trim(),
      planGrade: '${plan?['grade'] ?? ''}'.trim(),
      accessLevel: json['is_super_admin'] == true ? '' : '${access?['access_level'] ?? ''}',
      blockReason: '${access?['block_reason'] ?? ''}'.trim(),
      departmentHeads: _departmentHeads(json['department_heads']),
    );
  }

  static List<DepartmentHeadship> _departmentHeads(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && '${item['department_id'] ?? ''}'.isNotEmpty)
          DepartmentHeadship(
            departmentId: '${item['department_id']}',
            departmentName: '${item['department_name'] ?? (item['department'] is Map ? (item['department'] as Map)['name'] : null) ?? item['name'] ?? ''}'.trim(),
            isMain: item['is_main'] == true || item['is_main'] == 1,
          ),
    ];
  }

  static Map<String, dynamic>? _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static Future<AuthResult> signIn({
    required String email,
    required String password,
    Role? expectedRole,
  }) async {
    try {
      final session = await _jsonPost(
        ApiConfig.loginPath,
        {'email': email.trim(), 'password': password},
        const Duration(seconds: 15),
      );
      if (session != null) {
        if (session.status >= 400) {
          return AuthResult.error(_apiMessage(session.body, session.status));
        }
        final parsed = _sessionFrom(session.body);
        if (parsed != null) {
          ApiConfig.markLive(session.base);
          ApiSession.instance.save(parsed.token, parsed.user);
          final user = userFromApi(parsed.user, password: password);
          return AuthResult.ok(user);
        }
        return AuthResult.error('Sign-in succeeded but the school API sent an unexpected reply.');
      }
    } catch (_) {}
    return AuthResult.error('Cannot reach the school API at ${ApiConfig.apiRoot}.');
  }

  static ({String token, Map<String, dynamic> user})? _sessionFrom(Map<String, dynamic> root) {
    final nested = _mapOf(root['data']);
    final token = (nested?['token'] ?? nested?['access_token'] ?? root['token'] ?? root['access_token'])?.toString();
    final userJson = nested?['user'] ?? root['user'];
    if (token == null || token.isEmpty || userJson is! Map) return null;
    return (token: token, user: Map<String, dynamic>.from(userJson));
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  static Future<AuthResult> staffCode(String email) async {
    final value = email.trim();
    if (value.isEmpty) return AuthResult.error('Enter the staff email address.');
    try {
      final hit = await _jsonPost(
        ApiConfig.staffRequestCodePath,
        {'identifier': value},
        const Duration(seconds: 15),
      );
      if (hit != null) {
        if (hit.status >= 400) return AuthResult.error(_apiMessage(hit.body, hit.status));
        ApiConfig.markLive(hit.base);
        final nested = _mapOf(hit.body['data']);
        final code = (nested?['otc'] ?? hit.body['otc'] ?? nested?['code'] ?? hit.body['code'])
            ?.toString()
            .replaceAll(RegExp(r'\D'), '');
        if (code != null && code.length == 6) {
          return AuthResult.pending('Your one-time code (OTC) is $code. Enter it to log in.', otc: code);
        }
        return AuthResult.pending('${hit.body['message'] ?? 'A login code has been sent to your staff contact.'}');
      }
    } catch (_) {}
    return AuthResult.error('Cannot send a staff login code. Check the school API connection.');
  }

  static Future<AuthResult> verifyStaff({
    required String email,
    required String code,
    Role? expectedRole,
  }) async {
    final digits = _digits(code);
    if (digits.length != 6) return AuthResult.error('Enter the 6-digit staff one-time code.');
    try {
      final hit = await _jsonPost(
        ApiConfig.staffVerifyCodePath,
        {'identifier': email.trim(), 'code': digits},
        const Duration(seconds: 15),
      );
      if (hit != null) {
        if (hit.status >= 400) return AuthResult.error(_apiMessage(hit.body, hit.status));
        ApiConfig.markLive(hit.base);
        final session = _sessionFrom(hit.body);
        if (session != null) {
          ApiSession.instance.save(session.token, session.user);
          final user = userFromApi(session.user);
          return AuthResult.ok(user);
        }
        return AuthResult.error('The code was accepted but the school API sent an unexpected reply.');
      }
    } catch (_) {}
    return AuthResult.error('Cannot verify the staff code. Request a new OTC.');
  }

  static Future<AuthResult> guardianCode(String phone) async {
    final trimmed = phone.trim();
    final digits = _digits(trimmed);
    if (digits.length < 9) {
      return AuthResult.error('Enter the parent telephone number registered at the school.');
    }
    final phoneValue = digits.length == 10 && digits.startsWith('0') ? digits : trimmed;
    try {
      final hit = await _jsonPost(
        ApiConfig.guardianRequestPath,
        {'phone': phoneValue},
        const Duration(seconds: 15),
      );
      if (hit != null) {
        if (hit.status >= 400) {
          return AuthResult.error(_apiMessage(hit.body, hit.status));
        }
        ApiConfig.markLive(hit.base);
        final nested = _mapOf(hit.body['data']);
        final code = (nested?['otc'] ?? hit.body['otc'] ?? nested?['code'] ?? hit.body['code'])
            ?.toString()
            .replaceAll(RegExp(r'\D'), '');
        if (code != null && code.length == 6) {
          return AuthResult.pending('Your one-time code (OTC) is $code. Enter it to log in.', otc: code);
        }
        return AuthResult.pending(
          '${hit.body['message'] ?? 'If that phone number has a guardian account, a login code has been sent.'}',
        );
      }
    } catch (_) {}
    return AuthResult.error(
      kIsWeb
        ? 'The school API is reachable, but the server is blocking browser CORS for this login request. '
          'Allow this application origin in the Laravel CORS configuration.'
        : 'Cannot send a parent login code. Check the school API connection.',
    );
  }

  static Future<AuthResult> verifyGuardian({required String phone, required String code}) async {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      return AuthResult.error('Enter the 6-digit one-time code given for this phone.');
    }
    final phoneDigits = _digits(phone);
    final phoneValue = phoneDigits.length == 10 && phoneDigits.startsWith('0') ? phoneDigits : phone.trim();
    try {
      final hit = await _jsonPost(
        ApiConfig.guardianVerifyPath,
        {'phone': phoneValue, 'code': digits},
        const Duration(seconds: 15),
      );
      if (hit != null) {
        if (hit.status >= 400) {
          return AuthResult.error(_apiMessage(hit.body, hit.status));
        }
        ApiConfig.markLive(hit.base);
        final session = _sessionFrom(hit.body);
        if (session != null) {
          ApiSession.instance.save(session.token, session.user);
          return AuthResult.ok(userFromApi(session.user));
        }
        return AuthResult.error('The code was accepted but the school API sent an unexpected reply.');
      }
    } catch (_) {}
    return AuthResult.error(
      kIsWeb
          ? 'The school API is reachable, but the server is blocking browser CORS for this verification request.'
          : 'Cannot verify the parent code. Request a new OTC.',
    );
  }

  static Future<AuthResult> currentUser() async {
    try {
      final hit = await ApiClient.instance.get(ApiConfig.mePath, timeout: const Duration(seconds: 15));
      if (hit is! Map) return AuthResult.error('The profile response was invalid.');
      final data = _mapOf(hit['data']) ?? hit;
      if (data.isEmpty) return AuthResult.error('The profile response was empty.');
      final current = Map<String, dynamic>.from(data);
      final nextToken = (current['token'] ?? hit['token'])?.toString();
      final currentUser = current['user'] is Map ? Map<String, dynamic>.from(current['user'] as Map) : current;
      if (nextToken != null && nextToken.isNotEmpty) {
        ApiSession.instance.save(nextToken, currentUser);
      } else {
        ApiSession.instance.user = currentUser;
      }
      return AuthResult.ok(userFromApi(currentUser));
    } on ApiException catch (e) {
      if (e.status == 401) {
        ApiSession.instance.clear();
      }
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('Cannot load the current profile.');
    }
  }

  static Future<AuthResult> guardianEnterSchool(String schoolId) async {
    final school = schoolId.trim();
    if (school.isEmpty) return AuthResult.error('No school was selected.');
    try {
      final hit = await ApiClient.instance.post('${ApiConfig.guardianEnterSchoolPath}/$school/enter', {}, const Duration(seconds: 15));
      final session = _sessionFromMap(hit);
      if (session == null) return AuthResult.error('The school switch response was empty.');
      ApiSession.instance.save(session.token, session.user);
      return AuthResult.ok(userFromApi(session.user));
    } on ApiException catch (e) {
      if (e.status == 403) return AuthResult.error('You are not linked to that school.');
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('Cannot switch to that school right now.');
    }
  }

  static Future<AuthResult> guardianExitSchool() async {
    try {
      final hit = await ApiClient.instance.post(ApiConfig.guardianExitSchoolPath, {}, const Duration(seconds: 15));
      final session = _sessionFromMap(hit);
      if (session == null) return AuthResult.error('The school exit response was empty.');
      ApiSession.instance.save(session.token, session.user);
      return AuthResult.ok(userFromApi(session.user));
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('Cannot leave the current school right now.');
    }
  }

  /// Platform super admin jumping into a specific school's admin context —
  /// mirrors [guardianEnterSchool]/[guardianExitSchool], just for
  /// `platform/schools/{id}/enter` and `platform/exit-school`.
  static Future<AuthResult> platformEnterSchool(String schoolId) async {
    final school = schoolId.trim();
    if (school.isEmpty) return AuthResult.error('No school was selected.');
    try {
      final hit = await ApiClient.instance.post(ApiConfig.platformSchoolEnterPath(school), {}, const Duration(seconds: 15));
      final session = _sessionFromMap(hit);
      if (session == null) return AuthResult.error('The school switch response was empty.');
      ApiSession.instance.save(session.token, session.user);
      return AuthResult.ok(userFromApi(session.user));
    } on ApiException catch (e) {
      if (e.status == 403) return AuthResult.error('You do not have platform access to that school.');
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('Cannot switch to that school right now.');
    }
  }

  static Future<AuthResult> platformExitSchool() async {
    try {
      final hit = await ApiClient.instance.post(ApiConfig.platformExitSchoolPath, {}, const Duration(seconds: 15));
      final session = _sessionFromMap(hit);
      if (session == null) return AuthResult.error('The exit response was empty.');
      ApiSession.instance.save(session.token, session.user);
      return AuthResult.ok(userFromApi(session.user));
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('Cannot leave that school right now.');
    }
  }

  /// Public — no sign-in required. Confirmed live: `school_name`,
  /// `contact_name` and `phone` are required; `email`, `student_count` and
  /// `message` are optional.
  static Future<AuthResult> submitSignupRequest({
    required String schoolName,
    required String contactName,
    required String phone,
    String email = '',
    int? studentCount,
    String message = '',
  }) async {
    final name = schoolName.trim();
    final contact = contactName.trim();
    final phoneValue = phone.trim();
    if (name.isEmpty || contact.isEmpty || phoneValue.isEmpty) {
      return AuthResult.error('Enter the school name, a contact name and a phone number.');
    }
    final body = <String, dynamic>{
      'school_name': name,
      'contact_name': contact,
      'phone': phoneValue,
      if (email.trim().isNotEmpty) 'email': email.trim(),
      if (studentCount != null) 'student_count': studentCount,
      if (message.trim().isNotEmpty) 'message': message.trim(),
    };
    try {
      final hit = await _jsonPost(ApiConfig.signupRequestsPath, body, const Duration(seconds: 15));
      if (hit != null) {
        if (hit.status >= 400) return AuthResult.error(_apiMessage(hit.body, hit.status));
        ApiConfig.markLive(hit.base);
        return AuthResult.pending("Thanks — we've received your school's details. Our team will be in touch shortly.");
      }
    } catch (_) {}
    return AuthResult.error('Could not submit your registration. Check the connection and try again.');
  }

  static Future<AuthResult> forgotPassword(String email) async {
    final value = email.trim();
    if (value.isEmpty) return AuthResult.error('Enter the email address to recover your account.');
    try {
      final hit = await ApiClient.instance.post(ApiConfig.passwordForgotPath, {'email': value}, const Duration(seconds: 15));
      final message = _messageFrom(hit, fallback: 'If that email exists, a reset link has been sent.');
      return AuthResult.pending(message);
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('Could not request a password reset.');
    }
  }

  static Future<AuthResult> resetPassword({
    required String email,
    required String password,
    String? token,
    String? code,
    String? passwordConfirmation,
  }) async {
    final emailValue = email.trim();
    final passwordValue = password.trim();
    if (emailValue.isEmpty || passwordValue.isEmpty) {
      return AuthResult.error('Enter your email and a new password.');
    }
    final finalToken = (token ?? code ?? '').trim();
    final body = <String, dynamic>{
      'email': emailValue,
      'password': passwordValue,
      'password_confirmation': passwordConfirmation ?? passwordValue,
      if (finalToken.isNotEmpty) 'token': finalToken,
      if (finalToken.isNotEmpty) 'code': finalToken,
    };
    try {
      final hit = await ApiClient.instance.post(ApiConfig.passwordResetPath, body, const Duration(seconds: 15));
      final message = _messageFrom(hit, fallback: 'Your password has been reset.');
      return AuthResult.pending(message);
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('The reset request could not be completed.');
    }
  }

  static Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  }) async {
    final body = <String, dynamic>{
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': confirmPassword ?? newPassword,
    };
    try {
      final hit = await ApiClient.instance.put(ApiConfig.passwordUpdatePath, body, const Duration(seconds: 15));
      final message = _messageFrom(hit, fallback: 'Your password has been updated.');
      return AuthResult.pending(message);
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('The password could not be updated.');
    }
  }

  static Future<AuthResult> updateAppearance({required bool dark}) async {
    try {
      final hit = await ApiClient.instance.put(
        ApiConfig.appearancePath,
        {'appearance': dark ? 'dark' : 'light'},
        const Duration(seconds: 15),
      );
      final payload = hit is Map ? Map<String, dynamic>.from(hit) : null;
      final data = _mapOf(payload?['data']) ?? payload;
      if (data == null) return AuthResult.error('The appearance response was empty.');
      final nextToken = (data['token'] ?? payload?['token'])?.toString();
      final currentUser = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : data;
      final updatedUser = userFromApi(currentUser);
      if (nextToken != null && nextToken.isNotEmpty) {
        ApiSession.instance.save(nextToken, currentUser);
      } else if (ApiSession.instance.token != null) {
        ApiSession.instance.save(ApiSession.instance.token!, currentUser);
      } else {
        ApiSession.instance.user = currentUser;
      }
      return AuthResult.ok(updatedUser);
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      return AuthResult.error('The appearance setting could not be saved.');
    }
  }

  static ({String token, Map<String, dynamic> user})? _sessionFromMap(dynamic body) {
    final map = body is Map ? Map<String, dynamic>.from(body) : null;
    if (map == null) return null;
    final session = _sessionFrom(map);
    if (session != null) return session;
    final data = _mapOf(map['data']);
    if (data == null) return null;
    final token = (data['token'] ?? map['token'])?.toString();
    final userJson = data['user'] ?? data;
    if (userJson is! Map || (token == null || token.isEmpty)) return null;
    return (token: token, user: Map<String, dynamic>.from(userJson));
  }

  static String _messageFrom(dynamic response, {required String fallback}) {
    if (response is Map) {
      final message = response['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return fallback;
  }

  static String _apiMessage(Map<String, dynamic> body, int status) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      if (first != null) return first.toString();
    }
    final message = body['message']?.toString();
    if (message != null && message.isNotEmpty && message.toLowerCase() != 'the given data was invalid.') {
      return message;
    }
    if (status == 422) return message ?? 'The provided credentials are incorrect.';
    if (status == 401) return 'Email or password is incorrect.';
    if (status == 429) return 'Too many attempts. Wait a moment and try again.';
    return 'School API returned $status.';
  }

  static Future<({String base, Map<String, dynamic> body, int status})?> _jsonPost(
    String path,
    Map<String, dynamic> body,
    Duration limit,
  ) async {
    ApiConfig.markLive(ApiConfig.apiRoot);
    final url = ApiConfig.endpoint(path);
    try {
      final response = await http
          .post(
            url,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(limit);
      if (response.body.isEmpty) {
        developer.log(
          'Auth POST returned an empty response (${response.statusCode})',
          name: 'e10.auth',
          error: url.toString(),
        );
        return (
          base: ApiConfig.apiRoot,
          body: <String, dynamic>{},
          status: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        developer.log(
          'Auth POST returned non-JSON data (${response.statusCode})',
          name: 'e10.auth',
          error: url.toString(),
        );
        return (
          base: ApiConfig.apiRoot,
          body: <String, dynamic>{'message': response.body},
          status: response.statusCode,
        );
      }
      return (
        base: ApiConfig.apiRoot,
        body: Map<String, dynamic>.from(decoded),
        status: response.statusCode,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Auth POST failed: $url',
        name: 'e10.auth',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      if (ApiSession.instance.isSignedIn) {
        await ApiClient.instance.post(ApiConfig.logoutPath, null, const Duration(seconds: 10));
      }
    } catch (_) {
      // Token is cleared locally even if the server is unreachable.
    }
    ApiSession.instance.clear();
  }
}
