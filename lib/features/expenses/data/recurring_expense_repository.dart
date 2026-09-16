import 'package:sqflite_sqlcipher/sqflite.dart';

import 'expense_model.dart';
import 'expense_repository.dart';
import 'recurring_expense.dart';

abstract interface class RecurringExpenseRepository {
  Future<List<RecurringExpense>> getAll();
  Future<RecurringExpense?> getById(String id);
  Future<List<RecurringExpense>> dueOnOrBefore(DateTime date);
  Future<Expense> enableForExpense(Expense expense);
  Future<void> updateSchedule(RecurringExpense recurring);
  Future<void> saveLinkedExpense(
    Expense expense, {
    bool updateTaxDefault = true,
  });
  Future<bool> confirm(RecurringExpense recurring, Expense occurrence);
  Future<void> stop(String id);
  Future<void> reactivate(String id, DateTime nextOccurrence);
}

class InMemoryRecurringExpenseRepository implements RecurringExpenseRepository {
  InMemoryRecurringExpenseRepository(this._expenses);

  final ExpenseRepository _expenses;
  final List<RecurringExpense> _items = [];
  final Set<String> _confirmedOccurrences = {};

  @override
  Future<List<RecurringExpense>> getAll() async => List.unmodifiable(_items);

  @override
  Future<RecurringExpense?> getById(String id) async {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<RecurringExpense>> dueOnOrBefore(DateTime date) async => _items
      .where((item) => item.isActive && !item.nextOccurrence.isAfter(date))
      .toList();

  @override
  Future<Expense> enableForExpense(Expense expense) async {
    if (expense.recurringRuleId != null || await getById(expense.id) != null) {
      throw StateError('This expense already belongs to a recurring rule.');
    }
    final linked = expense.copyWith(recurringRuleId: expense.id);
    await _expenses.save(linked);
    _items.add(_fromExpense(linked));
    return linked;
  }

  @override
  Future<void> updateSchedule(RecurringExpense recurring) async {
    final index = _items.indexWhere((item) => item.id == recurring.id);
    if (index < 0) return;
    _items[index] = recurring;
    await _synchronizeSeriesFields(recurring.id, recurring);
  }

  @override
  Future<void> saveLinkedExpense(
    Expense expense, {
    bool updateTaxDefault = true,
  }) async {
    final ruleId = expense.recurringRuleId;
    if (ruleId == null) {
      throw StateError('The expense is not linked to a recurring rule.');
    }
    final index = _items.indexWhere((item) => item.id == ruleId);
    if (index < 0) throw StateError('The recurring rule no longer exists.');
    _items[index] = _withRecurringSeriesFields(
      _items[index],
      expense,
      updateTaxDefault: updateTaxDefault,
    );
    await _expenses.save(expense);
    await _synchronizeSeriesFields(ruleId, _items[index]);
  }

  @override
  Future<bool> confirm(RecurringExpense recurring, Expense occurrence) async {
    final index = _items.indexWhere(
      (item) =>
          item.id == recurring.id &&
          item.isActive &&
          item.nextOccurrence == recurring.nextOccurrence,
    );
    final occurrenceKey =
        '${recurring.id}:${recurring.nextOccurrence.millisecondsSinceEpoch}';
    if (index < 0 || !_confirmedOccurrences.add(occurrenceKey)) return false;

    final linkedOccurrence = occurrence.copyWith(
      recurringRuleId: recurring.id,
      recurringOccurrence: recurring.nextOccurrence,
    );
    await _expenses.save(linkedOccurrence);
    _items[index] = _advancedSchedule(recurring, occurrence);
    await _synchronizeSeriesFields(recurring.id, _items[index]);
    return true;
  }

  @override
  Future<void> stop(String id) async {
    final item = await getById(id);
    if (item != null) await updateSchedule(item.copyWith(isActive: false));
  }

  @override
  Future<void> reactivate(String id, DateTime nextOccurrence) async {
    final item = await getById(id);
    if (item == null) throw StateError('The recurring rule no longer exists.');
    await updateSchedule(
      item.copyWith(isActive: true, nextOccurrence: nextOccurrence),
    );
  }

  Future<void> _synchronizeSeriesFields(
    String ruleId,
    RecurringExpense recurring,
  ) async {
    for (final expense in await _expenses.getAll()) {
      if (expense.recurringRuleId == ruleId) {
        await _expenses.save(_withSeriesFields(expense, recurring));
      }
    }
  }
}

class SqlCipherRecurringExpenseRepository
    implements RecurringExpenseRepository {
  const SqlCipherRecurringExpenseRepository(this._database);
  final Database _database;

  @override
  Future<List<RecurringExpense>> getAll() async {
    final rows = await _database.query(
      'recurring_expenses',
      orderBy: 'next_occurrence_millis ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<RecurringExpense?> getById(String id) async {
    final rows = await _database.query(
      'recurring_expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<List<RecurringExpense>> dueOnOrBefore(DateTime date) async {
    final rows = await _database.query(
      'recurring_expenses',
      where: 'is_active = 1 AND next_occurrence_millis <= ?',
      whereArgs: [date.millisecondsSinceEpoch],
      orderBy: 'next_occurrence_millis ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Expense> enableForExpense(Expense expense) async {
    if (expense.recurringRuleId != null) {
      throw StateError('This expense already belongs to a recurring rule.');
    }
    final linked = expense.copyWith(recurringRuleId: expense.id);
    await _database.transaction((transaction) async {
      final references = await resolveReferenceIds(
        transaction,
        category: linked.category,
        paymentMethod: linked.paymentMethod,
      );
      final existing = Sqflite.firstIntValue(
        await transaction.rawQuery(
          'SELECT COUNT(*) FROM recurring_expenses WHERE id = ?',
          [expense.id],
        ),
      );
      if (existing != 0) {
        throw StateError('This expense already has a recurring rule.');
      }
      await transaction.insert(
        'recurring_expenses',
        _toRow(_fromExpense(linked), references),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await transaction.insert(
        'expenses',
        _expenseRow(linked, references),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    return linked;
  }

  @override
  Future<void> updateSchedule(RecurringExpense recurring) async {
    await _database.transaction((transaction) async {
      final references = await resolveReferenceIds(
        transaction,
        category: recurring.category,
        paymentMethod: recurring.paymentMethod,
      );
      await transaction.update(
        'recurring_expenses',
        _toRow(recurring, references),
        where: 'id = ?',
        whereArgs: [recurring.id],
      );
      await transaction.update(
        'expenses',
        _seriesFields(recurring, references),
        where: 'recurring_rule_id = ?',
        whereArgs: [recurring.id],
      );
    });
  }

  @override
  Future<void> saveLinkedExpense(
    Expense expense, {
    bool updateTaxDefault = true,
  }) async {
    final ruleId = expense.recurringRuleId;
    if (ruleId == null) {
      throw StateError('The expense is not linked to a recurring rule.');
    }
    await _database.transaction((transaction) async {
      final references = await resolveReferenceIds(
        transaction,
        category: expense.category,
        paymentMethod: expense.paymentMethod,
      );
      final scheduleValues = <String, Object?>{
        'category': expense.category,
        'category_id': references.categoryId,
        'merchant_or_note': expense.merchantOrNote,
        'payment_method': expense.paymentMethod,
        'payment_method_id': references.paymentMethodId,
      };
      if (updateTaxDefault) {
        scheduleValues['is_tax_deductible'] = expense.isTaxDeductible ? 1 : 0;
      }
      final changed = await transaction.update(
        'recurring_expenses',
        scheduleValues,
        where: 'id = ?',
        whereArgs: [ruleId],
      );
      if (changed != 1) {
        throw StateError('The recurring rule no longer exists.');
      }
      await transaction.insert(
        'expenses',
        _expenseRow(expense, references),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.update(
        'expenses',
        {
          'category': expense.category,
          'category_id': references.categoryId,
          'merchant_or_note': expense.merchantOrNote,
          'payment_method': expense.paymentMethod,
          'payment_method_id': references.paymentMethodId,
        },
        where: 'recurring_rule_id = ?',
        whereArgs: [ruleId],
      );
    });
  }

  @override
  Future<bool> confirm(RecurringExpense recurring, Expense occurrence) async {
    return _database.transaction((transaction) async {
      final linkedOccurrence = occurrence.copyWith(
        recurringRuleId: recurring.id,
        recurringOccurrence: recurring.nextOccurrence,
      );
      final updated = _advancedSchedule(recurring, occurrence);
      final references = await resolveReferenceIds(
        transaction,
        category: updated.category,
        paymentMethod: updated.paymentMethod,
      );
      final changed = await transaction.update(
        'recurring_expenses',
        _toRow(updated, references),
        where: 'id = ? AND is_active = 1 AND next_occurrence_millis = ?',
        whereArgs: [
          recurring.id,
          recurring.nextOccurrence.millisecondsSinceEpoch,
        ],
      );
      if (changed != 1) return false;
      await transaction.insert(
        'expenses',
        _expenseRow(linkedOccurrence, references),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await transaction.update(
        'expenses',
        _seriesFields(updated, references),
        where: 'recurring_rule_id = ?',
        whereArgs: [recurring.id],
      );
      return true;
    });
  }

  @override
  Future<void> stop(String id) => _database.update(
    'recurring_expenses',
    {'is_active': 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  @override
  Future<void> reactivate(String id, DateTime nextOccurrence) async {
    final changed = await _database.update(
      'recurring_expenses',
      {
        'is_active': 1,
        'next_occurrence_millis': nextOccurrence.millisecondsSinceEpoch,
        'anchor_day': nextOccurrence.day,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed != 1) throw StateError('The recurring rule no longer exists.');
  }

  Map<String, Object?> _toRow(RecurringExpense item, ReferenceIds references) =>
      {
        'id': item.id,
        'amount_cents': item.amountCents,
        'category': item.category,
        'category_id': references.categoryId,
        'merchant_or_note': item.merchantOrNote,
        'payment_method': item.paymentMethod,
        'payment_method_id': references.paymentMethodId,
        'next_occurrence_millis': item.nextOccurrence.millisecondsSinceEpoch,
        'created_at_millis': item.createdAt.millisecondsSinceEpoch,
        'is_active': item.isActive ? 1 : 0,
        'is_tax_deductible': item.isTaxDeductible ? 1 : 0,
        'anchor_day': item.anchorDay,
      };

  RecurringExpense _fromRow(Map<String, Object?> row) => RecurringExpense(
    id: row['id']! as String,
    amountCents: row['amount_cents']! as int,
    category: row['category']! as String,
    merchantOrNote: row['merchant_or_note'] as String?,
    paymentMethod: row['payment_method'] as String?,
    nextOccurrence: DateTime.fromMillisecondsSinceEpoch(
      row['next_occurrence_millis']! as int,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at_millis']! as int,
    ),
    isActive: (row['is_active'] as int? ?? 1) == 1,
    isTaxDeductible: (row['is_tax_deductible'] as int? ?? 0) == 1,
    anchorDay: row['anchor_day']! as int,
  );
}

RecurringExpense _fromExpense(Expense expense) => RecurringExpense(
  id: expense.id,
  amountCents: expense.amountCents,
  category: expense.category,
  merchantOrNote: expense.merchantOrNote,
  paymentMethod: expense.paymentMethod,
  nextOccurrence: nextMonthlyOccurrence(
    expense.occurredAt,
    expense.occurredAt.day,
  ),
  createdAt: expense.createdAt,
  anchorDay: expense.occurredAt.day,
  isTaxDeductible: expense.isTaxDeductible,
);

RecurringExpense _advancedSchedule(
  RecurringExpense recurring,
  Expense occurrence,
) => RecurringExpense(
  id: recurring.id,
  amountCents: occurrence.amountCents,
  category: occurrence.category,
  merchantOrNote: occurrence.merchantOrNote,
  paymentMethod: occurrence.paymentMethod,
  nextOccurrence: nextMonthlyOccurrence(
    recurring.nextOccurrence,
    recurring.anchorDay,
  ),
  createdAt: recurring.createdAt,
  anchorDay: recurring.anchorDay,
  isActive: recurring.isActive,
  isTaxDeductible: occurrence.isTaxDeductible,
);

Map<String, Object?> _expenseRow(Expense expense, ReferenceIds references) => {
  'id': expense.id,
  'amount_cents': expense.amountCents,
  'category': expense.category,
  'category_id': references.categoryId,
  'merchant_or_note': expense.merchantOrNote,
  'payment_method': expense.paymentMethod,
  'payment_method_id': references.paymentMethodId,
  'occurred_at_millis': expense.occurredAt.millisecondsSinceEpoch,
  'created_at_millis': expense.createdAt.millisecondsSinceEpoch,
  'recurring_rule_id': expense.recurringRuleId,
  'recurring_occurrence_millis':
      expense.recurringOccurrence?.millisecondsSinceEpoch,
  'is_tax_deductible': expense.isTaxDeductible ? 1 : 0,
};

DateTime nextMonthlyOccurrence(DateTime date, int anchorDay) {
  final month = date.month == 12 ? 1 : date.month + 1;
  final year = date.month == 12 ? date.year + 1 : date.year;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    anchorDay.clamp(1, lastDay),
    date.hour,
    date.minute,
  );
}

Map<String, Object?> _seriesFields(
  RecurringExpense recurring,
  ReferenceIds references,
) => {
  'category': recurring.category,
  'category_id': references.categoryId,
  'merchant_or_note': recurring.merchantOrNote,
  'payment_method': recurring.paymentMethod,
  'payment_method_id': references.paymentMethodId,
};

Expense _withSeriesFields(Expense expense, RecurringExpense recurring) =>
    Expense(
      id: expense.id,
      amountCents: expense.amountCents,
      category: recurring.category,
      merchantOrNote: recurring.merchantOrNote,
      paymentMethod: recurring.paymentMethod,
      occurredAt: expense.occurredAt,
      createdAt: expense.createdAt,
      recurringRuleId: expense.recurringRuleId,
      recurringOccurrence: expense.recurringOccurrence,
      isTaxDeductible: expense.isTaxDeductible,
    );

RecurringExpense _withRecurringSeriesFields(
  RecurringExpense recurring,
  Expense expense, {
  required bool updateTaxDefault,
}) => RecurringExpense(
  id: recurring.id,
  amountCents: recurring.amountCents,
  category: expense.category,
  merchantOrNote: expense.merchantOrNote,
  paymentMethod: expense.paymentMethod,
  nextOccurrence: recurring.nextOccurrence,
  createdAt: recurring.createdAt,
  anchorDay: recurring.anchorDay,
  isActive: recurring.isActive,
  isTaxDeductible: updateTaxDefault
      ? expense.isTaxDeductible
      : recurring.isTaxDeductible,
);
