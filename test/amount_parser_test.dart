import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/utils/amount_parser.dart';

void main() {
  test('parses exact two-decimal amounts as cents', () {
    expect(parseAmountToCents('9.99'), 999);
  });

  test('rounds additional decimal places using standard rounding', () {
    expect(parseAmountToCents('9.999'), 1000);
    expect(parseAmountToCents('9.994'), 999);
  });

  test('rejects invalid and negative amounts', () {
    expect(parseAmountToCents(''), isNull);
    expect(parseAmountToCents('-5'), isNull);
    expect(parseAmountToCents('abc'), isNull);
  });
}
