import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'quick_entry_template.dart';

abstract interface class QuickEntryTemplateRepository {
  Future<List<QuickEntryTemplate>> getAll();
  Future<void> save(QuickEntryTemplate template);
  Future<void> delete(String id);
  Future<void> reorder(List<String> orderedIds);
  Future<int> countByCategoryId(String categoryId);
  Future<int> countByPaymentMethodId(String paymentMethodId);
}

class InMemoryQuickEntryTemplateRepository
    implements QuickEntryTemplateRepository {
  final List<QuickEntryTemplate> _templates = [];

  @override
  Future<List<QuickEntryTemplate>> getAll() async {
    final result = List<QuickEntryTemplate>.of(_templates)
      ..sort((first, second) => first.sortOrder.compareTo(second.sortOrder));
    return result;
  }

  @override
  Future<void> save(QuickEntryTemplate template) async {
    final index = _templates.indexWhere((item) => item.id == template.id);
    if (index == -1) {
      _templates.add(template);
    } else {
      _templates[index] = template;
    }
  }

  @override
  Future<void> delete(String id) async =>
      _templates.removeWhere((template) => template.id == id);

  @override
  Future<void> reorder(List<String> orderedIds) async {
    for (var index = 0; index < orderedIds.length; index++) {
      final current = _templates.indexWhere(
        (item) => item.id == orderedIds[index],
      );
      if (current != -1) {
        _templates[current] = _templates[current].copyWith(sortOrder: index);
      }
    }
  }

  @override
  Future<int> countByCategoryId(String categoryId) async =>
      _templates.where((item) => item.categoryId == categoryId).length;

  @override
  Future<int> countByPaymentMethodId(String paymentMethodId) async => _templates
      .where((item) => item.paymentMethodId == paymentMethodId)
      .length;
}

class SqlCipherQuickEntryTemplateRepository
    implements QuickEntryTemplateRepository {
  const SqlCipherQuickEntryTemplateRepository(this._database);
  final Database _database;

  @override
  Future<List<QuickEntryTemplate>> getAll() async {
    final rows = await _database.query(
      'quick_entry_templates',
      orderBy: 'sort_order ASC, created_at_millis ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(QuickEntryTemplate template) => _database.insert(
    'quick_entry_templates',
    _toRow(template),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  @override
  Future<void> delete(String id) => _database.delete(
    'quick_entry_templates',
    where: 'id = ?',
    whereArgs: [id],
  );

  @override
  Future<void> reorder(List<String> orderedIds) =>
      _database.transaction((transaction) async {
        for (var index = 0; index < orderedIds.length; index++) {
          await transaction.update(
            'quick_entry_templates',
            {'sort_order': index},
            where: 'id = ?',
            whereArgs: [orderedIds[index]],
          );
        }
      });

  @override
  Future<int> countByCategoryId(String categoryId) =>
      _count('category_id = ?', [categoryId]);

  @override
  Future<int> countByPaymentMethodId(String paymentMethodId) =>
      _count('payment_method_id = ?', [paymentMethodId]);

  Future<int> _count(String where, List<Object?> whereArgs) async =>
      Sqflite.firstIntValue(
        await _database.rawQuery(
          'SELECT COUNT(*) FROM quick_entry_templates WHERE $where',
          whereArgs,
        ),
      ) ??
      0;

  QuickEntryTemplate _fromRow(Map<String, Object?> row) => QuickEntryTemplate(
    id: row['id']! as String,
    name: row['name']! as String,
    categoryId: row['category_id']! as String,
    paymentMethodId: row['payment_method_id'] as String?,
    merchantOrNote: row['merchant_or_note'] as String?,
    sortOrder: row['sort_order']! as int,
    isFavorite: (row['is_favorite']! as int) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at_millis']! as int,
    ),
  );

  Map<String, Object?> _toRow(QuickEntryTemplate template) => {
    'id': template.id,
    'name': template.name,
    'category_id': template.categoryId,
    'payment_method_id': template.paymentMethodId,
    'merchant_or_note': template.merchantOrNote,
    'sort_order': template.sortOrder,
    'is_favorite': template.isFavorite ? 1 : 0,
    'created_at_millis': template.createdAt.millisecondsSinceEpoch,
  };
}

QuickEntryTemplate newQuickEntryTemplate({
  required String name,
  required String categoryId,
  String? paymentMethodId,
  String? merchantOrNote,
  required int sortOrder,
}) => QuickEntryTemplate(
  id: const Uuid().v4(),
  name: name,
  categoryId: categoryId,
  paymentMethodId: paymentMethodId,
  merchantOrNote: merchantOrNote,
  sortOrder: sortOrder,
  createdAt: DateTime.now(),
);
