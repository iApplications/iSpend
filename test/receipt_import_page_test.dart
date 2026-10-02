import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/utils/amount_formatter.dart';
import 'package:ispend/features/ocr_import/data/receipt_parser.dart';
import 'package:ispend/features/ocr_import/presentation/receipt_import_page.dart';
import 'package:ispend/features/settings/currency_preference.dart';

void main() {
  testWidgets('foreign receipt amount is copied only when opted in', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupAppCurrencyProvider.overrideWithValue(
            AppCurrency.fromCode('USD'),
          ),
        ],
        child: const MaterialApp(
          home: ReceiptImportPage(
            initialSuggestion: ReceiptSuggestion(
              rawText: 'Amount paid MYR12.33',
              foreignAmountReference: 'MYR12.33',
              merchant: 'Shop',
            ),
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

    await tester.ensureVisible(scannedOption);
    await tester.tap(scannedOption);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amountField).controller!.text, '12.33');
    expect(tester.widget<CheckboxListTile>(scannedOption).value, isTrue);
    expect(find.textContaining('as USD 12.33. No conversion.'), findsOneWidget);

    await tester.tap(scannedOption);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amountField).controller!.text, isEmpty);

    await tester.ensureVisible(amountField);
    await tester.enterText(amountField, '8.20');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amountField).controller!.text, '8.20');
    expect(tester.widget<CheckboxListTile>(scannedOption).value, isFalse);
  });
}
