import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Opens a receipt (PDF, or a photo when [mime] says so) in a new browser
/// tab (download if pop-ups are blocked).
Future<void> openPdfBytes(Uint8List bytes, String name, {String mime = 'application/pdf'}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final tab = web.window.open(url, '_blank');
  if (tab == null) {
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = '$name.${mime == 'application/pdf' ? 'pdf' : mime.split('/').last}';
    a.click();
  }
  Future.delayed(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}

/// The type of a downloaded receipt, from its first bytes.
String receiptMime(Uint8List bytes) {
  if (bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) return 'application/pdf';
  if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
  if (bytes.length > 12 && bytes[8] == 0x57 && bytes[9] == 0x45) return 'image/webp';
  return 'image/jpeg';
}
