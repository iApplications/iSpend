import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/expense_providers.dart';
import 'package:ispend/features/summary/presentation/summary_page.dart';

Expense _e(String id, int cents, DateTime at, {String category = 'Food'}) =>
    Expense(
      id: id,
      amountCents: cents,
      category: category,
      occurredAt: at,
      createdAt: at,
    );

Future<void> _pump(WidgetTester tester, InMemoryExpenseRepository repo) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: SummaryPage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('total card shows the end date and expense count', (
    tester,
  ) async {
    final now = DateTime.now();
    final repo = InMemoryExpenseRepository();
    await repo.save(_e('a', 1000, now));
    await repo.save(_e('b', 1000, now));
    await _pump(tester, repo);

    expect(find.textContaining('Ending '), findsOneWidget);
    expect(find.textContaining('2 expenses'), findsOneWidget);
    expect(find.text('Period ending'), findsNothing);
  });

  testWidgets('compares with the previous 30 days using an arrow and sign', (
    tester,
  ) async {
    final now = DateTime.now();
    final repo = InMemoryExpenseRepository();
    await repo.save(_e('now', 5000, now));
    await repo.save(_e('then', 2000, now.subtract(const Duration(days: 40))));
    await _pump(tester, repo);

    expect(find.textContaining('▲ +'), findsOneWidget);
    expect(find.textContaining('vs previous 30 days'), findsOneWidget);
  });

  testWidgets('says so when there is nothing to compare with', (tester) async {
    final repo = InMemoryExpenseRepository();
    await repo.save(_e('now', 5000, DateTime.now()));
    await _pump(tester, repo);

    expect(find.textContaining('to compare with'), findsOneWidget);
  });

  testWidgets('quick-link tiles and section labels are present', (
    tester,
  ) async {
    final repo = InMemoryExpenseRepository();
    await repo.save(_e('now', 5000, DateTime.now()));
    await _pump(tester, repo);

    expect(find.text('Tax-deductible'), findsOneWidget);
    expect(find.text('Monthly report'), findsOneWidget);
    expect(find.text('WHERE IT WENT'), findsOneWidget);
    expect(find.text('Category breakdown'), findsOneWidget);
    expect(find.text('Payment method breakdown'), findsOneWidget);
  });
}
