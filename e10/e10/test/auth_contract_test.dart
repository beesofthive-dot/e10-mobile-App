import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:e10/core/config/api_config.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  test('auth endpoints resolve to the live API root without duplicate /api segments', () {
    expect(ApiConfig.apiBaseUrl, 'https://e10.beesofthive.pro/api');
    expect(ApiConfig.apiRoot, ApiConfig.apiBaseUrl);
    expect(ApiConfig.staffRequestCodePath, 'auth/staff/request-code');
    expect(ApiConfig.staffVerifyCodePath, 'auth/staff/verify-code');
    expect(ApiConfig.guardianRequestPath, 'auth/guardian/request-code');
    expect(ApiConfig.guardianVerifyPath, 'auth/guardian/verify-code');
    expect(ApiConfig.join(ApiConfig.apiRoot, ApiConfig.staffRequestCodePath),
      'https://e10.beesofthive.pro/api/auth/staff/request-code');
    expect(ApiConfig.join(ApiConfig.apiRoot, ApiConfig.staffVerifyCodePath),
      'https://e10.beesofthive.pro/api/auth/staff/verify-code');
    expect(ApiConfig.logoutPath, 'auth/logout');
    expect(ApiConfig.join(ApiConfig.apiRoot, ApiConfig.guardianRequestPath),
        'https://e10.beesofthive.pro/api/auth/guardian/request-code');
    expect(ApiConfig.join(ApiConfig.apiRoot, ApiConfig.logoutPath),
        'https://e10.beesofthive.pro/api/auth/logout');
  });

  test('supplied role endpoints use one normalized API root', () {
    const paths = [
      'auth/login',
      'auth/me',
      'auth/logout',
      'students',
      'staff',
      'guardians',
      'attendance',
      'report-cards',
      'exams',
      'bills',
      'payments',
      'notifications',
      'school-classes',
      'subjects',
    ];

    for (final path in paths) {
      final uri = ApiConfig.endpoint('/$path');
      expect(uri.toString(), 'https://e10.beesofthive.pro/api/$path');
      expect(uri.toString(), isNot(contains('/api//')));
    }
  });
}
