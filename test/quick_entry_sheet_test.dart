import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/utils/amount_formatter.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/quick_entry/presentation/quick_entry_sheet.dart';

void main() {
  testWidgets('typing more in the smart input keeps fields set by hand', (
    tester,
  ) async {
    Expense? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showQuickEntrySheet(
                  context,
                  categories: const ['Food', 'Transport', 'Other'],
                  paymentMethods: const ['Cash', 'TNG eWallet'],
                  history: const [],
                  currency: const AppCurrency(code: 'MYR', symbol: 'RM'),
                  categoryNamesById: const {},
                  paymentMethodNamesById: const {},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '5');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'My note');
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash'));
    await tester.pump();

    // The user keeps typing in the smart input; their own choices stay.
    await tester.enterText(find.byType(TextField).first, '5.50');
    await tester.pump();

    final merchant = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(merchant.controller!.text, 'My note');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.amountCents, 550);
    expect(saved!.category, 'Transport');
    expect(saved!.paymentMethod, 'Cash');
    expect(saved!.merchantOrNote, 'My note');
  });
}
