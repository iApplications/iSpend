import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/recovery_key.dart';

/// Creates a complete, encrypted logical backup without exposing a raw
/// database file. The document can only be opened with the recovery passphrase.
abstract interface class ManualBackupOperations {
  Future<String> export({
    required Database database,
    required String passphrase,
  });

  Future<void> restore({
    required Database database,
    required String document,
    required String passphrase,
  });
}

class ManualBackupService implements ManualBackupOperations {
  const ManualBackupService({RecoveryKeyOperations? recoveryKeyService})
    : _recoveryKeyService = recoveryKeyService ?? const RecoveryKeyService();

  static const format = 'ispend-manual-backup';
  static const version = 1;

  final RecoveryKeyOperations _recoveryKeyService;

  @override
  Future<String> export({
    required Database database,
    required String passphrase,
  }) async {
    final payload = <String, Object>{
      'expenses': await database.query('expenses'),
      'categories': await database.query('categories'),
      'payment_methods': await database.query('payment_methods'),
      'app_settings': await database.query('app_settings'),
      'recurring_expenses': await database.query('recurring_expenses'),
      'quick_entry_templates': await database.query('quick_entry_templates'),
    };
    final encodedPayload = base64UrlEncode(utf8.encode(jsonEncode(payload)));
    final encryptedPayload = await _recoveryKeyService.wrap(
      databaseKey: encodedPayload,
      passphrase: passphrase,
    );
    return jsonEncode({
      'format': format,
      'version': version,
      'created_at_millis': DateTime.now().millisecondsSinceEpoch,
      'encrypted_payload': encryptedPayload.toJson(),
    });
  }

  @override
  Future<void> restore({
    required Database database,
    required String document,
    required String passphrase,
  }) async {
    final root = jsonDecode(document);
    if (root is! Map<String, dynamic> ||
        root['format'] != format ||
        root['version'] != version ||
        root['encrypted_payload'] is! Map<String, dynamic>) {
      throw const FormatException('This is not a supported iSpend backup.');
    }
    final envelope = RecoveryKeyEnvelope.fromJson(
      root['encrypted_payload'] as Map<String, dynamic>,
    );
    final encodedPayload = await _recoveryKeyService.unwrap(
      envelope: envelope,
      passphrase: passphrase,
    );
    final decodedPayload = jsonDecode(
      utf8.decode(base64Url.decode(encodedPayload)),
    );
    if (decodedPayload is! Map<String, dynamic>) {
      throw const FormatException('The backup data is invalid.');
    }

    final normalized = _normalizeStableReferences(
      expenses: _rows(decodedPayload['expenses']),
      categories: _rows(decodedPayload['categories']),
      paymentMethods: _rows(decodedPayload['payment_methods']),
      settings: _rows(decodedPayload['app_settings']),
      recurringExpenses: _optionalRows(decodedPayload['recurring_expenses']),
      quickEntryTemplates: _optionalRows(
        decodedPayload['quick_entry_templates'],
      ),
    );

    await database.transaction((transaction) async {
      for (final table in const [
        'expenses',
        'categories',
        'payment_methods',
        'app_settings',
        'recurring_expenses',
        'quick_entry_templates',
      ]) {
        await transaction.delete(table);
      }
      await _insertAll(transaction, 'expenses', normalized.expenses);
      await _insertAll(transaction, 'categories', normalized.categories);
      await _insertAll(
        transaction,
        'payment_methods',
        normalized.paymentMethods,
      );
      await _insertAll(transaction, 'app_settings', normalized.settings);
      await _insertAll(
        transaction,
        'recurring_expenses',
        normalized.recurringExpenses,
      );
      await _insertAll(
        transaction,
        'quick_entry_templates',
        normalized.quickEntryTemplates,
      );
    });
  }

  static List<Map<String, Object?>> _rows(Object? value) {
    if (value is! List) {
      throw const FormatException('The backup data is invalid.');
    }
    return value.map((row) {
      if (row is! Map) {
        throw const FormatException('The backup data is invalid.');
      }
      return row.map((key, value) => MapEntry(key as String, value));
    }).toList();
  }

  static List<Map<String, Object?>> _optionalRows(Object? value) =>
      value == null ? const [] : _rows(value);

