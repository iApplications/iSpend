import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/app.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/expense_providers.dart';

void main() {
  testWidgets('Settings shows the grouped sections and row values', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            InMemoryExpenseRepository(),
          ),
        ],
        child: const ISpendApp(),
      ),
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    // Profile card: no name yet, so it invites one; the old Currency row is
    // folded into it.
    expect(find.text('Add your name'), findsOneWidget);
    expect(find.textContaining('locked'), findsOneWidget);

    for (final label in const [
      'LOOK AND FEEL',
      'ORGANISE',
      'MONEY',
      'FAST ENTRY',
      'SECURITY',
      'YOUR DATA',
      'HELP',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200);
      expect(find.text(label), findsOneWidget);
    }

    // Budgets show their state on the row instead of a description.
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Budget limits'),
      -200,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Budget limits'),
        matching: find.text('None'),
      ),
      findsOneWidget,
    );

    // Quick logging explains why it is unavailable while App lock is off.
    await tester.scrollUntilVisible(find.text('Turn on App lock first.'), 200);
    expect(find.text('Turn on App lock first.'), findsOneWidget);
  });
}
