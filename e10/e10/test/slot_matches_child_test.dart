import 'package:flutter_test/flutter_test.dart';

import 'package:e10/models.dart';
import 'package:e10/school_store.dart';

TimeSlot _slot(String cls, {String classId = ''}) => TimeSlot(
      id: 't',
      classId: classId,
      className: cls,
      day: 'Monday',
      start: '08:00',
      end: '09:00',
      subject: 'Maths',
      teacher: 'T',
      room: 'A1',
    );

Student _child({String classId = ''}) => Student(
      id: 's1',
      name: 'Kofi',
      klass: 'JHS 1A',
      classId: classId,
      avatar: 'K',
      attendance: 0,
      fees: 0,
      outstanding: 0,
      status: 'active',
    );

void main() {
  final store = SchoolStore();

  test('matches by class name ignoring spaces/case when ids are missing', () {
    expect(store.slotMatchesChild(_slot('JHS 1 A'), _child()), isTrue);
    expect(store.slotMatchesChild(_slot('JHS 2 A'), _child()), isFalse);
  });

  test('id match wins when both sides have a class id', () {
    final kid = _child(classId: 'c1');
    expect(store.slotMatchesChild(_slot('Other', classId: 'c1'), kid), isTrue);
    expect(store.slotMatchesChild(_slot('JHS 1A', classId: 'c2'), kid), isFalse);
  });
}
