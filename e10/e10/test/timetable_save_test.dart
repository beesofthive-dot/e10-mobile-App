import 'package:flutter_test/flutter_test.dart';

import 'package:e10/api/api_session.dart';
import 'package:e10/school_store.dart';

void main() {
  test('period times are sent in the server format', () {
    expect(SchoolStore.apiTime('7:30'), '07:30:00');
    expect(SchoolStore.apiTime('07:30'), '07:30:00');
    expect(SchoolStore.apiTime('1:05 PM'), '13:05:00');
    expect(SchoolStore.apiTime('12:10 am'), '00:10:00');
    expect(SchoolStore.apiTime('08:15:00'), '08:15:00');
    expect(SchoolStore.apiTime('8.45'), '08:45:00');
    expect(SchoolStore.apiTime('25:00'), '');
    expect(SchoolStore.apiTime('soon'), '');
  });

  test('a period is checked before it is sent to the server', () async {
    ApiSession.instance.token = 'test-token';
    addTearDown(() => ApiSession.instance.token = null);
    final store = SchoolStore();
    store.classes.add(NamedRecord(id: 'c1', name: 'Basic 4'));
    store.tables['subjects'] = [
      {'id': 's1', 'name': 'Maths'},
    ];
    store.teachers.add(NamedRecord(id: 't1', name: 'Afia Mensah'));

    TimeSlot slot({String subject = 'Maths', String teacher = 'Afia Mensah', String start = '07:30', String end = '08:15'}) =>
        TimeSlot(id: '', className: 'Basic 4', day: 'Monday', start: start, end: end, subject: subject, teacher: teacher, room: '');

    expect(await store.saveTimetableSlot(slot(subject: 'Dance')), contains('subject'));
    expect(await store.saveTimetableSlot(slot(teacher: 'Nobody')), contains('teacher'));
    expect(await store.saveTimetableSlot(slot(start: 'soon')), contains('times'));
    expect(await store.saveTimetableSlot(slot(start: '09:00', end: '08:00')), contains('end after'));
  });
}
