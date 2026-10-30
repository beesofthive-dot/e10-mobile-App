import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/app.dart';
import 'package:e10/app_prefs.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/theme.dart';

/// Opens every screen each role can reach on a phone turned sideways (and
/// upright) and fails if any of them overflows — the yellow/black stripes.
void main() {
  const roles = {
    Role.schoolAdmin: 'School Admin',
    Role.parent: 'Parent',
    Role.teacher: 'Teacher',
    Role.cashier: 'Cashier',
    Role.accountant: 'Bursar',
  };
  const skip = {AppScreen.splash, AppScreen.landing, AppScreen.login, AppScreen.schoolSignup, AppScreen.studentDetail};
  const sizes = {
    'landscape': Size(800, 360),
    'portrait': Size(360, 760),
    'small phone': Size(320, 568),
    'narrow window': Size(380, 460),
  };

  for (final seeded in [false, true]) {
  for (final role in roles.keys) {
    for (final screen in AppScreen.values) {
      if (skip.contains(screen) || !role.canOpen(screen)) continue;
      for (final entry in sizes.entries) {
        testWidgets('${seeded ? 'data' : 'empty'} ${role.name} ${screen.name} ${entry.key}', (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = entry.value * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          final overflows = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.exceptionAsString();
            if (text.contains('overflowed')) {
              final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString())?.group(0) ?? '?';
              overflows.add('${text.split('\n').first} at $where');
            } else {
              previous?.call(details);
            }
          };
          addTearDown(() => FlutterError.onError = previous);

          final user = AppUser(email: 'user@school.test', displayName: 'Afia Mensah-Boateng', role: role, subtitle: roles[role]!);
          final store = SchoolStore();
          if (seeded) {
            _seed(store, role);
            addTearDown(() => ApiSession.instance.user = null);
          }
          await tester.pumpWidget(
            AppPrefsScope(
              prefs: AppPrefs(),
              child: SchoolScope(
                store: store,
                child: MaterialApp(
                  theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
                  home: E10App(debugUser: user, debugScreen: screen),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));

          // Lazily-built lists only lay out what is visible, so scroll down
          // to bring the rest of the page into view.
          for (var i = 0; i < 4; i++) {
            final scrollables = find.byType(Scrollable);
            if (scrollables.evaluate().isEmpty) break;
            await tester.drag(scrollables.first, const Offset(0, -300), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
          }
          await tester.pump(const Duration(seconds: 1));

          FlutterError.onError = previous;
          expect(overflows, isEmpty, reason: overflows.toSet().join('\n'));
        });
      }
    }
  }
  }
}

/// A realistic, wordy school: long names, big numbers, a full week of
/// lessons — the content that pushes layouts past the screen edge.
void _seed(SchoolStore store, Role role) {
  const names = [
    'Nana Akosua Owusu-Ansah', 'Kwabena Asamoah-Gyamfi', 'Abena Serwaa Boakye', 'Kofi Adomako Mensah',
    'Ama Konadu Darko', 'Yaw Barimah Frimpong', 'Efua Nyarko Antwi', 'Kwame Ofori-Atta Junior',
  ];
  const classes = [('c1', 'Basic 4 Gold'), ('c2', 'Junior High School 2 B'), ('c3', 'Kindergarten 1')];
  const subjects = ['Mathematics', 'English Language', 'Integrated Science', 'Religious & Moral Education', 'Creative Arts and Design'];
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  Map<String, dynamic> studentRow(int i) => {
        'id': 's$i',
        'full_name': names[i % names.length],
        'status': 'active',
        'student_number': 'STU-2026-00${i + 100}',
        'gender': i.isEven ? 'female' : 'male',
        'date_of_birth': '2015-03-1$i',
        'residence_type': i == 3 ? 'boarding' : 'day',
        'enrollments': [
          {'class': {'id': classes[i % 3].$1, 'name': classes[i % 3].$2}},
        ],
      };

  store.applyBootstrap({
    'school': {'name': 'Bright Future International Academy, East Legon', 'motto': 'Knowledge, Discipline and Service'},
    'tables': {
      'students': [for (var i = 0; i < 8; i++) studentRow(i)],
      'school_classes': [
        for (final c in classes)
          {'id': c.$1, 'name': c.$2, 'capacity': 45, 'class_teacher': {'full_name': 'Afia Mensah-Boateng', 'user_id': 'u1'}},
      ],
      'departments': [
        {'id': 'd1', 'name': 'Science and Mathematics', 'description': 'Core sciences', 'status': 'active'},
        {'id': 'd2', 'name': 'PreSchool', 'description': 'Early years', 'status': 'active'},
      ],
      'staff': [
        for (var i = 0; i < 4; i++)
          {'id': 't$i', 'full_name': names[(i + 2) % names.length], 'category': 'teacher', 'phone': '+233 24 555 01$i$i', 'email': 'teacher$i@brightfuture.edu.gh'},
      ],
    },
  });

  store.invoices.addAll([
    for (var i = 0; i < 4; i++)
      Invoice(
        id: 'b$i', student: names[i], studentId: 's$i', amount: 12450.75, amountPaid: 3200, balance: 9250.75,
        date: '2026-09-0${i + 1}', status: i.isEven ? 'unpaid' : 'partial',
        description: 'First Term School Fees, Feeding and Transport', invoiceNumber: 'INV-2026-000${i + 1}', dueDate: '2026-10-15',
      ),
  ]);
  store.timetable.addAll([
    for (final d in days)
      for (var p = 0; p < 5; p++)
        TimeSlot(
          id: '$d$p', classId: 'c1', className: classes[0].$2, day: d,
          start: '${(7 + p).toString().padLeft(2, '0')}:30', end: '${(8 + p).toString().padLeft(2, '0')}:20',
          subject: subjects[p], teacher: names[p], room: 'Science Laboratory Block B',
        ),
  ]);
  store.academics.addAll([
    for (var i = 0; i < 8; i++)
      AcademicMark(
        id: 'm$i', student: names[i], klass: classes[0].$2, subject: subjects[i % 5], term: 'Term 1',
        score: 60 + i * 4, grade: 'B${i % 3 + 1}', remark: 'Very good progress this term',
      ),
  ]);
  store.messages.addAll([
    for (var i = 0; i < 5; i++)
      ChatPreview(
        id: 'th$i', from: names[i], role: 'Parent of ${names[i + 1]}', time: '10:4$i AM',
        preview: 'Good morning, please my ward will not be in school tomorrow because of a hospital appointment',
        unread: i.isEven, unreadCount: i, avatar: names[i],
      ),
  ]);
  store.notifications.addAll([
    for (var i = 0; i < 5; i++)
      AppNotification(
        id: 'n$i', type: 'announcement', title: 'Mid-term break and PTA meeting reminder',
        text: 'Parents are reminded that the PTA meeting takes place on Saturday at 9:00 AM in the main assembly hall.',
        time: '2 hours ago', icon: 'campaign', color: 'honey',
      ),
  ]);

  if (role == Role.parent) {
    ApiSession.instance.user = {
      'id': 'u-parent',
      'guardian': {
        'id': 'g1',
        'students': [studentRow(0), studentRow(1)],
      },
    };
  }
}
