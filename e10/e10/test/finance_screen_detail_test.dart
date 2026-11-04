import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/finance_screen.dart';
import 'package:e10/widgets/txn_charts.dart';

/// Transactions reads the server like the website: tiles and charts from
/// `/transactions-summary`, the table from `/payments`, filters sent to both.
void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'));

  testWidgets('tiles, charts and table come from the server; a row opens the full detail', (tester) async {
    tester.view.physicalSize = const Size(390, 2400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final queries = <String, Map<String, String>>{};
    final client = MockClient((request) async {
      final path = request.url.path;
      queries[path.split('/').last] = request.url.queryParameters;
      if (path.endsWith('transactions-summary')) {
        return http.Response(
            jsonEncode({
              'data': {
                'totals': {
                  'collected': 2800,
                  'collected_count': 2,
                  'by_status': {'successful': 2, 'failed': 1, 'pending': 0},
                },
                'volume_over_time': [
                  {'period': '2026-10-26', 'amount': 2800, 'count': 1},
                  {'period': '2026-10-28', 'amount': 0, 'count': 0},
                ],
                'by_method': [
                  {'method': 'cash', 'amount': 2800, 'count': 2},
                ],
              },
            }),
            200);
      }
      if (path.endsWith('payments')) {
        return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'p1',
                  'amount': 450,
                  'method': 'mtn_momo',
                  'source': 'manual',
                  'status': 'successful',
                  'paid_at': '2026-09-01T10:00:00Z',
                  'receipt_number': 'RCT-0001',
                  'recorded_by_name': 'Bursar Ama',
                  'student': {'id': 'kid-1', 'full_name': 'Ama Owusu'},
                  'fee': 'Term 1 fees',
                  'paid_by': 'Kojo Owusu',
                  'previous_debt': '900.00',
                  'remaining_debt': '450.00',
                  'invoice_number': 'INV-0042',
                },
              ],
              'recorders': [
                {'id': 'u1', 'name': 'Bursar Ama'},
              ],
              'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
            }),
            200);
      }
      return http.Response(jsonEncode({'data': []}), 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SchoolScope(
            store: SchoolStore(),
            child: Scaffold(body: FinanceScreen(onLogout: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The previous filter box: Status, Method, Chart period only.
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Method'), findsOneWidget);
      expect(find.text('Chart period'), findsOneWidget);
      expect(find.text('Provider'), findsNothing);
      expect(find.text('Source'), findsNothing);
      expect(find.text('From'), findsNothing);

      // Server totals, not sums of whatever the phone downloaded.
      expect(find.text('GHS 2,800.00'), findsOneWidget);
      expect(find.text('2 successful payments'), findsOneWidget);
      expect(find.text('1 failed · 0 pending'), findsOneWidget);
      expect(find.byType(TxnChartCard), findsNWidgets(2));
      expect(queries['transactions-summary']?['period'], 'day');
      expect(queries['payments']?['per_page'], '25');

      // Touching the chart shows the day and amount, like the website.
      await tester.tapAt(tester.getTopLeft(find.byType(TxnChartCard).first) + const Offset(60, 120));
      await tester.pumpAndSettle();
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.textContaining('amount : GHS 2,800.00'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Ama Owusu'), 300, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.textContaining('MTN MoMo'), findsOneWidget);
      expect(find.text('by Bursar Ama'), findsOneWidget);

      await tester.tap(find.text('Ama Owusu'));
      await tester.pumpAndSettle();
      expect(find.text('Paid by'), findsOneWidget);
      expect(find.text('Kojo Owusu'), findsOneWidget);
      expect(find.textContaining('INV-0042'), findsOneWidget);
      expect(find.textContaining('900.00'), findsOneWidget);
    }, () => client);
  });
}
