import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/ocr_import/data/receipt_parser.dart';
import 'package:ispend/features/ocr_import/data/shopping_order_candidate.dart';

void main() {
  const parser = ReceiptParser();

  test('uses final payment, ignoring subtotal, tax, and cash change', () {
    final result = parser.parse(
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      input: [
        _line('Tealive', 10),
        _line('Date 2026-09-24 14:35', 30),
        _line('Subtotal RM 10.00', 90),
        _line('SST RM 0.60', 110),
        _line('Grand Total RM 10.60', 130),
        _line('Change RM 9.40', 160),
      ],
    );

    expect(result.amountCents, 1060);
    expect(result.merchant, 'Tealive');
    expect(result.occurredAt, DateTime(2026, 9, 24, 14, 35));
  });

  test('leaves conflicting final amounts and purchase dates for review', () {
    final result = parser.parse(
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      input: [
        _line('Shop', 10),
        _line('Date 2026-09-23', 30),
        _line('Date 2026-09-24', 50),
        _line('Grand Total RM 12.00', 90),
        _line('Grand Total RM 13.00', 110),
      ],
    );

    expect(result.amountCents, isNull);
    expect(result.amountNeedsReview, isTrue);
    expect(result.occurredAt, isNull);
    expect(result.dateNeedsReview, isTrue);
  });

  test('does not treat foreign amount or delivery date as purchase', () {
    final result = parser.parse(
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      input: [
        _line('Shop', 10),
        _line('Delivered 2026-09-24', 30),
        _line('Total USD 12.00', 90),
      ],
    );

    expect(result.amountCents, isNull);
    expect(result.occurredAt, isNull);
  });

  test('recognizes Chinese final payment and order date', () {
    final result = parser.parse(
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      input: [
        _line('茶饮店', 10),
        _line('订单日期 2026年9月24日', 30),
        _line('实付款 MYR 8.20', 90),
      ],
    );

    expect(result.amountCents, 820);
    expect(result.merchant, '茶饮店');
    expect(result.occurredAt, DateTime(2026, 9, 24, 12));
  });

  test('receipt picker maps a shopping order detail to the item title', () {
    final result = parser.parse(
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      input: [
        _line('个Oroder Details', 10),
        _line('Your Order is Completed', 60),
        _line('Parcel has been delivered', 190),
        _line('18-03-2026 19:50', 220),
        _line('Mall DOSEN Official Store >', 520),
        _line('DOSENro', 540),
        _line('DOSEN Retractable Car Charger 120W...', 560),
        _line('Order Total: RM21.87 v', 680),
        _line('Support Center', 760),
        _line('Request for Return/Refund', 790),
      ],
    );

    expect(result.merchant, 'DOSEN Retractable Car Charger 120W...');
    expect(result.amountCents, 2187);
    expect(result.occurredAt, isNull);
    expect(result.dateNeedsReview, isTrue);
  });

  test(
    'order detail keeps a readable total if OCR drops its currency marker',
    () {
      final result = parser.parse(
        currencyCode: 'MYR',
        currencySymbol: 'RM',
        input: [
          _line('个Oroder Details', 10),
          _line('Your Order is Completed', 60),
          _line('Mall DOSEN Official Store >', 520),
          _line('DOSEN Retractable Car Charger 120W...', 560),
          _line('Order Total: 21.87', 680),
          _line('Support Center', 760),
        ],
      );

      expect(result.merchant, 'DOSEN Retractable Car Charger 120W...');
      expect(result.amountCents, 2187);
      expect(result.occurredAt, isNull);
    },
  );

  test('receipt picker interprets Taobao paid MYR total and product title', () {
    final result = parser.parse(
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      input: [
        _line('交易成功', 10),
        _line('淘宝泡菜饭卖机', 100),
        _line('enhypen符娃朴成训西村力¥18.52', 120),
        _line('¥25.9', 140),
        _line('实付款MYRT2.33', 200),
        _line('成交时间', 260),
        _line('2025-07-17 16:58:53', 280),
        _line('付款时间', 300),
        _line('2025-05-26 23:51:07', 320),
      ],
    );

    expect(result.merchant, 'enhypen符娃朴成训西村力');
    expect(result.amountCents, 1233);
    expect(result.occurredAt, DateTime(2025, 5, 26, 23, 51));
    expect(result.amountNeedsReview, isFalse);
    expect(result.dateNeedsReview, isFalse);
  });

  test(
    'labeled paid amount recovers OCR T as a leading 1 without detail match',
    () {
      final result = parser.parse(
        currencyCode: 'MYR',
        currencySymbol: 'RM',
        input: [_line('Shop', 10), _line('实付款MYRT2.33', 30)],
      );

      expect(result.amountCents, 1233);
    },
  );

  test('MYR paid total is not misread as USD 2.33', () {
    final result = parser.parse(
      currencyCode: 'USD',
      currencySymbol: r'$',
      input: [
        _line('交易成功', 10),
        _line('淘宝泡菜饭卖机', 100),
        _line('enhypen符娃朴成训西村力¥18.52', 120),
        _line('实付款MYRT2.33', 200),
        _line('付款时间', 300),
        _line('2025-05-26 23:51:07', 320),
      ],
    );

    expect(result.amountCents, isNull);
    expect(result.foreignAmountReference, 'MYR12.33');
    expect(result.amountNeedsReview, isTrue);
  });
}

RecognizedOcrLine _line(String text, double top) =>
    RecognizedOcrLine(text: text, left: 0, top: top, width: 200, height: 14);
