import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/announcements_screen.dart';
import 'package:e10/widgets/common.dart';

const _admin = AppUser(email: '', displayName: 'Test Admin', role: Role.schoolAdmin, subtitle: 'Admin');
const _parent = AppUser(email: '', displayName: 'Test Parent', role: Role.parent, subtitle: 'Parent');
const _teacher = AppUser(email: '', displayName: 'Afia Mensah', role: Role.teacher, subtitle: 'Teacher');

Future<SchoolStore> _pump(WidgetTester tester, AppUser user) async {
  final store = SchoolStore()..schoolName = 'Assemblies of God Academy';
  store.classes.addAll([
    NamedRecord(id: 'c1', name: 'Basic 4'),
    NamedRecord(id: 'c2', name: 'Basic 5'),
  ]);
  store.tables['announcements'] = [
    {
      'id': 'a1',
      'title': 'Test announcement UI',
      'body': 'Verifying the new announcements UI matches the design.',
      'audience': 'all',
      'allow_replies': true,
      'reply_count': 2,
      'replies': [
        {'id': 'r1', 'body': 'Thanks!', 'author': {'guardian_name': 'Kojo Owusu'}},
      ],
      'posted_at': '2026-09-22T19:08:00',
      'poster': {'full_name': 'Joseph Ntierenyin'},
    },
  ];
  await tester.pumpWidget(
    MaterialApp(
      home: SchoolScope(
        store: store,
        child: Scaffold(body: AnnouncementsScreen(user: user, onBack: () {}, onLogout: () {})),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('shows school name, Announcements title and announcement cards', (tester) async {
    await _pump(tester, _parent);

    expect(find.text('Assemblies of God Academy'), findsOneWidget);
    expect(find.text('Announcements'), findsWidgets);
    expect(find.text('Messages'), findsNothing);
    expect(find.text('Test announcement UI'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('JOSEPH NTIERENYIN · 22 Sept 2026, 7:08 PM'), findsOneWidget);
    expect(find.text('Replies (2)'), findsOneWidget);
    // Parents can read and reply, but not post.
    expect(find.text('New'), findsNothing);

    await tester.tap(find.text('Replies (2)'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Thanks!'), findsOneWidget);
  });

  testWidgets('admin gets the New Announcement pop-up with class picker for a single class', (tester) async {
    await _pump(tester, _admin);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('New Announcement'), findsOneWidget);
    expect(find.text('Title *'), findsOneWidget);
    expect(find.text('Audience *'), findsOneWidget);
    expect(find.text('Allow threaded replies'), findsOneWidget);
    expect(find.text('Class *'), findsNothing);

    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Single class').last);
    await tester.pumpAndSettle();
    expect(find.text('Class *'), findsOneWidget);

    final post = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Post announcement'));
    expect(post.onPressed, isNull);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    // Let the form's text fields be cleaned up after its close animation.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a teacher gets the admin form, limited to the classes they teach', (tester) async {
    final store = SchoolStore()..schoolName = 'Assemblies of God Academy';
    // For a teacher session the server only returns the classes they teach:
    // their own class plus any class they take a subject in.
    store.classes.addAll([
      NamedRecord(id: 'c1', name: 'Basic 4', link: 'Afia Mensah'),
      NamedRecord(id: 'c2', name: 'Basic 5'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: AnnouncementsScreen(user: _teacher, onBack: () {}, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    // Same fields as admin's form.
    expect(find.text('New Announcement'), findsOneWidget);
    expect(find.text('Title *'), findsOneWidget);
    expect(find.text('Audience *'), findsOneWidget);
    expect(find.text('Allow threaded replies'), findsOneWidget);
    expect(find.text('Class *'), findsOneWidget);
    // ...but the audience can only be one of their classes, never school-wide.
    expect(find.text('Single class'), findsOneWidget);
    await tester.tap(find.text('Single class'));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsNothing);
    expect(find.text('Parents'), findsNothing);
    expect(find.text('Teachers'), findsNothing);
    await tester.tap(find.text('Single class').last);
    await tester.pumpAndSettle();

    // Both the class they lead and the class they only teach a subject in.
    await tester.tap(find.text('Select class'));
    await tester.pumpAndSettle();
    expect(find.text('Basic 4'), findsWidgets);
    expect(find.text('Basic 5'), findsWidgets);
    await tester.tap(find.text('Basic 5').last);
    await tester.pumpAndSettle();

    final dialogFields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(dialogFields.first, 'Reminder');
    await tester.enterText(dialogFields.last, 'Bring your books tomorrow.');
    await tester.pumpAndSettle();

    final post = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Post announcement'));
    expect(post.onPressed, isNotNull);
  });

  testWidgets('a teacher with no classes cannot post', (tester) async {
    final store = SchoolStore()..schoolName = 'Assemblies of God Academy';
    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: Scaffold(body: AnnouncementsScreen(user: _teacher, onBack: () {}, onLogout: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New'), findsNothing);
  });

  testWidgets('header has one communication icon offering Announcements and Messages', (tester) async {
    var went = '';
    await tester.pumpWidget(
      MaterialApp(
        home: AppChrome(
          messageCount: 3,
          onMessages: () => went = 'messages',
          onAnnouncements: () => went = 'announcements',
          child: const Scaffold(body: Center(child: HeaderChromeActions())),
        ),
      ),
    );

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Announcements, messages & notifications · 3'));
    await tester.pumpAndSettle();
    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);

    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();
    expect(went, 'announcements');
  });
}
