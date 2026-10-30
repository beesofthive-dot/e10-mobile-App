import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/app.dart';
import 'package:e10/app_prefs.dart';
import 'package:e10/models.dart';
import 'package:e10/school_store.dart';
import 'package:e10/theme.dart';
import 'package:e10/widgets/common.dart';

Future<void> _open(WidgetTester tester, AppUser user) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    AppPrefsScope(
      prefs: AppPrefs(),
      child: SchoolScope(
        store: SchoolStore(),
        child: MaterialApp(
          theme: AppTheme.build(brightness: Brightness.light, seed: AppColors.honey),
          home: E10App(debugUser: user, debugScreen: AppScreen.payments),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

List<String> _tabs(WidgetTester tester) => [
      for (final label in ['Home', 'Timetable', 'Fees', 'Feeding', 'Reports'])
        if (find.descendant(of: find.byType(BottomNav), matching: find.text(label)).evaluate().isNotEmpty) label,
    ];

/// Parents always get four bottom tabs; Feeding takes Timetable's place
/// when the school's plan includes feeding.
void main() {
  testWidgets('with feeding in the plan: Home, Fees, Feeding, Reports', (tester) async {
    await _open(tester, const AppUser(email: 'p@s.test', displayName: 'Kofi', role: Role.parent, subtitle: 'Parent'));
    expect(_tabs(tester), ['Home', 'Fees', 'Feeding', 'Reports']);
  });

  testWidgets('without feeding: Home, Timetable, Fees, Reports', (tester) async {
    await _open(
      tester,
      const AppUser(
        email: 'p@s.test',
        displayName: 'Kofi',
        role: Role.parent,
        subtitle: 'Parent',
        schoolModules: ['fees', 'timetable_assignments', 'academics'],
      ),
    );
    expect(_tabs(tester), ['Home', 'Timetable', 'Fees', 'Reports']);
  });
}
