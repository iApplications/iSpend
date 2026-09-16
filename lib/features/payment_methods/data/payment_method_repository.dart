import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

const defaultPaymentMethods = ['Cash', 'Credit Card', 'Debit Card'];

abstract interface class PaymentMethodRepository {
  Future<List<String>> getAll();
  Future<Map<String, String>> getIdsByName();
  Future<void> add(String name);
  Future<void> rename(String oldName, String newName);
  Future<void> delete(String name);
}

class InMemoryPaymentMethodRepository implements PaymentMethodRepository {
  final List<String> _methods = List.of(defaultPaymentMethods);
  final Map<String, String> _ids = {
    for (final name in defaultPaymentMethods) name: const Uuid().v4(),
  };

  @override
  Future<List<String>> getAll() async => List.unmodifiable(_methods);
  @override
  Future<Map<String, String>> getIdsByName() async => Map.unmodifiable(_ids);
  @override
  Future<void> add(String name) async {
    _methods.add(name);
    _ids[name] = const Uuid().v4();
  }

  @override
  Future<void> rename(String oldName, String newName) async {
    final index = _methods.indexOf(oldName);
    if (index >= 0) {
      _methods[index] = newName;
      _ids[newName] = _ids.remove(oldName) ?? const Uuid().v4();
    }
  }

  @override
  Future<void> delete(String name) async {
    _methods.remove(name);
    _ids.remove(name);
  }
}

class SqlCipherPaymentMethodRepository implements PaymentMethodRepository {
  const SqlCipherPaymentMethodRepository(this._database);
  final Database _database;

  @override
  Future<List<String>> getAll() async {
    final rows = await _database.query(
      'payment_methods',
      columns: ['name'],
      orderBy: 'created_at_millis ASC, name COLLATE NOCASE ASC',
    );
    return rows.map((row) => row['name']! as String).toList();
  }

  @override
  Future<Map<String, String>> getIdsByName() async {
    final rows = await _database.query(
      'payment_methods',
      columns: ['id', 'name'],
    );
    return {
      for (final row in rows) row['name']! as String: row['id']! as String,
    };
  }

  @override
  Future<void> add(String name) => _database.insert('payment_methods', {
    'id': const Uuid().v4(),
    'name': name,
    'created_at_millis': DateTime.now().millisecondsSinceEpoch,
  });
  @override
  Future<void> rename(String oldName, String newName) => _database.update(
    'payment_methods',
    {'name': newName},
    where: 'name = ?',
    whereArgs: [oldName],
  );
  @override
  Future<void> delete(String name) =>
      _database.delete('payment_methods', where: 'name = ?', whereArgs: [name]);

  Future<void> renameAndUpdateExpenses(String oldName, String newName) {
    return _database.transaction((transaction) async {
      final rows = await transaction.query(
        'payment_methods',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [oldName],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final id = rows.single['id']! as String;
      await transaction.update(
        'payment_methods',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );
      await transaction.update(
        'expenses',
        {'payment_method': newName},
        where: 'payment_method_id = ?',
        whereArgs: [id],
      );
      await transaction.update(
        'recurring_expenses',
        {'payment_method': newName},
        where: 'payment_method_id = ?',
        whereArgs: [id],
      );
    });
  }
}
