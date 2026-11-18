import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/expense_providers.dart';
import 'package:ispend/features/summary/presentation/summary_page.dart';

void main() {
  testWidgets('shows the period end date and expense count in the total card', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2200);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final repo = InMemoryExpenseRepository();
    for (final id in ['a', 'b']) {
      await repo.save(
        Expense(
          id: id,
          amountCents: 1000,
          category: 'Food',
          occurredAt: now,
          createdAt: now,
        ),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: SummaryPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ending '), findsOneWidget);
    expect(find.textContaining('2 expenses'), findsOneWidget);
    // The two link rows are grouped into one card.
    expect(find.text('Tax-deductible expenses'), findsOneWidget);
    expect(find.text('Monthly report'), findsOneWidget);
    expect(find.text('Period ending'), findsNothing);
  });
}
