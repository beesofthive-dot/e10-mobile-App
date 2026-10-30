import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/app.dart';
import 'package:e10/app_prefs.dart';
import 'package:e10/auth.dart';
import 'package:e10/data.dart';
import 'package:e10/feeding.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/theme.dart';

const _cashier = AppUser(
  email: 'cash@school.test',
  displayName: 'Esi',
  role: Role.cashier,
  subtitle: 'Cashier',
  permissions: ['payments.collect', 'feeding.collect'],
);

final _feedingRow = {
  'student_id': 'st1',
  'full_name': 'Kwame Boateng',
  'admission_number': 'AG-001',
  'class_name': 'Basic 1',
  'rate': '5.00',
  'boarder': false,
  'state': 'unpaid_present',
  'present_today': true,
  'covered_until': null,
  'days_in_hand': 0,
  'unpaid_days': 1,
  'unpaid_amount': '5.00',
  'change': '0.00',
};

/// Answers like the live API (shapes taken from the website's cashier pages).
http.Response _reply(http.Request r) {
  final path = r.url.path.replaceFirst('/api/', '');
  Object? data;
  switch (path) {
    case 'cashier/my-day':
      data = {
        'fees': {'total': '120.00', 'count': 2, 'cash': '100.00'},
        'feeding': {'total': '10.00', 'count': 1, 'cash': '10.00'},
        'cash_to_hand_over': '110.00',
        'not_paid_feeding': [_feedingRow],
        'payments': [
          {
            'id': 'p1',
            'kind': 'fees',
            'paid_at': '2026-10-26T08:30:00Z',
            'receipt_number': 'RCT-0001',
            'student': 'Ama Mensah',
            'method': 'mtn_momo',
            'amount': '100.00',
            'receipt_url': '/api/payments/p1/receipt',
          },
        ],
      };
    case 'cashier/students':
      data = [
        {'id': 'st1', 'full_name': 'Kwame Boateng', 'admission_number': 'AG-001', 'class_name': 'Basic 1', 'owing': '0.00'},
      ];
    case 'cashier/students/st1':
      data = {
        'id': 'st1',
        'full_name': 'Kwame Boateng',
        'admission_number': 'AG-001',
        'class_name': 'Basic 1',
        'guardians': [
          {'full_name': 'Yaw Boateng', 'relationship': 'Father', 'phone': '0240000000'},
        ],
        'fees': {'owing': '0.00', 'bills': []},
        'feeding': _feedingRow,
      };
    case 'feeding/settings':
      data = {'week_days': 5, 'month_days': 20};
    case 'feeding/today':
      data = {
        'date': '2026-10-26',
        'feeding_today': true,
        'set_up': true,
        'week_days': 5,
        'month_days': 20,
        'classes': [
          {'id': 'c1', 'name': 'Basic 1'},
        ],
        'students': r.url.queryParameters.isEmpty ? [] : [_feedingRow],
      };
    case 'feeding/my-day':
      data = {'cash': '10.00', 'mobile_money': '0.00', 'total': '10.00', 'count': 1};
    case 'feeding/quote':
      data = {'amount': '5.00', 'arrears_days': 1, 'ahead_days': 0, 'covers': 'Mon 26 Oct', 'change_before': '0', 'change_after': '0', 'unpaid_left': 0};
    default:
      data = [];
  }
  return http.Response(jsonEncode({'data': data}), 200, headers: {'content-type': 'application/json'});
}

Future<void> _open(WidgetTester tester, AppUser user, AppScreen screen) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppPrefsScope(
      prefs: AppPrefs(),
      child: SchoolScope(
        store: SchoolStore(),
        child: MaterialApp(
          theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
          home: E10App(debugUser: user, debugScreen: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  setUp(() => ApiSession.instance.token = 'test-token');
  tearDown(() => ApiSession.instance.token = null);

  test('a cashier gets the cashier portal; a bursar stays on finance', () {
    expect(Auth.roleFromApi({'roles': ['cashier'], 'staff': {}}), Role.cashier);
    expect(Auth.roleFromApi({'roles': ['bursar', 'cashier'], 'staff': {}}), Role.accountant);
    expect(Auth.roleFromApi({'roles': [], 'staff': {'category': 'cashier'}}), Role.cashier);
    expect(homeFor(Role.cashier), AppScreen.cashierCounter);
    expect([for (final n in navFor(Role.cashier)) n.screen], [
      AppScreen.cashierCounter,
      AppScreen.feedingToday,
      AppScreen.schoolLife,
      AppScreen.myAttendance,
    ]);
    // Announcements stays reachable from the header's comms menu.
    expect(Role.cashier.canOpen(AppScreen.teacherAnnouncements), isTrue);
    expect(Role.cashier.canOpen(AppScreen.adminFinance), isFalse);
    // Messages is offered only when the school grants `messages.view`.
    expect(Role.cashier.canOpen(AppScreen.studentDetail), isFalse);
  });

  test('money reads like the website', () {
    expect(money('1234.5', 'GHS'), 'GHS 1,234.50');
    expect(money(null, 'GHS'), 'GHS 0.00');
    expect(dayLabel('2026-10-26'), 'Mon, 26 Oct');
  });

  testWidgets('the counter shows takings, unpaid feeding and the found student', (tester) async {
    await http.runWithClient(() async {
      await _open(tester, _cashier, AppScreen.cashierCounter);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('GHS 120.00'), findsOneWidget);
      expect(find.text('GHS 110.00'), findsOneWidget);
      expect(find.text('Present today, not paid for feeding'), findsOneWidget);
      expect(find.text('Kwame Boateng'), findsOneWidget);
      expect(find.text('My payments today'), findsOneWidget);
      expect(find.textContaining('RCT-0001'), findsOneWidget);
      expect(find.text('Counter'), findsWidgets); // bottom nav

      await tester.enterText(find.byType(TextField).first, 'Kwa');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Fees paid'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('School fees · owes GHS 0.00'), findsOneWidget);
      expect(find.text('Nothing owed.'), findsOneWidget);
      expect(find.text('Present today, not paid'), findsOneWidget);
      expect(find.text('1 unpaid day · GHS 5.00'), findsOneWidget);
      expect(find.text('Yaw Boateng'), findsOneWidget);
    }, () => MockClient((r) async => _reply(r)));
  });

  testWidgets('feeding today lists a class and quotes a payment', (tester) async {
    await http.runWithClient(() async {
      await _open(tester, _cashier, AppScreen.feedingToday);
      expect(find.text('Pick a class or search for a child'), findsOneWidget);
      expect(find.text('My takings today'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Kwame');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Not paid · present'), findsOneWidget);

      await tester.tap(find.text('Record'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Record feeding'), findsOneWidget);
      expect(find.text('Collect GHS 5.00'), findsOneWidget);
      expect(find.text('Pay unpaid days first'), findsOneWidget);
    }, () => MockClient((r) async => _reply(r)));
  });

  testWidgets('a school without the feeding module never shows feeding', (tester) async {
    const user = AppUser(
      email: 'cash@school.test',
      displayName: 'Esi',
      role: Role.cashier,
      subtitle: 'Cashier',
      permissions: ['payments.collect', 'feeding.collect'],
      schoolModules: ['fees', 'attendance', 'announcements'],
    );
    await http.runWithClient(() async {
      await _open(tester, user, AppScreen.cashierCounter);
      expect(find.text('Feeding'), findsNothing);
      expect(find.text('Present today, not paid for feeding'), findsNothing);
      expect(find.text('Counter'), findsWidgets);
    }, () => MockClient((r) async => _reply(r)));
  });
}
