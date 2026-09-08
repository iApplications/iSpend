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
      version: 5,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            amount_cents INTEGER NOT NULL,
            category TEXT NOT NULL,
            merchant_or_note TEXT,
            payment_method TEXT,
            occurred_at_millis INTEGER NOT NULL,
            created_at_millis INTEGER NOT NULL
          )
        ''');
        await _createSettingsTable(db);
        await _createCategoriesTable(db);
        await _createPaymentMethodsTable(db);
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
}
