import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/payment_method_repository.dart';
import '../expenses/data/expense_repository.dart';
import '../expenses/expense_providers.dart';

final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>(
  (_) => InMemoryPaymentMethodRepository(),
);

final paymentMethodsProvider =
    NotifierProvider<PaymentMethodsNotifier, List<String>>(
      PaymentMethodsNotifier.new,
    );

class PaymentMethodsNotifier extends Notifier<List<String>> {
  late final PaymentMethodRepository _repository;
  late final ExpenseRepository _expenses;
  @override
  List<String> build() {
    _repository = ref.watch(paymentMethodRepositoryProvider);
    _expenses = ref.watch(expenseRepositoryProvider);
    Future.microtask(_load);
    return defaultPaymentMethods;
  }

  Future<void> _load() async => state = await _repository.getAll();
  Future<void> add(String name) async {
    await _repository.add(name);
    await _load();
  }

  Future<void> rename(String oldName, String newName) async {
    if (_repository case final SqlCipherPaymentMethodRepository repository) {
      await repository.renameAndUpdateExpenses(oldName, newName);
    } else {
      await _repository.rename(oldName, newName);
      await _expenses.renamePaymentMethod(oldName, newName);
    }
    await _load();
    await ref.read(expensesProvider.notifier).refresh();
  }

  Future<void> delete(String name) async {
    await _repository.delete(name);
    await _load();
  }

  Future<int> expenseCount(String name) => _expenses.countByPaymentMethod(name);
}
