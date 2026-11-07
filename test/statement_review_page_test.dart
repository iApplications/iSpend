import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/utils/amount_formatter.dart';
import 'package:ispend/features/settings/currency_preference.dart';
import 'package:ispend/features/statement_import/data/statement_row.dart';
import 'package:ispend/features/statement_import/presentation/statement_review_page.dart';

void main() {
  testWidgets('shows parsed statement rows and the printed-total warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupAppCurrencyProvider.overrideWithValue(
            AppCurrency.fromCode('MYR'),
          ),
        ],
        child: MaterialApp(
          home: StatementReviewPage(
            sourceLabel: 'HSBC',
            notice: 'Parsed spending does not match the statement total.',
            parsedRows: [
              StatementRow(
                line: 1,
                description: 'Lunch',
                date: DateTime(2026, 10, 1, 12),
                amountCents: 1250,
                reason: null,
                selected: true,
              ),
              StatementRow(
                line: 2,
                description: 'Payment',
                date: DateTime(2026, 10, 2, 12),
                amountCents: 5000,
                reason: 'Credit, payment, or refund — review before adding',
                selected: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import HSBC statement'), findsOneWidget);
    expect(find.textContaining('does not match'), findsOneWidget);
    expect(find.text('2 transactions · 1 selected'), findsOneWidget);
    expect(find.text('Add selected (1)'), findsOneWidget);
  });
}
