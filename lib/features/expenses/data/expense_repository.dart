import 'package:sqflite_sqlcipher/sqflite.dart';

import 'expense_model.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getAll();
  Future<void> save(Expense expense);
  Future<void> delete(String id);
}

class InMemoryExpenseRepository implements ExpenseRepository {
  final List<Expense> _expenses = [];

  @override
  Future<List<Expense>> getAll() async => List.unmodifiable(_expenses);

  @override
  Future<void> save(Expense expense) async {
    _expenses.removeWhere((item) => item.id == expense.id);
    _expenses.add(expense);
  }

  @override
  Future<void> delete(String id) async {
    _expenses.removeWhere((expense) => expense.id == id);
  }
}

class SqlCipherExpenseRepository implements ExpenseRepository {
  const SqlCipherExpenseRepository(this._database);

  final Database _database;

  @override
  Future<List<Expense>> getAll() async {
    final rows = await _database.query(
      'expenses',
      orderBy: 'occurred_at_millis DESC, created_at_millis DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(Expense expense) {
    return _database.insert(
      'expenses',
      _toRow(expense),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    await _database.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _toRow(Expense expense) {
    return {
      'id': expense.id,
      'amount_cents': expense.amountCents,
      'category': expense.category,
      'merchant_or_note': expense.merchantOrNote,
      'payment_method': expense.paymentMethod,
      'occurred_at_millis': expense.occurredAt.millisecondsSinceEpoch,
      'created_at_millis': expense.createdAt.millisecondsSinceEpoch,
    };
  }

  Expense _fromRow(Map<String, Object?> row) {
    return Expense(
      id: row['id']! as String,
      amountCents: row['amount_cents']! as int,
      category: row['category']! as String,
      merchantOrNote: row['merchant_or_note'] as String?,
      paymentMethod: row['payment_method'] as String?,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row['occurred_at_millis']! as int,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at_millis']! as int,
      ),
    );
  }
}
