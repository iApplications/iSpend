import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_key_store.dart';

class ISpendDatabase {
  ISpendDatabase._(this.database);

  final Database database;

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
      version: 9,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            amount_cents INTEGER NOT NULL,
            category TEXT NOT NULL,
            merchant_or_note TEXT,
            payment_method TEXT,
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
          await db.execute(
            'ALTER TABLE recurring_expenses ADD COLUMN is_tax_deductible INTEGER NOT NULL DEFAULT 0',
          );
        }
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
        name TEXT PRIMARY KEY,
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
        name TEXT PRIMARY KEY,
        created_at_millis INTEGER NOT NULL
      )
    ''');
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    for (final name in const ['Cash', 'Credit Card', 'Debit Card']) {
      await db.insert('payment_methods', {
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
        merchant_or_note TEXT,
        payment_method TEXT,
        next_occurrence_millis INTEGER NOT NULL,
        created_at_millis INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_tax_deductible INTEGER NOT NULL DEFAULT 0
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
}
