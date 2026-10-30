import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart';

class AppPrefs extends ChangeNotifier {
  // Index 0 is the seed used in main.dart before a school's own
  // `primary_color` has loaded (or if it never set one) — kept equal to
  // the admin/teacher website's own hardcoded default
  // (frontend/src/theme/ThemeProvider.tsx's DEFAULTS.primary) so the app
  // never flashes/falls back to an unrelated colour the website doesn't
  // also use.
  static const accents = [
    (label: 'Default', color: Color(0xFF5B5BD6)),
    (label: 'Sky', color: Color(0xFF39A9E8)),
    (label: 'Ocean', color: Color(0xFF1668B7)),
    (label: 'Azure', color: Color(0xFF2D8CDE)),
    (label: 'Ice', color: Color(0xFF6DB9EA)),
  ];

  bool dark = false;
  int accentIndex = 0;

  Color get accent => accents[accentIndex.clamp(0, accents.length - 1)].color;

  Future<void> load() async {
    final store = await SharedPreferences.getInstance();
    dark = store.getBool('prefs.dark') ?? false;
    accentIndex = store.getInt('prefs.accent') ?? 0;
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    dark = value;
    notifyListeners();
    final store = await SharedPreferences.getInstance();
    await store.setBool('prefs.dark', value);
    try {
      await Auth.updateAppearance(dark: value);
    } catch (_) {}
  }

  Future<void> setAccent(int index) async {
    accentIndex = index.clamp(0, accents.length - 1);
    notifyListeners();
    final store = await SharedPreferences.getInstance();
    await store.setInt('prefs.accent', accentIndex);
  }

  static AppPrefs of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppPrefsScope>();
    assert(scope != null, 'No AppPrefs found');
    return scope!.notifier!;
  }
}

class _AppPrefsScope extends InheritedNotifier<AppPrefs> {
  const _AppPrefsScope({required AppPrefs prefs, required super.child}) : super(notifier: prefs);
}

class AppPrefsScope extends StatelessWidget {
  const AppPrefsScope({super.key, required this.prefs, required this.child});

  final AppPrefs prefs;
  final Widget child;

  @override
  Widget build(BuildContext context) => _AppPrefsScope(prefs: prefs, child: child);
}
