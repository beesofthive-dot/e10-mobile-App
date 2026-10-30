import 'package:flutter_test/flutter_test.dart';

import 'package:e10/widgets/common.dart';

void main() {
  test('formatStamp shows people-friendly date and time', () {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();

    final today = DateTime(now.year, now.month, now.day, 14, 30);
    expect(formatStamp(iso(today)), 'Today, 2:30 PM');

    final yesterday = DateTime(now.year, now.month, now.day - 1, 9, 5);
    expect(formatStamp(iso(yesterday)), 'Yesterday, 9:05 AM');

    expect(formatStamp(iso(DateTime(2025, 3, 7, 0, 15))), '7 Mar 2025, 12:15 AM');
    expect(formatStamp('2025-03-07'), '7 Mar 2025');

    // Not a timestamp: left alone.
    expect(formatStamp('Just now'), 'Just now');
    expect(formatStamp('08:00'), '08:00');
    expect(formatStamp(''), '');
    expect(formatStamp('null'), '');
  });
}
