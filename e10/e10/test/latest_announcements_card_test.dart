import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/school_store.dart';
import 'package:e10/widgets/home_cards.dart';

void main() {
  testWidgets('dashboard card shows the newest announcements with poster, time and audience', (tester) async {
    final store = SchoolStore();
    store.tables['announcements'] = [
      {'id': 'a1', 'title': 'Oldest', 'body': 'x', 'audience': 'all', 'posted_at': '2025-01-01T09:00:00Z'},
      {
        'id': 'a2',
        'title': 'Sports day',
        'body': 'Wear house colours on Friday.',
        'audience': 'all',
        'posted_at': '2025-03-07T14:30:00Z',
        'poster': {'full_name': 'Ama Mensah'},
      },
      {
        'id': 'a3',
        'title': 'Basic 4 trip',
        'body': 'Consent forms due.',
        'audience': 'single_class',
        'class': {'name': 'Basic 4'},
        'posted_at': '2025-03-06T08:00:00Z',
      },
      {'id': 'a4', 'title': 'PTA meeting', 'body': 'Saturday 10am.', 'audience': 'parents', 'posted_at': '2025-03-05T08:00:00Z'},
    ];
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolScope(
            store: store,
            child: SingleChildScrollView(child: LatestAnnouncementsCard(onOpen: () => opened = true)),
          ),
        ),
      ),
    );

    // Newest three, newest first; the oldest is left for "See all".
    expect(find.text('Sports day'), findsOneWidget);
    expect(find.text('Basic 4 trip'), findsOneWidget);
    expect(find.text('PTA meeting'), findsOneWidget);
    expect(find.text('Oldest'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Sports day')).dy,
      lessThan(tester.getTopLeft(find.text('Basic 4 trip')).dy),
    );

    // Readable audience, poster and date — no raw timestamps.
    expect(find.text('Everyone'), findsOneWidget);
    expect(find.text('Basic 4'), findsOneWidget);
    expect(find.text('Parents'), findsOneWidget);
    expect(find.textContaining('Ama Mensah · 7 Mar 2025'), findsOneWidget);
    expect(find.textContaining('T14:30'), findsNothing);

    await tester.tap(find.text('See all'));
    expect(opened, isTrue);
  });
}
