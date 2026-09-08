import 'package:sqflite_sqlcipher/sqflite.dart';

abstract interface class AppSettingsRepository {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class InMemoryAppSettingsRepository implements AppSettingsRepository {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class SqlCipherAppSettingsRepository implements AppSettingsRepository {
  const SqlCipherAppSettingsRepository(this._database);

  final Database _database;

  @override
  Future<String?> read(String key) async {
    final rows = await _database.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  @override
  Future<void> write(String key, String value) {
    return _database.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
