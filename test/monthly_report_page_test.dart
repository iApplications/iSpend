import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/expense_providers.dart';
import 'package:ispend/features/reports/presentation/monthly_report_page.dart';

Expense _e(String id, String category, int cents, DateTime at) => Expense(
  id: id,
  amountCents: cents,
  category: category,
  occurredAt: at,
  createdAt: at,
);

void main() {
  testWidgets('shows the total, change arrows and category shares', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1800);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 5, 12);
    final repo = InMemoryExpenseRepository();
    await repo.save(_e('a', 'Food', 6000, DateTime(now.year, now.month, 1, 9)));
    await repo.save(
      _e('b', 'Transport', 2000, DateTime(now.year, now.month, 1, 10)),
    );
    await repo.save(_e('c', 'Food', 4000, lastMonth));
    await repo.save(_e('d', 'Transport', 3000, lastMonth));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: MonthlyReportPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total spent'), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    // Food rose and Transport fell: arrows carry the direction, not colour.
    expect(find.textContaining('▲'), findsWidgets);
    expect(find.textContaining('▼'), findsWidgets);
    expect(find.text('75%'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);
  });

  testWidgets('shows an empty message for a month without expenses', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            InMemoryExpenseRepository(),
          ),
        ],
        child: const MaterialApp(home: MonthlyReportPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No expenses in'), findsOneWidget);
  });
}
