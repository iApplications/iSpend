import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/ocr_import/data/shopping_order_candidate.dart';
import 'package:ispend/features/ocr_import/data/shopping_order_parser.dart';

void main() {
  const parser = ShoppingOrderParser();

  test('extracts a paid order with an explicitly labeled payment date', () {
    final candidates = parser.parseImage(
      imagePath: 'orders-a.png',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('Tealive', 10),
        _line('Order date: 2026-08-28', 32),
        _line('Order Total RM 12.33', 54),
        _line('Paid', 76),
      ],
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.merchant, 'Tealive');
    expect(candidates.single.amountCents, 1233);
    expect(candidates.single.occurredAt, DateTime(2026, 8, 28));
    expect(candidates.single.status, ShoppingOrderStatus.paid);
    expect(candidates.single.canImportByDefault, isTrue);
  });

  test('uses the final-payment amount, not subtotal or promotional price', () {
    final candidates = parser.parseImage(
      imagePath: 'orders-a.png',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('Shopee order', 10),
        _line('Subtotal RM 99.00', 32),
        _line('Buy Again RM 88.00', 54),
        _line('Total Payment', 76),
        _line('MYR 12.33', 98),
        _line('Paid', 120),
      ],
    );

    expect(candidates.single.amountCents, 1233);
  });

  test('does not substitute delivery date or assume foreign currency', () {
    final candidates = parser.parseImage(
      imagePath: 'orders-a.png',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('Shop', 10),
        _line('Delivered 2026-08-28', 32),
        _line('Order Total USD 12.33', 54),
        _line('Completed', 76),
      ],
    );

    expect(candidates.single.occurredAt, isNull);
    expect(candidates.single.amountCents, isNull);
    expect(candidates.single.foreignAmountReference, 'USD 12.33');
    expect(candidates.single.canImportByDefault, isFalse);
  });

  test('shows a foreign currency symbol as a reference only', () {
    final candidates = parser.parseImage(
      imagePath: 'orders-a.png',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('Shop', 10),
        _line('Order date: 2026-08-28', 32),
        _line(r'Order Total $12.33', 54),
        _line('Paid', 76),
      ],
    );

    expect(candidates.single.amountCents, isNull);
    expect(candidates.single.foreignAmountReference, r'$12.33');
  });

  test('records source platform from the screenshot header', () {
    final candidates = parser.parseImage(
      imagePath: 'orders-a.png',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('Shopee', 10),
        _line('Tea shop', 150),
        _line('Order date: 2026-08-28', 172),
        _line('Total Payment RM 8.20', 194),
        _line('Paid', 216),
      ],
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.platform, ShoppingPlatform.shopee);
  });

  test('Shopee purchase list separates stores and keeps each paid total', () {
    final candidates = parser.parseImage(
      imagePath: 'shopee-purchases.jpg',
      currencyCode: 'USD',
      currencySymbol: r'$',
      lines: [
        _line('My Purchases', 10),
        _line('To Ship', 40),
        _line('To Receive', 40),
        _line('Completed', 40),
        _line('Return/Refund', 40),
        _line('Mall DOSEN Official Store', 100),
        _line('Completed', 101),
        _line('DOSEN Retractable Car Charger 120W...', 125),
        _line('RM52.50 RM32.31', 180),
        _line('Total 1 item: RM21.87', 200),
        _line('Buy Again', 225),
        _line('Mall Trapo Malaysia Official Store', 260),
        _line('Completed', 261),
        _line('Trapo Shineguard Car Coating (Car Co...', 285),
        _line('RM29.90', 335),
        _line('Total 1 item: RM23.78', 355),
        _line('Buy Again', 380),
        _line('Mall JisuLife Official Shop', 415),
        _line('Completed', 416),
        _line('JisuLife Handheld Fan Life10/10S', 440),
        _line('RM229.00 RM94.90', 490),
        _line('Total 1 item: RM91.87', 510),
        _line('Completed', 550),
        _line('PASSAY', 551),
      ],
    );

    expect(candidates, hasLength(3));
    expect(
      candidates.every((row) => row.platform == ShoppingPlatform.shopee),
      isTrue,
    );
    expect(candidates.map((row) => row.merchant), [
      'DOSEN Retractable Car Charger 120W...',
      'Trapo Shineguard Car Coating (Car Co...',
      'JisuLife Handheld Fan Life10/10S',
    ]);
    expect(candidates.map((row) => row.foreignAmountReference), [
      'RM21.87',
      'RM23.78',
      'RM91.87',
    ]);
    expect(candidates.every((row) => row.amountCents == null), isTrue);
    expect(candidates.every((row) => row.occurredAt == null), isTrue);
    expect(
      candidates.every((row) => row.status == ShoppingOrderStatus.paid),
      isTrue,
    );
    expect(candidates.any((row) => row.rawText.contains('PASSAY')), isFalse);
  });

  test('Shopee total line with unreadable amount remains reviewable', () {
    final candidates = parser.parseImage(
      imagePath: 'shopee-blurry.jpg',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('My Purchases', 10),
        _line('Mall Tea Shop', 100),
        _line('Completed', 101),
        _line('Tea', 125),
        _line('Total 1 item: unreadable', 200),
      ],
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.amountCents, isNull);
    expect(candidates.single.foreignAmountReference, isNull);
  });

  test('Shopee screenshot with only a cropped shop has no import rows', () {
    final candidates = parser.parseImage(
      imagePath: 'shopee-cropped.jpg',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('My Purchases', 10),
        _line('Completed', 100),
        _line('PASSAY', 101),
      ],
    );

    expect(candidates, isEmpty);
  });

  test('marks refunded, cancelled, and ambiguous rows for review', () {
    final candidates = parser.parseImage(
      imagePath: 'orders-a.png',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('Shop One', 10),
        _line('Order date: 2026-08-28', 32),
        _line('Order Total RM 12.00', 54),
        _line('Refunded', 76),
        _line('Shop Two', 200),
        _line('Order date: 2026-08-29', 222),
        _line('Order Total RM 8.00', 244),
        _line('Cancelled', 266),
        _line('Shop Three', 400),
        _line('Order date: 2026-08-30', 422),
        _line('Order Total RM 9.00', 444),
      ],
    );

    expect(candidates, hasLength(3));
    expect(candidates[0].status, ShoppingOrderStatus.refunded);
    expect(candidates[1].status, ShoppingOrderStatus.cancelled);
    expect(candidates[2].status, ShoppingOrderStatus.needsReview);
    expect(
      candidates.every((candidate) => !candidate.canImportByDefault),
      isTrue,
    );
    expect(hasMultipleTaobaoOrderCards(candidates), isFalse);
  });

  test('deduplicates identical overlap rows across images only', () {
    final first = _candidate('orders-a.png', 'Order 12345\nPaid RM 12.00');
    final overlap = _candidate('orders-b.png', 'Order 12345\nPaid RM 12.00');
    final separate = _candidate('orders-a.png', 'Order 67890\nPaid RM 12.00');

    final unique = parser.deduplicateOverlappingScreenshots([
      first,
      overlap,
      separate,
    ]);

    expect(unique, [first, separate]);
  });

  test('order-detail screenshot fills item and total, not delivery time', () {
    final candidates = parser.parseImage(
      imagePath: 'shopee-detail.jpg',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('个Oroder Details', 10),
        _line('Your Order is Completed', 60),
        _line('Shipping Information', 130),
        _line('Parcel has been delivered', 190),
        _line('18-03-2026 19:50', 220),
        _line('Delivery Information', 320),
        _line('Recipient and delivery address', 360),
        _line('Mall DOSEN Official Store >', 520),
        _line('DOSENro', 540),
        _line('DOSEN Retractable Car Charger 120W...', 560),
        _line('D5-120W', 590),
        _line('RM52.5O RM32.31', 620),
        _line('Order Total: RM21.87 v', 680),
        _line('Support Center', 760),
        _line('Request for Return/Refund', 790),
        _line('Buy Again', 860),
      ],
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.merchant, 'DOSEN Retractable Car Charger 120W...');
    expect(candidates.single.amountCents, 2187);
    expect(candidates.single.status, ShoppingOrderStatus.paid);
    expect(candidates.single.occurredAt, isNull);
    expect(candidates.single.canImportByDefault, isFalse);
  });

  test('store and item identify one detail order when OCR misses headings', () {
    final candidates = parser.parseImage(
      imagePath: 'shopee-detail-blurry.jpg',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('个Oroder Details', 10),
        _line('Your Order is Completed', 60),
        _line('Mall DOSEN Official Store >', 520),
        _line('DOSENro', 540),
        _line('DOSEN Retractable Car Charger 120W...', 560),
        _line('D5-120W', 590),
        _line('Order Total: RM21.87 v', 680),
      ],
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.merchant, 'DOSEN Retractable Car Charger 120W...');
    expect(candidates.single.amountCents, 2187);
  });

  test(
    'Taobao detail uses MYR paid total and payment time, not CNY item price',
    () {
      final candidates = parser.parseImage(
        imagePath: 'taobao-detail.jpg',
        currencyCode: 'MYR',
        currencySymbol: 'RM',
        lines: [
          _line('交易成功', 10),
          _line('淘宝泡菜饭卖机', 100),
          _line('enhypen符娃朴成训西村力¥18.52', 120),
          _line('JUNGWON梁祐元', 140),
          _line('¥25.9', 160),
          _line('实付款MYRT2.33', 200),
          _line('成交时间', 260),
          _line('2025-07-17 16:58:53', 280),
          _line('付款时间', 300),
          _line('2025-05-26 23:51:07', 320),
          _line('创建时间', 340),
          _line('2025-05-26 23:50:30', 360),
        ],
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.platform, ShoppingPlatform.taobao);
      expect(candidates.single.merchant, 'enhypen符娃朴成训西村力');
      expect(candidates.single.amountCents, 1233);
      expect(candidates.single.occurredAt, DateTime(2025, 5, 26, 23, 51));
      expect(candidates.single.status, ShoppingOrderStatus.paid);
    },
  );

  test('Taobao MYR total is foreign when the app is locked to USD', () {
    final candidate = parser
        .parseImage(
          imagePath: 'taobao-detail.jpg',
          currencyCode: 'USD',
          currencySymbol: r'$',
          lines: [
            _line('交易成功', 10),
            _line('淘宝泡菜饭卖机', 100),
            _line('enhypen符娃朴成训西村力¥18.52', 120),
            _line('实付款MYRT2.33', 200),
            _line('付款时间', 300),
            _line('2025-05-26 23:51:07', 320),
          ],
        )
        .single;

    expect(candidate.amountCents, isNull);
    expect(candidate.foreignAmountReference, 'MYR12.33');
    expect(candidate.canImportByDefault, isFalse);
  });

  test('Taobao order list yields one review row per visible order card', () {
    final candidates = parser.parseImage(
      imagePath: 'taobao-list.jpg',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('搜索订单', 10),
        _line('全部订单 购物 闪购', 35),
        _line('天猫 博库旗舰店 交易成功', 100),
        _line('【2024年诺贝尔文学奖得主韩江 ¥27.83', 130),
        _line('伤口愈合中', 150),
        _line('1件赠品', 180),
        _line('含官方直邮服务 实付款 ¥34.29', 240),
        _line('淘宝 泡菜饭卖机 交易成功', 350),
        _line('enhypen符娃朴成训西村力梁祯 ¥18.52', 380),
        _line('JUNGWON梁祐元', 400),
        _line('1件赠品', 430),
        _line('实付款 ¥21', 480),
        _line('天猫 南荔旗舰店 交易成功', 590),
        _line('【活动价】适用三星 s25ultra 磁吸 ¥33.3', 620),
      ],
    );

    expect(candidates, hasLength(3));
    expect(
      candidates.every(
        (candidate) => candidate.platform == ShoppingPlatform.taobao,
      ),
      isTrue,
    );
    expect(candidates[0].merchant, '伤口愈合中');
    expect(candidates[0].foreignAmountReference, '¥34.29');
    expect(candidates[0].amountCents, isNull);
    expect(candidates[0].occurredAt, isNull);
    expect(candidates[1].merchant, 'enhypen符娃朴成训西村力梁祯');
    expect(candidates[1].foreignAmountReference, '¥21');
    expect(candidates[2].merchant, '【活动价】适用三星 s25ultra 磁吸');
    expect(candidates[2].foreignAmountReference, isNull);
    expect(
      candidates.every((candidate) => !candidate.canImportByDefault),
      isTrue,
    );
  });

  test('list card keeps status when OCR puts it just before the shop name', () {
    final candidates = parser.parseImage(
      imagePath: 'taobao-list.jpg',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      lines: [
        _line('交易成功', 99),
        _line('天猫 博库旗舰店', 100),
        _line('伤口愈合中 ¥27.83', 130),
        _line('实付款 MYR 34.29', 200),
      ],
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.merchant, '伤口愈合中');
    expect(candidates.single.amountCents, 3429);
    expect(candidates.single.status, ShoppingOrderStatus.paid);
    expect(candidates.single.occurredAt, isNull);
    expect(hasMultipleTaobaoOrderCards(candidates), isFalse);
  });

  test('actual Taobao OCR tolerates a misread first shop header', () {
    final candidates = parser.parseImage(
      imagePath: 'taobao-list-ocr.jpg',
      currencyCode: 'USD',
      currencySymbol: r'$',
      lines: [
        _line('I令92', 10),
        _line('个Q搜索订单', 30),
        _line('天道傅库旗舰店 >', 100),
        _line('交易成功', 115),
        _line('【2024年诺贝尔文学奖得主韩江 ¥27.83', 140),
        _line('h1愈合', 155),
        _line('正版店铺', 170),
        _line('伤口愈合中', 185),
        _line('x1', 200),
        _line('含官方直邮服务实付款 ¥34.29', 260),
        _line('淘宝泡菜饭卖机>', 350),
        _line('交易成功', 365),
        _line('enhypen符娃朴成训西村力梁祯¥18.52', 390),
        _line('JUNGWON梁祐元', 410),
        _line('x1', 425),
        _line('含官方直邮服务实付款 ¥21', 470),
        _line('天猫南荔旗舰店>', 560),
        _line('交·顶部', 575),
        _line('【活动价】适用三星s25ultra磁吸¥33.3', 600),
      ],
    );

    expect(candidates, hasLength(3));
    expect(hasMultipleTaobaoOrderCards(candidates), isTrue);
    expect(candidates[0].merchant, '伤口愈合中');
    expect(candidates[0].foreignAmountReference, '¥34.29');
    expect(candidates[1].merchant, 'enhypen符娃朴成训西村力梁祯');
    expect(candidates[1].foreignAmountReference, '¥21');
    expect(candidates[2].merchant, '【活动价】适用三星s25ultra磁吸');
    expect(candidates[2].amountCents, isNull);
  });
}

RecognizedOcrLine _line(String text, double top) =>
    RecognizedOcrLine(text: text, left: 0, top: top, width: 220, height: 14);

ShoppingOrderCandidate _candidate(String imagePath, String rawText) =>
    ShoppingOrderCandidate(
      id: '$imagePath#0',
      sourceImagePath: imagePath,
      rawText: rawText,
      status: ShoppingOrderStatus.needsReview,
    );
