import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:ispend/core/utils/amount_formatter.dart';
import 'package:ispend/core/utils/yen.dart';
import 'package:ispend/features/ocr_import/data/paid_amount_ocr.dart';

void main() {
  test('reads a yen sign from Chinese or Japanese context', () {
    expect(yenKindOf('实付款 ¥34.29'), YenKind.cny);
    expect(yenKindOf('¥1,200 税込'), YenKind.jpy);
    expect(yenKindOf('Total ¥500'), YenKind.unknown);
    expect(yenKindOf('RMB 20'), YenKind.cny);
  });

  test('a yen sign matches only the app yen currency it could mean', () {
    expect(yenMatchesCurrency('实付款 ¥34.29', 'JPY'), isFalse);
    expect(yenMatchesCurrency('实付款 ¥34.29', 'CNY'), isTrue);
    expect(yenMatchesCurrency('¥1,200 税込', 'CNY'), isFalse);
    expect(yenMatchesCurrency('Total ¥500', 'JPY'), isTrue);
    expect(yenMatchesCurrency('Total ¥500', 'MYR'), isFalse);
  });

  test('a Chinese yen paid total is foreign when the app is in JPY', () {
    expect(foreignPaidAmountReference('实付款 ¥34.29', 'JPY', '¥'), '¥34.29');
    expect(foreignPaidAmountReference('Total ¥500', 'JPY', '¥'), isNull);
    expect(foreignPaidAmountReference('实付款 ¥34.29', 'CNY', '¥'), isNull);
  });

  test('CNY is a supported app currency', () {
    expect(AppCurrency.fromCode('CNY').code, 'CNY');
    expect(AppCurrency.fromLocale(const Locale('zh', 'CN')).code, 'CNY');
  });
}
