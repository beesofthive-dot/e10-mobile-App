import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Saves a receipt (PDF, or a photo when [mime] says so) to the app's temp
/// folder and opens it in the phone's viewer (from there it can be printed
/// or shared).
Future<void> openPdfBytes(Uint8List bytes, String name, {String mime = 'application/pdf'}) async {
  final dir = await getTemporaryDirectory();
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final ext = mime == 'application/pdf' ? 'pdf' : mime.split('/').last;
  final file = File('${dir.path}/$safe.$ext');
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFilex.open(file.path, type: mime);
  if (result.type != ResultType.done) {
    throw Exception(result.type == ResultType.noAppToOpen ? 'No app on this phone can open this file.' : 'Could not open the receipt.');
  }
}

/// The type of a downloaded receipt, from its first bytes.
String receiptMime(Uint8List bytes) {
  if (bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) return 'application/pdf';
  if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
  if (bytes.length > 12 && bytes[8] == 0x57 && bytes[9] == 0x45) return 'image/webp';
  return 'image/jpeg';
}
