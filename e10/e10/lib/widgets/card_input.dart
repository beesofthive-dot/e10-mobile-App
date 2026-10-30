import 'package:flutter/services.dart';

/// Card brands the school accepts.
enum CardBrand { visa, mastercard }

extension CardBrandLabel on CardBrand {
  String get label => this == CardBrand.visa ? 'Visa' : 'Mastercard';
}

/// Visa starts with 4; Mastercard with 51–55 or 2221–2720. Null until
/// enough digits are typed to tell (or for any other brand).
CardBrand? detectCardBrand(String input) {
  final d = input.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('4')) return CardBrand.visa;
  if (d.length >= 2) {
    final two = int.parse(d.substring(0, 2));
    if (two >= 51 && two <= 55) return CardBrand.mastercard;
  }
  if (d.length >= 4) {
    final four = int.parse(d.substring(0, 4));
    if (four >= 2221 && four <= 2720) return CardBrand.mastercard;
  }
  return null;
}

/// Standard Luhn checksum every real card number passes.
bool luhnValid(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 13) return false;
  var sum = 0;
  var alt = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var n = int.parse(digits[i]);
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 == 0;
}

/// Error for an `MM/YY` expiry, or null when it's valid and not in the past.
String? expiryError(String input, {DateTime? now}) {
  final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(input.trim());
  if (m == null) return 'Use MM/YY';
  final month = int.parse(m.group(1)!);
  final year = 2000 + int.parse(m.group(2)!);
  if (month < 1 || month > 12) return 'Month must be 01–12';
  final today = now ?? DateTime.now();
  if (year < today.year || (year == today.year && month < today.month)) return 'This card has expired';
  return null;
}

/// Groups digits as `1234 5678 9012 3456` while typing (max 16).
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(capped[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Types `MM/YY`, adding the slash automatically.
class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = capped.length > 2 ? '${capped.substring(0, 2)}/${capped.substring(2)}' : capped;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
