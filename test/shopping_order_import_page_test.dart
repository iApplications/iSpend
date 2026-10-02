import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/ocr_import/data/shopping_order_candidate.dart';
import 'package:ispend/features/ocr_import/presentation/shopping_order_import_page.dart';
import 'package:ispend/features/settings/currency_preference.dart';
import 'package:ispend/core/utils/amount_formatter.dart';

void main() {
  testWidgets('batch review opens with candidates handed off by receipt scan', (
    tester,
  ) async {
    final candidates = [
      _candidate(0, '伤口愈合中', '¥34.29'),
      _candidate(1, 'enhypen符娃朴成训西村力梁祯', '¥21'),
      _candidate(2, '适用三星s25ultra磁吸', null),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ShoppingOrderImportPage(
            initialImagePath: 'test-image.jpg',
            initialCandidates: candidates,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import shopping orders'), findsOneWidget);
    expect(find.text('3 orders found'), findsOneWidget);
    expect(find.text('伤口愈合中'), findsWidgets);
    expect(find.textContaining('Detected ¥34.29'), findsOneWidget);
    expect(find.text('Add selected (0)'), findsOneWidget);
  });

  testWidgets(
    'scanned foreign amount is opt-in and can return to manual entry',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupAppCurrencyProvider.overrideWithValue(
              AppCurrency.fromCode('USD'),
            ),
          ],
          child: MaterialApp(
            home: ShoppingOrderImportPage(
              initialImagePath: 'test-image.jpg',
              initialCandidates: [
                ShoppingOrderCandidate(
                  id: 'test-image.jpg#0',
                  sourceImagePath: 'test-image.jpg',
                  rawText: 'Paid ¥34.29',
                  status: ShoppingOrderStatus.paid,
                  platform: ShoppingPlatform.taobao,
                  merchant: 'Book',
                  foreignAmountReference: '¥34.29',
                  occurredAt: DateTime(2026, 9, 20),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final amountField = find.widgetWithText(TextField, 'Amount (USD)');
      final scannedOption = find.widgetWithText(
        CheckboxListTile,
        'Use scanned amount',
      );
      expect(tester.widget<TextField>(amountField).controller!.text, isEmpty);
      expect(tester.widget<CheckboxListTile>(scannedOption).value, isFalse);
      expect(find.text('Add selected (0)'), findsOneWidget);

      await tester.ensureVisible(scannedOption);
      await tester.tap(scannedOption);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(amountField).controller!.text, '34.29');
      expect(tester.widget<CheckboxListTile>(scannedOption).value, isTrue);
      expect(
        find.textContaining('as USD 34.29. No conversion.'),
        findsOneWidget,
      );

      await tester.tap(scannedOption);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(amountField).controller!.text, isEmpty);
      expect(tester.widget<CheckboxListTile>(scannedOption).value, isFalse);

      await tester.ensureVisible(amountField);
      await tester.enterText(amountField, '7.50');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(amountField).controller!.text, '7.50');
      expect(tester.widget<CheckboxListTile>(scannedOption).value, isFalse);
    },
  );
}

ShoppingOrderCandidate _candidate(int index, String item, String? paid) =>
    ShoppingOrderCandidate(
      id: 'test-image.jpg#$index',
      sourceImagePath: 'test-image.jpg',
      rawText: '$item\n交易成功\n${paid == null ? '' : '实付款 $paid'}',
      status: ShoppingOrderStatus.paid,
      platform: ShoppingPlatform.taobao,
      merchant: item,
      foreignAmountReference: paid,
    );
