import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_key_store.dart';

class ISpendDatabase {
  ISpendDatabase._(this.database);

  final Database database;

  /// Deletes only this device's local database and its SQLite sidecar files.
  /// External manual backup files are never stored at this path.
  static Future<void> deleteLocalDatabase() async {
    final databasePath = join(await getDatabasesPath(), 'ispend.db');
    await deleteDatabase(databasePath);
  }

  static Future<ISpendDatabase> open({
    DatabaseKeyStore? keyStore,
    String? databasePath,
    String? databaseKey,
  }) async {
    final resolvedDatabaseKey =
        databaseKey ?? await (keyStore ?? DatabaseKeyStore()).readOrCreateKey();
    final resolvedDatabasePath =
        databasePath ?? join(await getDatabasesPath(), 'ispend.db');
    final database = await openDatabase(
      resolvedDatabasePath,
      password: resolvedDatabaseKey,
      version: 12,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            amount_cents INTEGER NOT NULL,
            category TEXT NOT NULL,
            category_id TEXT NOT NULL,
            merchant_or_note TEXT,
            payment_method TEXT,
            payment_method_id TEXT,
            occurred_at_millis INTEGER NOT NULL,
            created_at_millis INTEGER NOT NULL,
            recurring_rule_id TEXT,
            recurring_occurrence_millis INTEGER,
            is_tax_deductible INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await _createSettingsTable(db);
        await _createCategoriesTable(db);
        await _createPaymentMethodsTable(db);
        await _createRecurringExpensesTable(db);
        await _createRecurringExpenseIndexes(db);
        await _createQuickEntryTemplatesTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createSettingsTable(db);
        }
        if (oldVersion < 3) {
          await _createCategoriesTable(db);
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE categories ADD COLUMN icon_key TEXT NOT NULL DEFAULT 'other'",
          );
          for (final name in const [
            'Food',
            'Transport',
            'Shopping',
            'Bills',
            'Other',
          ]) {
            await db.update(
              'categories',
              {'icon_key': _defaultCategoryIconKey(name)},
              where: 'name = ?',
              whereArgs: [name],
            );
          }
        }
        if (oldVersion < 5) await _createPaymentMethodsTable(db);
        if (oldVersion < 6) await _createRecurringExpensesTable(db);
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE expenses ADD COLUMN recurring_rule_id TEXT',
          );
          await db.execute(
            'ALTER TABLE expenses ADD COLUMN recurring_occurrence_millis INTEGER',
          );
          if (oldVersion >= 6) {
            await db.execute(
              'ALTER TABLE recurring_expenses ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
            );
          }
          await db.execute('''
            UPDATE expenses
            SET recurring_rule_id = id
            WHERE id IN (SELECT id FROM recurring_expenses)
          ''');
          await _createRecurringExpenseIndexes(db);
        }
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE expenses ADD COLUMN is_tax_deductible INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'CREATE INDEX expenses_tax_deductible ON expenses(is_tax_deductible)',
          );
        }
        if (oldVersion < 9) {
          if (oldVersion >= 6) {
            await db.execute(
              'ALTER TABLE recurring_expenses ADD COLUMN is_tax_deductible INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
        if (oldVersion < 10 && oldVersion >= 6) {
          await db.execute(
            'ALTER TABLE recurring_expenses ADD COLUMN anchor_day INTEGER NOT NULL DEFAULT 1',
          );
          final schedules = await db.query('recurring_expenses');
          for (final schedule in schedules) {
            final original = await db.query(
              'expenses',
              columns: ['occurred_at_millis'],
              where: 'id = ?',
              whereArgs: [schedule['id']],
              limit: 1,
            );
            // Best-effort fallback: the original occurrence may have been
            // deleted and next_occurrence may already reflect prior drift.
            final millis = original.isEmpty
                ? schedule['next_occurrence_millis']! as int
                : original.single['occurred_at_millis']! as int;
            await db.update(
              'recurring_expenses',
              {'anchor_day': DateTime.fromMillisecondsSinceEpoch(millis).day},
              where: 'id = ?',
              whereArgs: [schedule['id']],
            );
          }
        }
        if (oldVersion < 11) await _migrateStableReferenceIds(db);
        if (oldVersion < 12) await _createQuickEntryTemplatesTable(db);
      },
    );
    return ISpendDatabase._(database);
  }

  static Future<void> _createSettingsTable(Database db) {
    return db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        icon_key TEXT NOT NULL,
        created_at_millis INTEGER NOT NULL
      )
    ''');
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    for (final name in const [
      'Food',
      'Transport',
      'Shopping',
      'Bills',
      'Other',
    ]) {
      await db.insert('categories', {
        'id': const Uuid().v4(),
        'name': name,
        'icon_key': _defaultCategoryIconKey(name),
        'created_at_millis': createdAt,
      });
    }
  }

  static String _defaultCategoryIconKey(String name) => switch (name) {
    'Food' => 'food',
    'Transport' => 'transport',
    'Shopping' => 'shopping',
    'Bills' => 'bills',
    _ => 'other',
  };

  static Future<void> _createPaymentMethodsTable(Database db) async {
    await db.execute('''
      CREATE TABLE payment_methods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        created_at_millis INTEGER NOT NULL
      )
    ''');
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    for (final name in const ['Cash', 'Credit Card', 'Debit Card']) {
      await db.insert('payment_methods', {
        'id': const Uuid().v4(),
        'name': name,
        'created_at_millis': createdAt,
      });
    }
  }

  static Future<void> _createRecurringExpensesTable(Database db) async {
    await db.execute('''
      CREATE TABLE recurring_expenses (
        id TEXT PRIMARY KEY,
        amount_cents INTEGER NOT NULL,
        category TEXT NOT NULL,
        category_id TEXT NOT NULL,
        merchant_or_note TEXT,
        payment_method TEXT,
        payment_method_id TEXT,
        next_occurrence_millis INTEGER NOT NULL,
        created_at_millis INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_tax_deductible INTEGER NOT NULL DEFAULT 0,
        anchor_day INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX recurring_expenses_next_occurrence
      ON recurring_expenses(next_occurrence_millis)
    ''');
  }

  static Future<void> _createRecurringExpenseIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX expenses_recurring_rule
      ON expenses(recurring_rule_id)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX expenses_recurring_occurrence
      ON expenses(recurring_rule_id, recurring_occurrence_millis)
      WHERE recurring_rule_id IS NOT NULL
        AND recurring_occurrence_millis IS NOT NULL
    ''');
  }

  /// Templates deliberately retain only stable foreign IDs. Names are resolved
  /// live in the UI, so a category or payment-method rename cannot stale them.
  static Future<void> _createQuickEntryTemplatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE quick_entry_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category_id TEXT NOT NULL,
        payment_method_id TEXT,
        merchant_or_note TEXT,
        sort_order INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at_millis INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX quick_entry_templates_category
      ON quick_entry_templates(category_id)
    ''');
    await db.execute('''
      CREATE INDEX quick_entry_templates_payment_method
      ON quick_entry_templates(payment_method_id)
    ''');
  }

  /// Gives existing records immutable identities while retaining name columns
  /// as display caches for the current UI and historic backup compatibility.
  static Future<void> _migrateStableReferenceIds(Database db) async {
    await _rebuildCategoriesTable(db);
    await _rebuildPaymentMethodsTable(db);

    await db.execute('ALTER TABLE expenses ADD COLUMN category_id TEXT');
    await db.execute('ALTER TABLE expenses ADD COLUMN payment_method_id TEXT');
    await db.execute(
      'ALTER TABLE recurring_expenses ADD COLUMN category_id TEXT',
    );
    await db.execute(
      'ALTER TABLE recurring_expenses ADD COLUMN payment_method_id TEXT',
    );

    await db.execute('''
      UPDATE expenses
      SET category_id = (
        SELECT id FROM categories WHERE categories.name = expenses.category
      )
    ''');
    await db.execute('''
      UPDATE expenses
      SET payment_method_id = (
        SELECT id FROM payment_methods
        WHERE payment_methods.name = expenses.payment_method
      )
      WHERE payment_method IS NOT NULL
    ''');
    await db.execute('''
      UPDATE recurring_expenses
      SET category_id = (
        SELECT id FROM categories
        WHERE categories.name = recurring_expenses.category
      )
    ''');
    await db.execute('''
      UPDATE recurring_expenses
      SET payment_method_id = (
        SELECT id FROM payment_methods
        WHERE payment_methods.name = recurring_expenses.payment_method
      )
      WHERE payment_method IS NOT NULL
    ''');
    await _migrateBudgetCategoryKeys(db);
  }

  static Future<void> _rebuildCategoriesTable(Database db) async {
    await db.execute('ALTER TABLE categories RENAME TO categories_legacy');
    await _createEmptyCategoriesTable(db);
    final rows = await db.query('categories_legacy');
    for (final row in rows) {
      await db.insert('categories', {
        'id': const Uuid().v4(),
        'name': row['name'],
        'icon_key': row['icon_key'] ?? 'other',
        'created_at_millis': row['created_at_millis'],
      });
    }
    await db.execute('DROP TABLE categories_legacy');
  }

  static Future<void> _rebuildPaymentMethodsTable(Database db) async {
    await db.execute(
      'ALTER TABLE payment_methods RENAME TO payment_methods_legacy',
    );
    await _createEmptyPaymentMethodsTable(db);
    final rows = await db.query('payment_methods_legacy');
    for (final row in rows) {
      await db.insert('payment_methods', {
        'id': const Uuid().v4(),
        'name': row['name'],
        'created_at_millis': row['created_at_millis'],
      });
    }
    await db.execute('DROP TABLE payment_methods_legacy');
  }

  static Future<void> _migrateBudgetCategoryKeys(Database db) async {
    const key = 'monthly_category_budget_limits_v1';
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final encoded = rows.single['value'] as String;
    final values = <String, Object?>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        final category = await db.query(
          'categories',
          columns: ['id'],
          where: 'name = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (category.isNotEmpty && entry.value is int && entry.value > 0) {
          values[category.single['id']! as String] = entry.value;
        }
      }
    } on FormatException {
      return;
    }
    await db.update(
      'app_settings',
      {'value': jsonEncode(values)},
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  static Future<void> _createEmptyCategoriesTable(Database db) => db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        icon_key TEXT NOT NULL,
        created_at_millis INTEGER NOT NULL
      )
    ''');

  static Future<void> _createEmptyPaymentMethodsTable(Database db) =>
      db.execute('''
      CREATE TABLE payment_methods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        created_at_millis INTEGER NOT NULL
      )
    ''');
}
