import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:e10/models.dart';
import 'package:e10/widgets/feeding_manage.dart';
import 'package:e10/widgets/money_dashboard_card.dart';

const _admin = AppUser(
  email: 'admin@school.edu',
  displayName: 'Admin',
  role: Role.schoolAdmin,
  subtitle: '',
  permissions: ['payments.view'],
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'));

  testWidgets('Money card shows figures, opens pages and shows the weekly details', (tester) async {
    tester.view.physicalSize = const Size(390, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async => http.Response(
        jsonEncode({
          'data': {
            'label': 'Term 1',
            'collected': 1200,
            'collected_count': 4,
            'billed': 3000,
            'outstanding': 1800,
            'students_owing': 3,
            'collection_rate': 40,
            'collection_term': 'Term 1',
            'expenses': 1500,
            'expenses_count': 2,
            'net': -300,
            'chart': [
              {'label': 'W1', 'in': 500, 'out': 200},
              {'label': 'W2', 'in': 700, 'out': 1300},
            ],
            'top_owing': [
              {'student_id': 's1', 'full_name': 'Ama Owusu', 'admission_number': 'A12', 'owed': 900},
            ],
            'latest_payments': [
              {'id': 'p1', 'student': 'Kofi Boateng', 'method': 'cash', 'paid_at': '2026-11-03', 'amount': 300},
            ],
          },
        }),
        200));
    final opened = <AppScreen>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_host(MoneyDashboardCard(user: _admin, onNav: opened.add)));
      await tester.pumpAndSettle();
      expect(find.text('Money · Term 1'), findsOneWidget);
      expect(find.text('Collection rate'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);

      await tester.tap(find.text('Expenses'));
      expect(opened, [AppScreen.expenses]);

      await tester.tap(find.text('Show details'));
      await tester.pumpAndSettle();
      expect(find.text('Money in'), findsOneWidget);
      expect(find.byType(MoneyInOutChart), findsOneWidget);
      expect(find.text('Students owing the most'), findsOneWidget);
      expect(find.textContaining('Ama Owusu'), findsOneWidget);
      expect(find.textContaining('Kofi Boateng'), findsOneWidget);
      expect(find.text('Hide details'), findsOneWidget);
    }, () => client);
  });

  testWidgets('Who pays lists children and marks the ticked ones as not paying', (tester) async {
    tester.view.physicalSize = const Size(390, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? saved;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        saved = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'message': '1 child updated'}), 200);
      }
      return http.Response(
          jsonEncode({
            'data': [
              {'student_id': 's1', 'full_name': 'Ama Owusu', 'class_name': 'Basic 4', 'exempt': null, 'unpaid_days': 0},
              {
                'student_id': 's2',
                'full_name': 'Yaw Mensah',
                'class_name': 'Basic 5',
                'exempt': {'label': 'Brings food from home', 'automatic': false},
                'unpaid_days': 2,
                'unpaid_amount': 20,
              },
            ],
            'counts': {'paying': 1, 'not_paying': 1},
            'classes': [
              {'id': 'c1', 'name': 'Basic 4'},
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          }),
          200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_host(const FeedingWhoPaysTab(currency: 'GHS')));
      await tester.pumpAndSettle();
      expect(find.text('Who pays daily feeding'), findsOneWidget);
      expect(find.text('Pays daily'), findsOneWidget);
      expect(find.text('Doesn’t pay · Brings food from home'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // Tick Ama, then mark her as not paying (default reason).
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(find.text('1 ticked'), findsOneWidget);
      await tester.tap(find.text('Mark as not paying'));
      await tester.pumpAndSettle();
      // Let the "1 child updated" message hide itself.
      await tester.pump(const Duration(seconds: 10));
    }, () => client);
    expect(saved, {'student_ids': ['s1'], 'reason': 'brings_food'});
  });
}
