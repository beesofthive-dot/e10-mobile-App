import 'package:flutter_test/flutter_test.dart';

import 'package:e10/auth.dart';

void main() {
  test('staff OTC identifier keeps emails and normalises phone numbers', () {
    expect(Auth.staffIdentifier(' teacher@school.edu '), 'teacher@school.edu');
    expect(Auth.staffIdentifier('024 400 0000'), '0244000000');
    expect(Auth.staffIdentifier('+233 24-400-0000'), '+233244000000');
  });
}
