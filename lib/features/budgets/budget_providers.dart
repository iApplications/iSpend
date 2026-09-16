import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_settings_repository.dart';
import '../categories/category_providers.dart';
import '../categories/data/category_repository.dart';
import 'data/budget_limit_repository.dart';

final budgetLimitRepositoryProvider = Provider<BudgetLimitRepository>(
  (ref) =>
      SettingsBudgetLimitRepository(ref.watch(appSettingsRepositoryProvider)),
);

final budgetLimitsProvider =
    NotifierProvider<BudgetLimitsNotifier, Map<String, int>>(
      BudgetLimitsNotifier.new,
    );

class BudgetLimitsNotifier extends Notifier<Map<String, int>> {
  late final BudgetLimitRepository _repository;
  late final CategoryRepository _categories;
  var _refreshVersion = 0;

  @override
  Map<String, int> build() {
    _repository = ref.watch(budgetLimitRepositoryProvider);
    _categories = ref.watch(categoryRepositoryProvider);
    Future<void>.microtask(refresh);
    return const {};
  }

  Future<void> refresh() async {
    final refreshVersion = ++_refreshVersion;
    final idsByName = await _categories.getIdsByName();
    final limitsById = await _repository.getAll();
    final namesById = {
      for (final entry in idsByName.entries) entry.value: entry.key,
    };
    if (refreshVersion != _refreshVersion) return;
    state = {
      for (final entry in limitsById.entries)
        if (namesById[entry.key] case final String name) name: entry.value,
    };
  }

  Future<void> set(String category, int amountCents) async {
    await _repository.set(await _categoryId(category), amountCents);
    await refresh();
  }

  Future<void> clear(String category) async {
    await _repository.clear(await _categoryId(category));
    await refresh();
  }

  Future<void> renameCategory(String oldName, String newName) async {
    await _repository.renameCategory(oldName, newName);
    await refresh();
  }

  Future<String> _categoryId(String name) async {
    final id = (await _categories.getIdsByName())[name];
    if (id == null) throw StateError('The selected category no longer exists.');
    return id;
  }
}
