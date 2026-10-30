import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parents get new-homework, due-tomorrow and due-today notices', () async {
    final store = SchoolStore();
    store.applyUserSchool(const AppUser(email: 'p@x', displayName: 'Parent', role: Role.parent, subtitle: ''));
    final now = DateTime.now();
    store.tables['assignments'] = [
      {'id': 'a1', 'title': 'Fractions', 'subject': {'name': 'Maths'}, 'deadline': _day(now.add(const Duration(days: 1))), 'created_at': now.toIso8601String()},
      {'id': 'a2', 'title': 'Essay', 'subject': {'name': 'English'}, 'deadline': _day(now), 'created_at': now.subtract(const Duration(days: 5)).toIso8601String()},
      {'id': 'a3', 'title': 'Old work', 'deadline': _day(now.subtract(const Duration(days: 3))), 'created_at': now.subtract(const Duration(days: 9)).toIso8601String()},
    ];

    expect(await store.rebuildHomeworkNotices(), isTrue);
    final notices = {for (final n in store.noticesFor(Role.parent)) n.id: n};

    expect(notices['hw-new-a1']?.title, 'New homework');
    expect(notices['hw-new-a1']?.text, startsWith('Maths: Fractions'));
    expect(notices['hw-due1-a1']?.title, 'Homework due tomorrow');
    expect(notices['hw-due0-a2']?.title, 'Homework due today');
    expect(notices.keys.where((k) => k.contains('a3')), isEmpty);
    expect(store.unreadNoticeCount(Role.parent), 3);

    store.markNoticeRead('hw-due0-a2');
    await store.rebuildHomeworkNotices();
    expect(store.unreadNoticeCount(Role.parent), 2, reason: 'read state survives a rebuild');
  });

  test('admins do not get homework notices', () async {
    final store = SchoolStore();
    store.applyUserSchool(const AppUser(email: 'a@x', displayName: 'Admin', role: Role.admin, subtitle: ''));
    store.tables['assignments'] = [
      {'id': 'a1', 'title': 'Fractions', 'deadline': _day(DateTime.now()), 'created_at': DateTime.now().toIso8601String()},
    ];
    expect(await store.rebuildHomeworkNotices(), isFalse);
    expect(store.noticesFor(Role.admin).where((n) => n.type == 'homework'), isEmpty);
  });
}