  static Future<void> _insertAll(
    Transaction transaction,
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    final batch = transaction.batch();
    for (final row in rows) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.abort);
    }
    await batch.commit(noResult: true);
  }

  static _NormalizedBackup _normalizeStableReferences({
    required List<Map<String, Object?>> expenses,
    required List<Map<String, Object?>> categories,
    required List<Map<String, Object?>> paymentMethods,
    required List<Map<String, Object?>> settings,
    required List<Map<String, Object?>> recurringExpenses,
    required List<Map<String, Object?>> quickEntryTemplates,
  }) {
    final categoryIds = _assignIds(categories);
    final paymentMethodIds = _assignIds(paymentMethods);
    _applyReferences(expenses, categoryIds, paymentMethodIds);
    _applyReferences(recurringExpenses, categoryIds, paymentMethodIds);
    _applyTemplateReferences(
      quickEntryTemplates,
      categoryIds,
      paymentMethodIds,
    );
    _migrateBudgetKeys(settings, categoryIds);
    return _NormalizedBackup(
      expenses: expenses,
      categories: categories,
      paymentMethods: paymentMethods,
      settings: settings,
      recurringExpenses: recurringExpenses,
      quickEntryTemplates: quickEntryTemplates,
    );
  }

  static Map<String, String> _assignIds(List<Map<String, Object?>> rows) {
    final ids = <String, String>{};
    for (final row in rows) {
      final name = row['name'];
      if (name is! String || name.isEmpty) {
        throw const FormatException('The backup data is invalid.');
      }
      final id = row['id'];
      final stableId = id is String && id.isNotEmpty ? id : const Uuid().v4();
      row['id'] = stableId;
      ids[name] = stableId;
    }
    return ids;
  }

  static void _applyReferences(
    List<Map<String, Object?>> rows,
    Map<String, String> categoryIds,
    Map<String, String> paymentMethodIds,
  ) {
    for (final row in rows) {
      final category = row['category'];
      if (category is! String || categoryIds[category] == null) {
        throw const FormatException('The backup data is invalid.');
      }
      row['category_id'] = categoryIds[category]!;
      final paymentMethod = row['payment_method'];
      if (paymentMethod == null) {
        row['payment_method_id'] = null;
      } else if (paymentMethod is String &&
          paymentMethodIds[paymentMethod] != null) {
        row['payment_method_id'] = paymentMethodIds[paymentMethod]!;
      } else {
        throw const FormatException('The backup data is invalid.');
      }
    }
  }

  static void _applyTemplateReferences(
    List<Map<String, Object?>> rows,
    Map<String, String> categoryIds,
    Map<String, String> paymentMethodIds,
  ) {
    for (final row in rows) {
      final categoryId = row['category_id'];
      if (categoryId is! String || !categoryIds.containsValue(categoryId)) {
        throw const FormatException('The backup data is invalid.');
      }
      final paymentMethodId = row['payment_method_id'];
      if (paymentMethodId != null &&
          (paymentMethodId is! String ||
              !paymentMethodIds.containsValue(paymentMethodId))) {
        throw const FormatException('The backup data is invalid.');
      }
    }
  }

  static void _migrateBudgetKeys(
    List<Map<String, Object?>> settings,
    Map<String, String> categoryIds,
  ) {
    for (final setting in settings) {
      if (setting['key'] != 'monthly_category_budget_limits_v1') {
        continue;
      }
      final value = setting['value'];
      if (value is! String) {
        throw const FormatException('The backup data is invalid.');
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('The backup data is invalid.');
        }
        final migrated = <String, Object?>{};
        for (final entry in decoded.entries) {
          final id = categoryIds[entry.key] ?? entry.key;
          migrated[id] = entry.value;
        }
        setting['value'] = jsonEncode(migrated);
      } on FormatException {
        rethrow;
      }
    }
  }
}

class _NormalizedBackup {
  const _NormalizedBackup({
    required this.expenses,
    required this.categories,
    required this.paymentMethods,
    required this.settings,
    required this.recurringExpenses,
    required this.quickEntryTemplates,
  });

  final List<Map<String, Object?>> expenses;
  final List<Map<String, Object?>> categories;
  final List<Map<String, Object?>> paymentMethods;
  final List<Map<String, Object?>> settings;
  final List<Map<String, Object?>> recurringExpenses;
  final List<Map<String, Object?>> quickEntryTemplates;
}
