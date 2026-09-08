import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/expense_model.dart';

final expensesProvider = NotifierProvider<ExpensesNotifier, List<Expense>>(
  ExpensesNotifier.new,
);

class ExpensesNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() => const [];

  void add(Expense expense) {
    state = [...state, expense]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
  }
}
