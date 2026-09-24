import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../expenses/data/expense_repository.dart';
import '../expenses/expense_providers.dart';
import '../budgets/budget_providers.dart';
import '../quick_entry/quick_entry_template_providers.dart';
import 'data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (_) => InMemoryCategoryRepository(),
);

final categoriesProvider = NotifierProvider<CategoriesNotifier, List<String>>(
  CategoriesNotifier.new,
);

final categoryIconKeysProvider = FutureProvider<Map<String, String>>(
  (ref) => ref.watch(categoryRepositoryProvider).getIconKeys(),
);

class CategoriesNotifier extends Notifier<List<String>> {
  late final CategoryRepository _repository;
  late final ExpenseRepository _expenseRepository;

  @override
  List<String> build() {
    _repository = ref.watch(categoryRepositoryProvider);
    _expenseRepository = ref.watch(expenseRepositoryProvider);
    Future<void>.microtask(_load);
    return List.unmodifiable(defaultCategoryNames);
  }

  Future<void> _load() async {
    final loadedCategories = await _repository.getAll();
    final seenNames = <String>{};
    state = [
      for (final category in loadedCategories)
        if (seenNames.add(category.toLowerCase())) category,
    ];
  }

  /// Reloads the persisted categories after an external data operation, such
  /// as restoring a backup, without disposing the provider currently watched
  /// by the UI.
  Future<void> refresh() => _load();

  Future<void> add(String name) async {
    await _repository.add(name);
    await _load();
    ref.invalidate(quickEntryTemplateReferencesProvider);
  }

  Future<void> rename(String oldName, String newName) async {
    if (_repository case final SqlCipherCategoryRepository repository) {
      await repository.renameAndUpdateExpenses(oldName, newName);
    } else {
      await _repository.rename(oldName, newName);
      await _expenseRepository.renameCategory(oldName, newName);
    }
    await ref
        .read(budgetLimitsProvider.notifier)
        .renameCategory(oldName, newName);
    await _load();
    await ref.read(expensesProvider.notifier).refresh();
    ref.invalidate(quickEntryTemplateReferencesProvider);
  }

  Future<int> expenseCount(String name) =>
      _expenseRepository.countByCategory(name);

  Future<int> templateCount(String name) async {
    final id = (await _repository.getIdsByName())[name];
    if (id == null) return 0;
    return ref.read(quickEntryTemplateRepositoryProvider).countByCategoryId(id);
  }

  Future<void> delete(String name) async {
    await ref.read(budgetLimitsProvider.notifier).clear(name);
    await _repository.delete(name);
    await _load();
    ref.invalidate(quickEntryTemplateReferencesProvider);
  }

  Future<void> updateIconKey(String name, String iconKey) async {
    await _repository.updateIconKey(name, iconKey);
    ref.invalidate(categoryIconKeysProvider);
  }
}
