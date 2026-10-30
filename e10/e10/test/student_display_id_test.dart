import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';

Student _kid({String id = '01a0b454-3bcb-71b7-bc9c-2590c997e106', String number = '', String card = ''}) => Student(
      id: id,
      name: 'Nana Mensa',
      klass: 'Basic 1',
      avatar: 'N',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
      studentNumber: number,
      cardNumber: card,
    );

void main() {
  final store = SchoolStore();

  test('shows the admission number, else the card number', () {
    expect(store.studentDisplayId(_kid(number: 'AGA123/2026/001')), 'AGA123/2026/001');
    expect(store.studentDisplayId(_kid(card: '10023')), '10023');
  });

  test('never shows a database key, hash or encrypted value', () {
    expect(store.studentDisplayId(_kid()), 'Not assigned');
    expect(store.studentDisplayId(_kid(number: '01J9ZQ3K4M5N6P7Q8R9S0T1V2W')), 'Not assigned'); // ULID
    expect(store.studentDisplayId(_kid(card: 'eyJpdiI6IkZ3b2x0eVZ5T0x1c2JrQT09In0=')), 'Not assigned'); // encrypted
    expect(store.studentDisplayId(_kid(number: '5f8d0d55b54764421b7156c3a1f9e2d4')), 'Not assigned'); // hash
  });

  test('ordinary numbers are not mistaken for machine ids', () {
    for (final ok in ['STU-00042', 'AGA123-2026-0001', '10023', 'KG1/045']) {
      expect(SchoolStore.looksMachineId(ok), isFalse, reason: ok);
    }
  });
}
