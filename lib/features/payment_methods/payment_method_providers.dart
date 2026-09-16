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

final paymentMethodColourKeysProvider =
    NotifierProvider<PaymentMethodColoursNotifier, Map<String, String>>(
      PaymentMethodColoursNotifier.new,
    );

class PaymentMethodColoursNotifier extends Notifier<Map<String, String>> {
  late final PaymentMethodRepository _repository;

  @override
  Map<String, String> build() {
    _repository = ref.watch(paymentMethodRepositoryProvider);
    Future.microtask(refresh);
    return const {};
  }

  Future<void> refresh() async {
    final ids = await _repository.getIdsByName();
    final colours = await _repository.getColourKeysById();
    state = {
      for (final entry in ids.entries)
        entry.key: colours[entry.value] ?? 'default',
    };
  }

  Future<void> set(String name, String colourKey) async {
    final id = (await _repository.getIdsByName())[name];
    if (id == null) return;
    await _repository.setColourKey(id, colourKey);
    await refresh();
  }
}

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

  /// Reloads the persisted payment methods after an external data operation,
  /// such as restoring a backup, without disposing the active provider.
  Future<void> refresh() => _load();

  Future<void> add(String name) async {
    await _repository.add(name);
    await _load();
    await ref.read(paymentMethodColourKeysProvider.notifier).refresh();
  }

  Future<void> rename(String oldName, String newName) async {
    if (_repository case final SqlCipherPaymentMethodRepository repository) {
      await repository.renameAndUpdateExpenses(oldName, newName);
    } else {
      await _repository.rename(oldName, newName);
      await _expenses.renamePaymentMethod(oldName, newName);
    }
    await _load();
    await ref.read(paymentMethodColourKeysProvider.notifier).refresh();
    await ref.read(expensesProvider.notifier).refresh();
  }

  Future<void> delete(String name) async {
    await _repository.delete(name);
    await _load();
    await ref.read(paymentMethodColourKeysProvider.notifier).refresh();
  }

  Future<int> expenseCount(String name) => _expenses.countByPaymentMethod(name);
}
