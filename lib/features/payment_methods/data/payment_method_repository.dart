import 'package:sqflite_sqlcipher/sqflite.dart';

const defaultPaymentMethods = ['Cash', 'Credit Card', 'Debit Card'];

abstract interface class PaymentMethodRepository {
  Future<List<String>> getAll();
  Future<void> add(String name);
  Future<void> rename(String oldName, String newName);
  Future<void> delete(String name);
}

class InMemoryPaymentMethodRepository implements PaymentMethodRepository {
  final List<String> _methods = List.of(defaultPaymentMethods);

  @override
  Future<List<String>> getAll() async => List.unmodifiable(_methods);
  @override
  Future<void> add(String name) async => _methods.add(name);
  @override
  Future<void> rename(String oldName, String newName) async {
    final index = _methods.indexOf(oldName);
    if (index >= 0) _methods[index] = newName;
  }

  @override
  Future<void> delete(String name) async => _methods.remove(name);
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
  Future<void> add(String name) => _database.insert('payment_methods', {
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
      await transaction.update(
        'payment_methods',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );
      await transaction.update(
        'expenses',
        {'payment_method': newName},
        where: 'payment_method = ?',
        whereArgs: [oldName],
      );
      await transaction.update(
        'recurring_expenses',
        {'payment_method': newName},
        where: 'payment_method = ?',
        whereArgs: [oldName],
      );
    });
  }
}
