import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'expense_model.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getAll();
  Future<void> save(Expense expense);
  Future<void> saveAll(
    List<Expense> expenses, {
    List<ExpenseImageAttachment> attachments = const [],
  });
  Future<Uint8List?> imageForExpense(String expenseId);
  Future<Set<String>> expenseIdsWithImages();
  Future<void> removeImageForExpense(String expenseId);
  Future<int> imageStorageBytes();
  Future<void> delete(String id);
  Future<int> countByCategory(String category);
  Future<void> renameCategory(String oldName, String newName);
  Future<int> countByPaymentMethod(String paymentMethod);
  Future<void> renamePaymentMethod(String oldName, String newName);
}

class ImageStorageLimitException implements Exception {
  const ImageStorageLimitException();
}

class ExpenseImageAttachment {
  const ExpenseImageAttachment({required this.bytes, required this.expenseIds});

  final Uint8List bytes;
  final Set<String> expenseIds;
}

const maxExpenseImageBytes = 1024 * 1024;
const maxTotalImageBytes = 100 * 1024 * 1024;

String expenseImageDigest(Uint8List bytes) =>
    base64UrlEncode(SHA256Digest().process(bytes));

class InMemoryExpenseRepository implements ExpenseRepository {
  final List<Expense> _expenses = [];
  final Map<String, Uint8List> _images = {};
  final Map<String, String> _expenseImageIds = {};

  @override
  Future<List<Expense>> getAll() async => List.unmodifiable(_expenses);

  @override
  Future<void> save(Expense expense) async {
    _expenses.removeWhere((item) => item.id == expense.id);
    _expenses.add(expense);
  }

  @override
  Future<void> saveAll(
    List<Expense> expenses, {
    List<ExpenseImageAttachment> attachments = const [],
  }) async {
    _validateImageBatch(expenses, attachments);
    final newIds = expenses.map((expense) => expense.id).toSet();
    if (newIds.length != expenses.length ||
        _expenses.any((existing) => newIds.contains(existing.id))) {
      throw StateError('An expense in this batch already exists.');
    }
    final addedBytes = attachments.fold(
      0,
      (sum, image) => sum + image.bytes.length,
    );
    if ((await imageStorageBytes()) + addedBytes > maxTotalImageBytes) {
      throw const ImageStorageLimitException();
    }
    for (final expense in expenses) {
      await save(expense);
    }
    for (final attachment in attachments) {
      final imageId = const Uuid().v4();
      _images[imageId] = attachment.bytes;
      for (final expenseId in attachment.expenseIds) {
        _expenseImageIds[expenseId] = imageId;
      }
    }
  }

  @override
  Future<Uint8List?> imageForExpense(String expenseId) async =>
      _images[_expenseImageIds[expenseId]];

  @override
  Future<Set<String>> expenseIdsWithImages() async =>
      _expenseImageIds.keys.toSet();

  @override
  Future<int> imageStorageBytes() async =>
      _images.values.fold<int>(0, (total, image) => total + image.length);

  @override
  Future<void> removeImageForExpense(String expenseId) async {
    final imageId = _expenseImageIds.remove(expenseId);
    if (imageId != null && !_expenseImageIds.containsValue(imageId)) {
      _images.remove(imageId);
    }
  }

  @override
  Future<void> delete(String id) async {
    _expenses.removeWhere((expense) => expense.id == id);
    await removeImageForExpense(id);
  }

  @override
  Future<int> countByCategory(String category) async =>
      _expenses.where((expense) => expense.category == category).length;

  @override
  Future<void> renameCategory(String oldName, String newName) async {
    for (var index = 0; index < _expenses.length; index++) {
      final expense = _expenses[index];
      if (expense.category == oldName) {
        _expenses[index] = Expense(
          id: expense.id,
          amountCents: expense.amountCents,
          category: newName,
          occurredAt: expense.occurredAt,
          createdAt: expense.createdAt,
          merchantOrNote: expense.merchantOrNote,
          paymentMethod: expense.paymentMethod,
          recurringRuleId: expense.recurringRuleId,
          recurringOccurrence: expense.recurringOccurrence,
          isTaxDeductible: expense.isTaxDeductible,
        );
      }
    }
  }

