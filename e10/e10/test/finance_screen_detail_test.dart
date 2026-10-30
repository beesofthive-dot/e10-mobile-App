import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/screens/finance_screen.dart';

void main() {
  testWidgets('tapping a payment row shows the full detail (paid by, fee, balances)', (tester) async {
    final store = SchoolStore();
    store.tables['payments'] = [
      {
        'id': 'p1',
        'amount': 450,
        'method': 'mtn_momo',
        'status': 'successful',
        'paid_at': '2026-09-01T10:00:00Z',
        'student': {'id': 'kid-1', 'full_name': 'Ama Owusu'},
        'fee': 'Term 1 fees',
        'paid_by': 'Kojo Owusu',
        'previous_debt': '900.00',
        'remaining_debt': '450.00',
        'invoice_number': 'INV-0042',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: FinanceScreen(onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Ama Owusu'), 300, scrollable: find.byType(Scrollable).first);
    // Nudge further so the row's center (not just its edge) is inside the
    // viewport — scrollUntilVisible stops as soon as any part overlaps.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text('Ama Owusu'), findsOneWidget);

    await tester.tap(find.text('Ama Owusu'));
    await tester.pumpAndSettle();

    expect(find.text('Paid by'), findsOneWidget);
    expect(find.text('Kojo Owusu'), findsOneWidget);
    expect(find.textContaining('INV-0042'), findsOneWidget);
    expect(find.textContaining('900.00'), findsOneWidget);
  });
}
