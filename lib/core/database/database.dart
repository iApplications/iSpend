import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_key_store.dart';

class ISpendDatabase {
  ISpendDatabase._(this.database);

  final Database database;

  static Future<ISpendDatabase> open({DatabaseKeyStore? keyStore}) async {
    final databaseKey = await (keyStore ?? DatabaseKeyStore())
        .readOrCreateKey();
    final databasePath = join(await getDatabasesPath(), 'ispend.db');
    final database = await openDatabase(
      databasePath,
      password: databaseKey,
      version: 2,
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
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createSettingsTable(db);
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
}
