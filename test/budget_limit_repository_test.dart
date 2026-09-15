import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/app_settings_repository.dart';
import 'package:ispend/features/budgets/data/budget_limit_repository.dart';

void main() {
  test(
    'budget limits persist, rename with categories, and can be cleared',
    () async {
      final repository = SettingsBudgetLimitRepository(
        InMemoryAppSettingsRepository(),
      );

      await repository.set('Food', 80000);
      expect(await repository.getAll(), {'Food': 80000});

      await repository.renameCategory('Food', 'Meals');
      expect(await repository.getAll(), {'Meals': 80000});

      await repository.clear('Meals');
      expect(await repository.getAll(), isEmpty);
    },
  );
}
