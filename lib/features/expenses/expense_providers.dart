import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/expense_model.dart';
import 'data/expense_repository.dart';
import 'data/recurring_expense.dart';
import 'data/recurring_expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (_) => InMemoryExpenseRepository(),
);

final expensesProvider = NotifierProvider<ExpensesNotifier, List<Expense>>(
  ExpensesNotifier.new,
);

final recurringExpenseRepositoryProvider = Provider<RecurringExpenseRepository>(
  (ref) =>
      InMemoryRecurringExpenseRepository(ref.watch(expenseRepositoryProvider)),
);

final dueRecurringExpensesProvider = FutureProvider<List<RecurringExpense>>(
  (ref) => ref
      .watch(recurringExpenseRepositoryProvider)
      .dueOnOrBefore(DateTime.now()),
);

final recurringExpensesProvider = FutureProvider<List<RecurringExpense>>(
  (ref) => ref.watch(recurringExpenseRepositoryProvider).getAll(),
);

class ExpensesNotifier extends Notifier<List<Expense>> {
  late final ExpenseRepository _repository;

  @override
  List<Expense> build() {
    _repository = ref.watch(expenseRepositoryProvider);
    Future<void>.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    state = await _repository.getAll();
  }

  Future<void> refresh() => _load();

  Future<void> add(Expense expense) async {
    await _repository.save(expense);
    await _load();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await _load();
  }
}
