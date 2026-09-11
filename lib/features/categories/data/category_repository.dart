import 'package:sqflite_sqlcipher/sqflite.dart';

const defaultCategoryNames = [
  'Food',
  'Transport',
  'Shopping',
  'Bills',
  'Other',
];

abstract interface class CategoryRepository {
  Future<List<String>> getAll();
  Future<Map<String, String>> getIconKeys();
  Future<void> add(String name);
  Future<void> rename(String oldName, String newName);
  Future<void> delete(String name);
  Future<void> updateIconKey(String name, String iconKey);
}

class InMemoryCategoryRepository implements CategoryRepository {
  final List<String> _categories = List.of(defaultCategoryNames);
  final Map<String, String> _iconKeys = {
    for (final name in defaultCategoryNames) name: _defaultIconKey(name),
  };

  @override
  Future<void> add(String name) async => _categories.add(name);

  @override
  Future<void> delete(String name) async => _categories.remove(name);

  @override
  Future<List<String>> getAll() async => List.unmodifiable(_categories);

  @override
  Future<Map<String, String>> getIconKeys() async =>
      Map.unmodifiable(_iconKeys);

  @override
  Future<void> rename(String oldName, String newName) async {
    final index = _categories.indexOf(oldName);
    if (index >= 0) {
      _categories[index] = newName;
      _iconKeys[newName] =
          _iconKeys.remove(oldName) ?? _defaultIconKey(newName);
    }
  }

  @override
  Future<void> updateIconKey(String name, String iconKey) async {
    _iconKeys[name] = iconKey;
  }
}

class SqlCipherCategoryRepository implements CategoryRepository {
  const SqlCipherCategoryRepository(this._database);
  final Database _database;

  @override
  Future<void> add(String name) => _database.insert('categories', {
    'name': name,
    'icon_key': 'other',
    'created_at_millis': DateTime.now().millisecondsSinceEpoch,
  });

  @override
  Future<void> delete(String name) =>
      _database.delete('categories', where: 'name = ?', whereArgs: [name]);

  @override
  Future<List<String>> getAll() async {
    final rows = await _database.query(
      'categories',
      columns: ['name'],
      orderBy: 'created_at_millis ASC, name COLLATE NOCASE ASC',
    );
    return rows.map((row) => row['name']! as String).toList();
  }

  @override
  Future<Map<String, String>> getIconKeys() async {
    final rows = await _database.query(
      'categories',
      columns: ['name', 'icon_key'],
    );
    return {
      for (final row in rows)
        row['name']! as String: row['icon_key']! as String,
    };
  }

  @override
  Future<void> rename(String oldName, String newName) => _database.update(
    'categories',
    {'name': newName},
    where: 'name = ?',
    whereArgs: [oldName],
  );

  @override
  Future<void> updateIconKey(String name, String iconKey) => _database.update(
    'categories',
    {'icon_key': iconKey},
    where: 'name = ?',
    whereArgs: [name],
  );

  Future<void> renameAndUpdateExpenses(String oldName, String newName) {
    return _database.transaction((transaction) async {
      await transaction.update(
        'categories',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );
      await transaction.update(
        'expenses',
        {'category': newName},
        where: 'category = ?',
        whereArgs: [oldName],
      );
      await transaction.update(
        'recurring_expenses',
        {'category': newName},
        where: 'category = ?',
        whereArgs: [oldName],
      );
    });
  }
}

String _defaultIconKey(String name) => switch (name) {
  'Food' => 'food',
  'Transport' => 'transport',
  'Shopping' => 'shopping',
  'Bills' => 'bills',
  _ => 'other',
};
