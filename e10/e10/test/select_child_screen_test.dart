import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/screens/select_child_screen.dart';

const _demoUser = AppUser(
  email: '',
  displayName: 'Test Guardian',
  role: Role.parent,
  subtitle: 'Parent',
);

const _schools = [
  (id: 'school-a', name: 'New College'),
  (id: 'school-b', name: 'Greenfield Academy'),
];

void main() {
  testWidgets('shows every school this phone number is linked to', (tester) async {
    final store = SchoolStore();
    store.schoolId = 'school-a';

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: SelectChildScreen(
            schools: _schools,
            initialUser: _demoUser,
            onContinue: (user) async {},
          ),
        ),
      ),
    );

    expect(find.text('New College'), findsOneWidget);
    expect(find.text('Greenfield Academy'), findsOneWidget);
    expect(find.textContaining('linked to more than one school'), findsOneWidget);
  });

  testWidgets('picking the school verify-code already resolved into continues without switching', (tester) async {
    final store = SchoolStore();
    store.schoolId = 'school-a';
    AppUser? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolScope(
          store: store,
          child: SelectChildScreen(
            schools: _schools,
            initialUser: _demoUser,
            onContinue: (user) async {
              picked = user;
            },
          ),
        ),
      ),
    );

    // The current school (matching store.schoolId) doesn't need an
    // Auth.guardianEnterSchool round trip — it should just continue with
    // the session verify-code already produced.
    await tester.tap(find.text('New College'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(picked, same(_demoUser));
    // Shown here as the only screen, so there is nothing to close back to —
    // it must not try (that is the "_history.isNotEmpty" crash).
    expect(tester.takeException(), isNull);
  });
}
