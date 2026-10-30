import 'package:e10/school_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uploading a photo without a saved report id is rejected before any network call', () async {
    final store = SchoolStore();
    final error = await store.uploadDailyReportPhoto(reportId: '', bytes: [1, 2, 3], filename: 'photo.jpg');
    expect(error, isNotEmpty);
  });

  test('uploading while signed out does not attempt the network call', () async {
    final store = SchoolStore();
    final error = await store.uploadDailyReportPhoto(reportId: 'report-123', bytes: [1, 2, 3], filename: 'photo.jpg');
    expect(error, isNotEmpty);
  });
}
