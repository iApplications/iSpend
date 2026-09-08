import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/expense_model.dart';
import 'data/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (_) => InMemoryExpenseRepository(),
);

final expensesProvider = NotifierProvider<ExpensesNotifier, List<Expense>>(
  ExpensesNotifier.new,
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

  Future<void> add(Expense expense) async {
    await _repository.save(expense);
    await _load();
  }
}
