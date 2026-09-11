import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ispend/app.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/data/recurring_expense_repository.dart';
import 'package:ispend/features/expenses/expense_providers.dart';

void main() {
  testWidgets('switches between the three primary tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.textContaining('('), findsOneWidget);

    await tester.tap(find.text('Summary').last);
    await tester.pumpAndSettle();
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('Category breakdown'), findsOneWidget);
    expect(find.text('Payment method breakdown'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Payment methods'), findsOneWidget);
  });

  testWidgets('saves a rounded expense with Food selected by default', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amountField')), '9.999');
    await tester.ensureVisible(find.byKey(const Key('saveExpenseButton')));
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dismissible),
        matching: find.textContaining('10.00'),
      ),
      findsOneWidget,
    );
    expect(find.text('Food'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('edits and deletes a saved expense', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountField')), '5.00');
    await tester.ensureVisible(find.byKey(const Key('saveExpenseButton')));
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amountField')), '12.50');
    await tester.ensureVisible(find.byKey(const Key('saveExpenseButton')));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Dismissible),
        matching: find.textContaining('12.50'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.drag(find.byType(Dismissible).first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete expense?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('manages an unused category from Settings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pets');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Pets'), findsOneWidget);

    await tester.tap(find.byTooltip('Category options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pets care');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Pets care'), findsOneWidget);

    await tester.tap(find.byTooltip('Category options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Pets care'), findsNothing);
  });

  testWidgets('sets a monthly category budget and shows it in Summary', (
    tester,
  ) async {
    final expenses = InMemoryExpenseRepository();
    final now = DateTime.now();
    await expenses.save(
      Expense(
        id: 'budget-food-expense',
        amountCents: 4000,
        category: 'Food',
        occurredAt: now,
        createdAt: now,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(expenses)],
        child: const ISpendApp(),
      ),
    );

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final budgetTile = find.widgetWithText(ListTile, 'Budget limits');
    await tester.ensureVisible(budgetTile);
    await tester.tap(budgetTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Save limit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('100.00'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Summary').last);
    await tester.pumpAndSettle();
    expect(find.text('Monthly budgets'), findsOneWidget);
    expect(find.textContaining('40.00 of'), findsOneWidget);
    expect(find.textContaining('60.00 remaining'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('blocks deleting a category used by an expense', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountField')), '5.00');
    await tester.ensureVisible(find.byKey(const Key('saveExpenseButton')));
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Category options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Category in use'), findsOneWidget);
    expect(find.textContaining('1 expense uses this category'), findsOneWidget);
  });

  testWidgets('blocks a duplicate payment method name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment methods'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add method'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cash');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('This payment method already exists.'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
  });

  testWidgets('blocks deleting a payment method used by an expense', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountField')), '5.00');
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveExpenseButton')));
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment methods'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Payment method in use'), findsOneWidget);
    expect(
      find.textContaining('1 expense uses this payment method'),
      findsOneWidget,
    );
  });

  testWidgets('collapses and expands the expense FAB while scrolling', (
    tester,
  ) async {
    final repository = InMemoryExpenseRepository();
    for (var index = 0; index < 20; index++) {
      await repository.save(
        Expense(
          id: 'expense-$index',
          amountCents: 100 + index,
          category: 'Food',
          occurredAt: DateTime(2026, 9, 10).subtract(Duration(days: index)),
          createdAt: DateTime(2026, 9, 10),
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repository)],
        child: const ISpendApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .isExtended,
      isTrue,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .isExtended,
      isFalse,
    );

    await tester.drag(find.byType(ListView), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .isExtended,
      isTrue,
    );
  });

  testWidgets('shows recurring membership and stops it with the expense', (
    tester,
  ) async {
    final expenseRepository = InMemoryExpenseRepository();
    final recurringRepository = InMemoryRecurringExpenseRepository(
      expenseRepository,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(expenseRepository),
          recurringExpenseRepositoryProvider.overrideWithValue(
            recurringRepository,
          ),
        ],
        child: const ISpendApp(),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountField')), '25.00');
    await tester.ensureVisible(find.text('More options'));
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Repeats monthly'));
    await tester.tap(find.text('Repeats monthly'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveExpenseButton')));
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    final savedSchedule = (await recurringRepository.getAll()).single;
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Part of recurring expense'));
    expect(find.text('Part of recurring expense'), findsOneWidget);
    expect(find.text('Repeats monthly'), findsNothing);
    expect(find.text('View recurring schedule >'), findsOneWidget);
    await tester.tap(find.text('View recurring schedule >'));
    await tester.pumpAndSettle();
    expect(find.text('Recurring expenses'), findsWidgets);
    expect(find.text('Edit schedule'), findsOneWidget);
    expect(find.text('Stop recurring'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(
      (await recurringRepository.getById(savedSchedule.id))!.isActive,
      isFalse,
    );
  });

  testWidgets('shows a synchronized recurring description everywhere', (
    tester,
  ) async {
    final expenseRepository = InMemoryExpenseRepository();
    final recurringRepository = InMemoryRecurringExpenseRepository(
      expenseRepository,
    );
    final august = DateTime(2026, 8, 10);
    final original = await recurringRepository.enableForExpense(
      Expense(
        id: 'series',
        amountCents: 2500,
        category: 'Food',
        merchantOrNote: 'Old description',
        paymentMethod: 'Cash',
        occurredAt: august,
        createdAt: august,
      ),
    );
    final schedule = (await recurringRepository.getAll()).single;
    await recurringRepository.confirm(
      schedule,
      Expense(
        id: 'september',
        amountCents: 2500,
        category: 'Food',
        merchantOrNote: 'Old description',
        paymentMethod: 'Cash',
        occurredAt: DateTime(2026, 9, 10),
        createdAt: DateTime(2026, 9, 10),
      ),
    );
    final september = (await expenseRepository.getAll()).singleWhere(
      (expense) => expense.id == 'september',
    );
    await recurringRepository.saveLinkedExpense(
      Expense(
        id: september.id,
        amountCents: september.amountCents,
        category: september.category,
        merchantOrNote: 'Updated description',
        paymentMethod: september.paymentMethod,
        occurredAt: september.occurredAt,
        createdAt: september.createdAt,
        recurringRuleId: september.recurringRuleId,
        recurringOccurrence: september.recurringOccurrence,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(expenseRepository),
          recurringExpenseRepositoryProvider.overrideWithValue(
            recurringRepository,
          ),
        ],
        child: const ISpendApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(original.recurringRuleId, 'series');
    expect(find.text('Updated description'), findsNWidgets(2));

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final recurringTile = find.widgetWithText(ListTile, 'Recurring expenses');
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(recurringTile);
    await tester.pumpAndSettle();

    expect(find.text('Updated description'), findsOneWidget);
  });
}
