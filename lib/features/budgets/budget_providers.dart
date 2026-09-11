import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_settings_repository.dart';
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

  @override
  Map<String, int> build() {
    _repository = ref.watch(budgetLimitRepositoryProvider);
    Future<void>.microtask(refresh);
    return const {};
  }

  Future<void> refresh() async => state = await _repository.getAll();

  Future<void> set(String category, int amountCents) async {
    await _repository.set(category, amountCents);
    await refresh();
  }

  Future<void> clear(String category) async {
    await _repository.clear(category);
    await refresh();
  }

  Future<void> renameCategory(String oldName, String newName) async {
    await _repository.renameCategory(oldName, newName);
    await refresh();
  }
}
