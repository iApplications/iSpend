import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/expense_model.dart';
import 'data/expense_repository.dart';
import 'data/recurring_expense.dart';
import 'data/recurring_expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (_) => InMemoryExpenseRepository(),
);

final expenseImageProvider = FutureProvider.family<Uint8List?, String>(
  (ref, expenseId) =>
      ref.watch(expenseRepositoryProvider).imageForExpense(expenseId),
);

final expenseImageIdsProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(expenseRepositoryProvider).expenseIdsWithImages(),
);

final imageStorageBytesProvider = FutureProvider<int>(
  (ref) => ref.watch(expenseRepositoryProvider).imageStorageBytes(),
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

  Future<void> addAll(
    List<Expense> expenses, {
    List<ExpenseImageAttachment> attachments = const [],
  }) async {
    if (expenses.isEmpty) return;
    await _repository.saveAll(expenses, attachments: attachments);
    await _load();
    ref.invalidate(imageStorageBytesProvider);
    ref.invalidate(expenseImageIdsProvider);
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await _load();
    ref.invalidate(expenseImageProvider(id));
    ref.invalidate(imageStorageBytesProvider);
    ref.invalidate(expenseImageIdsProvider);
  }

  Future<void> removeImage(String expenseId) async {
    await _repository.removeImageForExpense(expenseId);
    ref.invalidate(expenseImageProvider(expenseId));
    ref.invalidate(expenseImageIdsProvider);
    ref.invalidate(imageStorageBytesProvider);
  }
}
