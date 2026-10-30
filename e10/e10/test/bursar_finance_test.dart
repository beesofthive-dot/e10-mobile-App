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
import 'package:e10/data.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/theme.dart';

const _bursar = AppUser(
  email: 'bursar@school.test',
  displayName: 'Ama',
  role: Role.accountant,
  subtitle: 'Bursar',
  permissions: [
    'feeding.view',
    'feeding.void',
    'feeding.cashup',
    'feeding.settings',
    'expenses.view',
    'expenses.create',
    'expenses.update',
    'expenses.void',
    'expenses.categories',
  ],
);

/// Replies shaped like the live API (from the website's Finance pages).
http.Response _reply(http.Request r) {
  final path = r.url.path.replaceFirst('/api/', '');
  Object? body;
  switch (path) {
    case 'feeding/today':
      body = {'data': {'date': '2026-10-26', 'feeding_today': true, 'set_up': true, 'week_days': 5, 'month_days': 22, 'classes': [], 'students': []}};
    case 'feeding/payments':
      body = {
        'data': [
          {
            'id': 'f1',
            'paid_at': '2026-10-26T09:00:00Z',
            'receipt_number': 'FD-0001',
            'student': 'Kwame Boateng',
            'amount': '50.00',
            'paid_for': '5 days',
            'method': 'cash',
            'cashier': 'Esi',
            'voided': false,
          },
        ],
        'cashiers': [
          {'id': 'c1', 'name': 'Esi'},
        ],
        'meta': {'last_page': 1},
      };
    case 'feeding/cashups':
      body = {
        'data': {
          'rows': [
            {'cashier_id': 'c1', 'cashier': 'Esi', 'count': 3, 'cash': '150.00', 'mobile_money': '20.00', 'received': '140.00', 'difference': '-10.00'},
          ],
        },
      };
    case 'feeding/report':
      body = {
        'data': {
          'periods': [
            {'key': 'today', 'label': 'Today', 'total': '170.00', 'cash': '150.00', 'mobile_money': '20.00', 'count': 4},
          ],
          'not_paid_today': [],
          'unpaid': [
            {'student_id': 's1', 'full_name': 'Joseph Mensah', 'class_name': 'KG1', 'days': 2, 'amount': '20.00', 'since': '2026-10-22'},
          ],
          'unpaid_total': '20.00',
        },
      };
    case 'feeding/settings':
      body = {
        'data': {
          'saved': true,
          'start_date': '2026-10-15',
          'feeding_days': [1, 2, 3, 4, 5],
          'week_days': 5,
          'month_days': 22,
          'rates': [
            {'scope': 'school', 'scope_id': null, 'daily_rate': '10.00', 'week_price': null, 'month_price': null},
            {'scope': 'class', 'scope_id': 'k1', 'daily_rate': '20.00', 'week_price': null, 'month_price': null},
          ],
          'departments': [],
          'classes': [
            {'id': 'k1', 'name': 'KG1 A'},
          ],
        },
      };
    case 'expense-categories':
      body = {
        'data': [
          {'id': 'e1', 'name': 'Utilities', 'is_active': true},
        ],
      };
    case 'expenses':
      body = {
        'data': [
          {
            'id': 'x1',
            'spent_on': '2026-10-20',
            'category': 'Utilities',
            'expense_category_id': 'e1',
            'paid_to': 'ECG',
            'description': 'Electricity for October',
            'amount': '300.00',
            'payment_method': 'mobile_money',
            'recorded_by': 'Ama',
            'voided_at': null,
          },
        ],
        'totals': {
          'amount': '300.00',
          'count': 1,
          'by_category': [
            {'expense_category_id': 'e1', 'name': 'Utilities', 'amount': '300.00', 'count': 1},
          ],
        },
        'meta': {'last_page': 1},
      };
    default:
      body = {'data': []};
  }
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
}

Future<void> _open(WidgetTester tester, AppScreen screen) async {
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
          home: E10App(debugUser: _bursar, debugScreen: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.widgetWithText(ChoiceChip, label));
  await tester.pump();
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://school.test/api'));
  setUp(() => ApiSession.instance.token = 'test-token');
  tearDown(() => ApiSession.instance.token = null);

  test('the bursar menu follows the website Finance menu', () {
    expect([for (final n in navFor(Role.accountant)) n.label], ['Home', 'Payments', 'Expenses', 'Feeding']);
    expect(Role.parent.canOpen(AppScreen.expenses), isFalse);
    expect(Role.cashier.canOpen(AppScreen.expenses), isFalse);
  });

  testWidgets('the bursar gets every Feeding tab with live-shaped data', (tester) async {
    await http.runWithClient(() async {
      await _open(tester, AppScreen.feedingToday);
      for (final label in ['Feeding today', 'Payments', 'Cash-up', 'Report', 'Rates & days']) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }

      await _tab(tester, 'Payments');
      expect(find.text('Kwame Boateng'), findsOneWidget);
      expect(find.text('Void'), findsOneWidget);

      await _tab(tester, 'Cash-up');
      expect(find.text('Esi'), findsOneWidget);
      expect(find.text('Short GHS 10.00'), findsOneWidget);

      await _tab(tester, 'Report');
      expect(find.text('Unpaid days · GHS 20.00 owed'), findsOneWidget);
      expect(find.text('Joseph Mensah'), findsOneWidget);

      await _tab(tester, 'Rates & days');
      expect(find.text('Whole school'), findsOneWidget);
      expect(find.text('Save rates'), findsOneWidget);
    }, () => MockClient((r) async => _reply(r)));
  });

  testWidgets('the expenses page lists totals and expenses', (tester) async {
    await http.runWithClient(() async {
      await _open(tester, AppScreen.expenses);
      expect(find.text('Total spent'), findsOneWidget);
      expect(find.text('ECG'), findsOneWidget);
      expect(find.text('Record expense'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    }, () => MockClient((r) async => _reply(r)));
  });
}
