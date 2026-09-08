import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../expenses/data/expense_repository.dart';
import '../expenses/expense_providers.dart';
import 'data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (_) => InMemoryCategoryRepository(),
);

final categoriesProvider = NotifierProvider<CategoriesNotifier, List<String>>(
  CategoriesNotifier.new,
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

  Future<void> add(String name) async {
    await _repository.add(name);
    await _load();
  }

  Future<void> rename(String oldName, String newName) async {
    await _repository.rename(oldName, newName);
    await _expenseRepository.renameCategory(oldName, newName);
    await _load();
    await ref.read(expensesProvider.notifier).refresh();
  }

  Future<int> expenseCount(String name) =>
      _expenseRepository.countByCategory(name);

  Future<void> delete(String name) async {
    await _repository.delete(name);
    await _load();
  }
}
