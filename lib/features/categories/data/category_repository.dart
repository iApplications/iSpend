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
  Future<void> add(String name);
  Future<void> rename(String oldName, String newName);
  Future<void> delete(String name);
}

class InMemoryCategoryRepository implements CategoryRepository {
  final List<String> _categories = List.of(defaultCategoryNames);

  @override
  Future<void> add(String name) async => _categories.add(name);

  @override
  Future<void> delete(String name) async => _categories.remove(name);

  @override
  Future<List<String>> getAll() async => List.unmodifiable(_categories);

  @override
  Future<void> rename(String oldName, String newName) async {
    final index = _categories.indexOf(oldName);
    if (index >= 0) _categories[index] = newName;
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
  Future<void> rename(String oldName, String newName) => _database.update(
    'categories',
    {'name': newName},
    where: 'name = ?',
    whereArgs: [oldName],
  );
}