  @override
  Future<int> countByPaymentMethod(String paymentMethod) async => _expenses
      .where((expense) => expense.paymentMethod == paymentMethod)
      .length;

  @override
  Future<void> renamePaymentMethod(String oldName, String newName) async {
    for (var i = 0; i < _expenses.length; i++) {
      final expense = _expenses[i];
      if (expense.paymentMethod == oldName) {
        _expenses[i] = Expense(
          id: expense.id,
          amountCents: expense.amountCents,
          category: expense.category,
          occurredAt: expense.occurredAt,
          createdAt: expense.createdAt,
          merchantOrNote: expense.merchantOrNote,
          paymentMethod: newName,
          recurringRuleId: expense.recurringRuleId,
          recurringOccurrence: expense.recurringOccurrence,
          isTaxDeductible: expense.isTaxDeductible,
        );
      }
    }
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
  Future<void> save(Expense expense) async {
    final references = await resolveReferenceIds(
      _database,
      category: expense.category,
      paymentMethod: expense.paymentMethod,
    );
    await _database.insert(
      'expenses',
      _toRow(expense, references),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveAll(
    List<Expense> expenses, {
    List<ExpenseImageAttachment> attachments = const [],
  }) async {
    _validateImageBatch(expenses, attachments);
    await _database.transaction((transaction) async {
      if (attachments.isNotEmpty) {
        final current =
            Sqflite.firstIntValue(
              await transaction.rawQuery(
                'SELECT COALESCE(SUM(size_bytes), 0) FROM ocr_images',
              ),
            ) ??
            0;
        final addedBytes = attachments.fold(
          0,
          (sum, image) => sum + image.bytes.length,
        );
        if (current + addedBytes > maxTotalImageBytes) {
          throw const ImageStorageLimitException();
        }
      }
      for (final expense in expenses) {
        final references = await resolveReferenceIds(
          transaction,
          category: expense.category,
          paymentMethod: expense.paymentMethod,
        );
        await transaction.insert(
          'expenses',
          _toRow(expense, references),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      for (final attachment in attachments) {
        final imageId = const Uuid().v4();
        await transaction.insert('ocr_images', {
          'id': imageId,
          'jpeg_bytes': attachment.bytes,
          'size_bytes': attachment.bytes.length,
          'sha256': expenseImageDigest(attachment.bytes),
        });
        for (final expenseId in attachment.expenseIds) {
          await transaction.insert('expense_images', {
            'expense_id': expenseId,
            'image_id': imageId,
          });
        }
      }
    });
  }

  @override
  Future<Uint8List?> imageForExpense(String expenseId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT ocr_images.jpeg_bytes, ocr_images.sha256 FROM ocr_images
      JOIN expense_images ON expense_images.image_id = ocr_images.id
      WHERE expense_images.expense_id = ? LIMIT 1
    ''',
      [expenseId],
    );
    if (rows.isEmpty) return null;
    final bytes = rows.single['jpeg_bytes'] as Uint8List;
    if (expenseImageDigest(bytes) != rows.single['sha256']) {
      throw const FormatException('The saved image is damaged.');
    }
    return bytes;
  }

  @override
  Future<Set<String>> expenseIdsWithImages() async {
    final rows = await _database.query(
      'expense_images',
      columns: ['expense_id'],
    );
    return rows.map((row) => row['expense_id']! as String).toSet();
  }

  @override
  Future<int> imageStorageBytes() async =>
      Sqflite.firstIntValue(
        await _database.rawQuery(
          'SELECT COALESCE(SUM(size_bytes), 0) FROM ocr_images',
        ),
      ) ??
      0;

  @override
  Future<void> removeImageForExpense(String expenseId) async {
    await _database.transaction((transaction) async {
      await _removeImageLinks(transaction, expenseId);
    });
  }

  Future<void> _removeImageLinks(
    Transaction transaction,
    String expenseId,
  ) async {
    final links = await transaction.query(
      'expense_images',
      columns: ['image_id'],
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    await transaction.delete(
      'expense_images',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    for (final link in links) {
      await transaction.rawDelete(
        '''
        DELETE FROM ocr_images
        WHERE id = ? AND NOT EXISTS (
          SELECT 1 FROM expense_images WHERE image_id = ?
        )
      ''',
        [link['image_id'], link['image_id']],
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    await _database.transaction((transaction) async {
      await _removeImageLinks(transaction, id);
      await transaction.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<int> countByCategory(String category) async {
    return Sqflite.firstIntValue(
          await _database.rawQuery(
            '''
            SELECT COUNT(*) FROM expenses
            WHERE category_id = (
              SELECT id FROM categories WHERE name = ?
            )
            ''',
            [category],
          ),
        ) ??
        0;
  }

  @override
  Future<void> renameCategory(String oldName, String newName) {
    return _database.update(
      'expenses',
      {'category': newName},
      where: 'category_id = (SELECT id FROM categories WHERE name = ?)',
      whereArgs: [newName],
    );
  }

  @override
  Future<int> countByPaymentMethod(String paymentMethod) async =>
      Sqflite.firstIntValue(
        await _database.rawQuery(
          '''
          SELECT COUNT(*) FROM expenses
          WHERE payment_method_id = (
            SELECT id FROM payment_methods WHERE name = ?
          )
          ''',
          [paymentMethod],
        ),
      ) ??
      0;

  @override
  Future<void> renamePaymentMethod(
    String oldName,
    String newName,
  ) => _database.update(
    'expenses',
    {'payment_method': newName},
    where:
        'payment_method_id = (SELECT id FROM payment_methods WHERE name = ?)',
    whereArgs: [newName],
  );

  Map<String, Object?> _toRow(Expense expense, ReferenceIds references) {
    return {
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
      recurringRuleId: row['recurring_rule_id'] as String?,
      recurringOccurrence: row['recurring_occurrence_millis'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row['recurring_occurrence_millis']! as int,
            ),
      isTaxDeductible: (row['is_tax_deductible'] as int? ?? 0) == 1,
    );
  }
}

class ReferenceIds {
  const ReferenceIds({required this.categoryId, this.paymentMethodId});

  final String categoryId;
  final String? paymentMethodId;
}

Future<ReferenceIds> resolveReferenceIds(
  DatabaseExecutor database, {
  required String category,
  required String? paymentMethod,
}) async {
  final categoryRows = await database.query(
    'categories',
    columns: ['id'],
    where: 'name = ?',
    whereArgs: [category],
    limit: 1,
  );
  if (categoryRows.isEmpty) {
    throw StateError('The selected category no longer exists.');
  }

  String? paymentMethodId;
  if (paymentMethod != null) {
    final paymentRows = await database.query(
      'payment_methods',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [paymentMethod],
      limit: 1,
    );
    if (paymentRows.isEmpty) {
      throw StateError('The selected payment method no longer exists.');
    }
    paymentMethodId = paymentRows.single['id']! as String;
  }
  return ReferenceIds(
    categoryId: categoryRows.single['id']! as String,
    paymentMethodId: paymentMethodId,
  );
}

void _validateImageBatch(
  List<Expense> expenses,
  List<ExpenseImageAttachment> attachments,
) {
  final ids = expenses.map((expense) => expense.id).toSet();
  final linked = <String>{};
  for (final attachment in attachments) {
    final bytes = attachment.bytes;
    if (attachment.expenseIds.isEmpty ||
        bytes.length < 4 ||
        bytes.length > maxExpenseImageBytes ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[bytes.length - 2] != 0xff ||
        bytes.last != 0xd9) {
      throw const FormatException('The retained image is invalid.');
    }
    if (!ids.containsAll(attachment.expenseIds) ||
        linked.intersection(attachment.expenseIds).isNotEmpty) {
      throw ArgumentError(
        'Image links must reference distinct batch expenses.',
      );
    }
    linked.addAll(attachment.expenseIds);
  }
}
