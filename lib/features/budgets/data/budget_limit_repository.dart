import 'dart:convert';

import '../../../core/database/app_settings_repository.dart';

abstract interface class BudgetLimitRepository {
  Future<Map<String, int>> getAll();
  Future<void> set(String categoryId, int amountCents);
  Future<void> clear(String categoryId);
  Future<void> renameCategory(String oldName, String newName);
}

class SettingsBudgetLimitRepository implements BudgetLimitRepository {
  SettingsBudgetLimitRepository(this._settings);

  static const _key = 'monthly_category_budget_limits_v1';
  final AppSettingsRepository _settings;

  @override
  Future<Map<String, int>> getAll() async {
    final encoded = await _settings.read(_key);
    if (encoded == null) return const {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is int && entry.value > 0)
            entry.key: entry.value as int,
      };
    } on FormatException {
      return const {};
    }
  }

  @override
  Future<void> set(String categoryId, int amountCents) async {
    if (amountCents <= 0) throw ArgumentError.value(amountCents, 'amountCents');
    final values = await getAll();
    await _write({...values, categoryId: amountCents});
  }

  @override
  Future<void> clear(String categoryId) async {
    final values = Map<String, int>.of(await getAll());
    values.remove(categoryId);
    await _write(values);
  }

  @override
  /// Migrated budgets use immutable category IDs and need no rewrite. Keep
  /// this small compatibility path for a legacy name-keyed value encountered
  /// before the v11 database migration has run.
  Future<void> renameCategory(String oldName, String newName) async {
    final values = Map<String, int>.of(await getAll());
    final amount = values.remove(oldName);
    if (amount == null) return;
    await _write({...values, newName: amount});
  }

  Future<void> _write(Map<String, int> values) =>
      _settings.write(_key, jsonEncode(values));
}
