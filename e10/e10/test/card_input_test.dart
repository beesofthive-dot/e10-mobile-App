import 'package:flutter_test/flutter_test.dart';

import 'package:e10/widgets/card_input.dart';

void main() {
  test('detects Visa and Mastercard from the first digits', () {
    expect(detectCardBrand('4'), CardBrand.visa);
    expect(detectCardBrand('4111 1111'), CardBrand.visa);
    expect(detectCardBrand('51'), CardBrand.mastercard);
    expect(detectCardBrand('5500 0000'), CardBrand.mastercard);
    expect(detectCardBrand('2221 00'), CardBrand.mastercard);
    expect(detectCardBrand('2720 99'), CardBrand.mastercard);
    expect(detectCardBrand('5'), isNull); // not enough digits yet
    expect(detectCardBrand('3782 822463'), isNull); // Amex: not accepted
    expect(detectCardBrand('6011 1111'), isNull); // Discover: not accepted
  });

  test('Luhn accepts real test numbers and rejects a typo', () {
    expect(luhnValid('4111 1111 1111 1111'), isTrue);
    expect(luhnValid('5555 5555 5555 4444'), isTrue);
    expect(luhnValid('4111 1111 1111 1112'), isFalse);
  });

  test('expiry must be MM/YY and not in the past', () {
    final now = DateTime(2026, 9, 28);
    expect(expiryError('09/26', now: now), isNull);
    expect(expiryError('12/30', now: now), isNull);
    expect(expiryError('08/26', now: now), 'This card has expired');
    expect(expiryError('13/27', now: now), 'Month must be 01–12');
    expect(expiryError('0927', now: now), 'Use MM/YY');
  });
}
