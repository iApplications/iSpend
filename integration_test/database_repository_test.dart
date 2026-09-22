import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ispend/core/database/database.dart';
import 'package:ispend/core/database/recovery_key.dart';
import 'package:ispend/features/backup/data/manual_backup_service.dart';
import 'package:ispend/features/categories/data/category_repository.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/data/recurring_expense_repository.dart';
import 'package:ispend/features/payment_methods/data/payment_method_repository.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLCipher persists icons and transactional renames', (
    tester,
  ) async {
    final path = '${await getDatabasesPath()}/ispend_integration_test.db';
    await deleteDatabase(path);
    final database = await ISpendDatabase.open(
      databasePath: path,
      databaseKey: 'integration-test-key-not-for-production',
    );
    final expenses = SqlCipherExpenseRepository(database.database);
    final categories = SqlCipherCategoryRepository(database.database);
    final methods = SqlCipherPaymentMethodRepository(database.database);
    final now = DateTime(2026, 1, 1);
    await expenses.save(
      Expense(
        id: 'test-1',
        amountCents: 500,
        category: 'Food',
        paymentMethod: 'Cash',
        occurredAt: now,
        createdAt: now,
      ),
    );

    expect((await categories.getIconKeys())['Food'], 'food');
    await categories.renameAndUpdateExpenses('Food', 'Meals');
    expect((await expenses.getAll()).single.category, 'Meals');
    await methods.renameAndUpdateExpenses('Cash', 'Wallet');
    expect((await expenses.getAll()).single.paymentMethod, 'Wallet');

    await database.database.close();
    await deleteDatabase(path);
  });

  testWidgets('SQLCipher keeps one recurring occurrence per schedule date', (
    tester,
  ) async {
    final path = '${await getDatabasesPath()}/ispend_recurring_test.db';
    await deleteDatabase(path);
    final database = await ISpendDatabase.open(
      databasePath: path,
      databaseKey: 'integration-test-key-not-for-production',
    );
    final expenses = SqlCipherExpenseRepository(database.database);
    final recurring = SqlCipherRecurringExpenseRepository(database.database);
    final original = Expense(
      id: 'rule-1',
      amountCents: 5500,
      category: 'Bills',
      occurredAt: DateTime(2026, 8, 10),
      createdAt: DateTime(2026, 8, 10),
    );
    final linked = await recurring.enableForExpense(original);
    final due = (await recurring.dueOnOrBefore(DateTime(2026, 9, 10))).single;
    final occurrence = Expense(
      id: 'occurrence-1',
      amountCents: 5500,
      category: 'Bills',
      occurredAt: DateTime(2026, 9, 10),
      createdAt: DateTime(2026, 9, 10),
    );

    expect(linked.recurringRuleId, due.id);
    expect(await recurring.confirm(due, occurrence), isTrue);
    expect(await recurring.confirm(due, occurrence), isFalse);

    final generated = (await expenses.getAll()).singleWhere(
      (expense) => expense.id == occurrence.id,
    );
    expect(generated.recurringRuleId, due.id);
    expect(generated.recurringOccurrence, due.nextOccurrence);

    final edited = Expense(
      id: generated.id,
      amountCents: generated.amountCents,
      category: 'Shopping',
      merchantOrNote: 'Updated subscription',
      paymentMethod: 'Credit Card',
      occurredAt: generated.occurredAt,
      createdAt: generated.createdAt,
      recurringRuleId: generated.recurringRuleId,
      recurringOccurrence: generated.recurringOccurrence,
    );
    await recurring.saveLinkedExpense(edited);
    final updatedSchedule = await recurring.getById(due.id);
    final linkedExpenses = (await expenses.getAll()).where(
      (expense) => expense.recurringRuleId == due.id,
    );
    expect(updatedSchedule!.merchantOrNote, 'Updated subscription');
    expect(updatedSchedule.category, 'Shopping');
    expect(updatedSchedule.paymentMethod, 'Credit Card');
    expect(
      linkedExpenses.every(
        (expense) => expense.merchantOrNote == 'Updated subscription',
      ),
      isTrue,
    );
    expect(
      linkedExpenses.every((expense) => expense.category == 'Shopping'),
      isTrue,
    );
    expect(
      linkedExpenses.every((expense) => expense.paymentMethod == 'Credit Card'),
      isTrue,
    );
    expect(
      updatedSchedule.draftExpense().merchantOrNote,
      'Updated subscription',
    );

    final resumedDate = DateTime(2026, 11, 10);
    await recurring.stop(due.id);
    await recurring.reactivate(due.id, resumedDate);
    final resumed = await recurring.getById(due.id);
    expect(resumed!.isActive, isTrue);
    expect(resumed.nextOccurrence, resumedDate);
    expect(await recurring.getAll(), hasLength(1));

    await database.database.close();
    await deleteDatabase(path);
  });

  testWidgets('version 7 migration links existing recurring source expenses', (
    tester,
  ) async {
    final path = '${await getDatabasesPath()}/ispend_recurring_migration.db';
    const password = 'integration-test-key-not-for-production';
    await deleteDatabase(path);
    final legacy = await openDatabase(
      path,
      password: password,
      version: 6,
      onCreate: (database, _) async {
        await database.execute('''
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
        await database.execute('''
          CREATE TABLE recurring_expenses (
            id TEXT PRIMARY KEY,
            amount_cents INTEGER NOT NULL,
            category TEXT NOT NULL,
            merchant_or_note TEXT,
            payment_method TEXT,
            next_occurrence_millis INTEGER NOT NULL,
            created_at_millis INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE categories (
            name TEXT PRIMARY KEY,
            icon_key TEXT NOT NULL,
            created_at_millis INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE payment_methods (
            name TEXT PRIMARY KEY,
            created_at_millis INTEGER NOT NULL
          )
        ''');
        await database.insert('categories', {
          'name': 'Bills',
          'icon_key': 'bills',
          'created_at_millis': DateTime(2026, 8, 10).millisecondsSinceEpoch,
        });
        await database.insert('expenses', {
          'id': 'legacy-rule',
          'amount_cents': 1200,
          'category': 'Bills',
          'occurred_at_millis': DateTime(2026, 8, 10).millisecondsSinceEpoch,
          'created_at_millis': DateTime(2026, 8, 10).millisecondsSinceEpoch,
        });
        await database.insert('recurring_expenses', {
          'id': 'legacy-rule',
          'amount_cents': 1200,
          'category': 'Bills',
          'next_occurrence_millis': DateTime(
            2026,
            9,
            10,
          ).millisecondsSinceEpoch,
          'created_at_millis': DateTime(2026, 8, 10).millisecondsSinceEpoch,
        });
      },
    );
    await legacy.close();

    final migrated = await ISpendDatabase.open(
      databasePath: path,
      databaseKey: password,
    );
    final expense = (await SqlCipherExpenseRepository(
      migrated.database,
    ).getAll()).single;
    final schedule = (await SqlCipherRecurringExpenseRepository(
      migrated.database,
    ).getAll()).single;

    expect(expense.recurringRuleId, 'legacy-rule');
    expect(expense.recurringOccurrence, isNull);
    expect(schedule.isActive, isTrue);

    await migrated.database.close();
    await deleteDatabase(path);
  });

  testWidgets('versions 5 through 8 upgrade to the current schema', (
    tester,
  ) async {
    const password = 'integration-test-key-not-for-production';
    for (final version in [5, 6, 7, 8]) {
      final path =
          '${await getDatabasesPath()}/ispend_schema_v${version}_test.db';
      await deleteDatabase(path);
      final legacy = await _openLegacyDatabase(
        path: path,
        password: password,
        version: version,
      );
      await legacy.close();

      final migrated = await ISpendDatabase.open(
        databasePath: path,
        databaseKey: password,
      );
      final expense = (await migrated.database.query('expenses')).single;
      expect(expense['id'], 'legacy-expense');
      expect(expense['category_id'], isNotNull);
      expect(expense['is_tax_deductible'], 0);
      expect(
        (await migrated.database.rawQuery(
          'PRAGMA table_info(expenses)',
        )).map((column) => column['name']),
        containsAll([
          'recurring_rule_id',
          'recurring_occurrence_millis',
          'is_tax_deductible',
        ]),
      );

      if (version >= 6) {
        final schedule = (await migrated.database.query(
          'recurring_expenses',
        )).single;
        expect(schedule['is_active'], 1);
        expect(schedule['is_tax_deductible'], 0);
        expect(schedule['anchor_day'], 31);
      }
      await migrated.database.close();
      await deleteDatabase(path);
    }
  });

  testWidgets('version 10 migration assigns stable IDs to every reference', (
    tester,
  ) async {
    const password = 'integration-test-key-not-for-production';
    final path = '${await getDatabasesPath()}/ispend_schema_v10_test.db';
    await deleteDatabase(path);
    final legacy = await openDatabase(
      path,
      password: password,
      version: 10,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY, amount_cents INTEGER NOT NULL,
            category TEXT NOT NULL, merchant_or_note TEXT,
            payment_method TEXT, occurred_at_millis INTEGER NOT NULL,
            created_at_millis INTEGER NOT NULL, recurring_rule_id TEXT,
            recurring_occurrence_millis INTEGER,
            is_tax_deductible INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await database.execute('''
          CREATE TABLE categories (
            name TEXT PRIMARY KEY, icon_key TEXT NOT NULL,
            created_at_millis INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE payment_methods (
            name TEXT PRIMARY KEY, created_at_millis INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE recurring_expenses (
            id TEXT PRIMARY KEY, amount_cents INTEGER NOT NULL,
            category TEXT NOT NULL, merchant_or_note TEXT,
            payment_method TEXT, next_occurrence_millis INTEGER NOT NULL,
            created_at_millis INTEGER NOT NULL, is_active INTEGER NOT NULL,
            is_tax_deductible INTEGER NOT NULL, anchor_day INTEGER NOT NULL
          )
        ''');
        await database.execute(
          'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        const createdAt = 1700000000000;
        await database.insert('categories', {
          'name': 'Food',
          'icon_key': 'food',
          'created_at_millis': createdAt,
        });
        await database.insert('payment_methods', {
          'name': 'Cash',
          'created_at_millis': createdAt,
        });
        await database.insert('expenses', {
          'id': 'expense-1',
          'amount_cents': 1200,
          'category': 'Food',
          'payment_method': 'Cash',
          'occurred_at_millis': createdAt,
          'created_at_millis': createdAt,
        });
        await database.insert('recurring_expenses', {
          'id': 'rule-1',
          'amount_cents': 1200,
          'category': 'Food',
          'payment_method': 'Cash',
          'next_occurrence_millis': createdAt,
          'created_at_millis': createdAt,
          'is_active': 1,
          'is_tax_deductible': 0,
          'anchor_day': 1,
        });
        await database.insert('app_settings', {
          'key': 'monthly_category_budget_limits_v1',
          'value': jsonEncode({'Food': 5000}),
        });
      },
    );
    await legacy.close();

    final migrated = await ISpendDatabase.open(
      databasePath: path,
      databaseKey: password,
    );
    final category = (await migrated.database.query('categories')).single;
    final method = (await migrated.database.query('payment_methods')).single;
    final expense = (await migrated.database.query('expenses')).single;
    final schedule = (await migrated.database.query(
      'recurring_expenses',
    )).single;
    final budget = (await migrated.database.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['monthly_category_budget_limits_v1'],
    )).single;

    expect(category['id'], isNotEmpty);
    expect(method['id'], isNotEmpty);
    expect(expense['category_id'], category['id']);
    expect(expense['payment_method_id'], method['id']);
    expect(schedule['category_id'], category['id']);
    expect(schedule['payment_method_id'], method['id']);
    expect(jsonDecode(budget['value']! as String), {category['id']: 5000});

    await migrated.database.close();
    await deleteDatabase(path);
  });

  testWidgets(
    'manual backup restores atomically including quick-entry configuration',
    (tester) async {
      final path = '${await getDatabasesPath()}/ispend_backup_test.db';
      await deleteDatabase(path);
      final opened = await ISpendDatabase.open(
        databasePath: path,
        databaseKey: 'backup-test-key',
      );
      final db = opened.database;
      final fake = _FakeRecoveryKeyService();
      final service = ManualBackupService(recoveryKeyService: fake);
      final foodId =
          (await db.query(
                'categories',
                columns: ['id'],
                where: 'name = ?',
                whereArgs: ['Food'],
              )).single['id']!
              as String;
      final cashId =
          (await db.query(
                'payment_methods',
                columns: ['id'],
                where: 'name = ?',
                whereArgs: ['Cash'],
              )).single['id']!
              as String;
      await db.insert('expenses', {
        'id': 'before',
        'amount_cents': 1234,
        'category': 'Food',
        'category_id': foodId,
        'occurred_at_millis': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'created_at_millis': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });
      await db.insert('quick_entry_templates', {
        'id': 'template-tealive',
        'name': 'Tealive',
        'category_id': foodId,
        'payment_method_id': cashId,
        'merchant_or_note': 'Tealive',
        'sort_order': 0,
        'is_favorite': 1,
        'created_at_millis': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });
      await db.insert('quick_entry_templates', {
        'id': 'template-lunch',
        'name': 'Lunch',
        'category_id': foodId,
        'payment_method_id': null,
        'merchant_or_note': 'Lunch',
        'sort_order': 1,
        'is_favorite': 0,
        'created_at_millis': DateTime(2026, 1, 2).millisecondsSinceEpoch,
      });
      for (final setting in {
        'app_lock_enabled': 'true',
        'quick_logging_without_unlock': 'true',
        'appearance_preference': 'dark',
        'locked_currency_code': 'MYR',
        'payment_method_colour_keys_v1': jsonEncode({cashId: 'teal'}),
      }.entries) {
        await db.insert('app_settings', {
          'key': setting.key,
          'value': setting.value,
        });
      }
      final backup = await service.export(database: db, passphrase: 'correct');
      await db.delete('expenses');
      await db.delete('quick_entry_templates');
      await db.delete('app_settings');
      await service.restore(
        database: db,
        document: backup,
        passphrase: 'correct',
      );
      expect((await db.query('expenses')).single['id'], 'before');
      final templates = await db.query(
        'quick_entry_templates',
        orderBy: 'sort_order ASC',
      );
      expect(templates.map((row) => row['id']), [
        'template-tealive',
        'template-lunch',
      ]);
      expect(templates.first['is_favorite'], 1);
      expect(templates.first['payment_method_id'], cashId);
      expect(templates.last['payment_method_id'], isNull);
      final restoredSettings = {
        for (final row in await db.query('app_settings'))
          row['key']! as String: row['value']! as String,
      };
      expect(restoredSettings['app_lock_enabled'], 'true');
      expect(restoredSettings['quick_logging_without_unlock'], 'true');
      expect(restoredSettings['appearance_preference'], 'dark');
      expect(restoredSettings['locked_currency_code'], 'MYR');
      expect(jsonDecode(restoredSettings['payment_method_colour_keys_v1']!), {
        cashId: 'teal',
      });

      fake.payload = base64UrlEncode(
        utf8.encode(
          jsonEncode({
            'expenses': [
              {
                'id': 'legacy-expense',
                'amount_cents': 500,
                'category': 'Food',
                'payment_method': 'Cash',
                'occurred_at_millis': 1700000000000,
                'created_at_millis': 1700000000000,
                'is_tax_deductible': 0,
              },
            ],
            'categories': [
              {
                'name': 'Food',
                'icon_key': 'food',
                'created_at_millis': 1700000000000,
              },
            ],
            'payment_methods': [
              {'name': 'Cash', 'created_at_millis': 1700000000000},
            ],
            'app_settings': [
              {
                'key': 'monthly_category_budget_limits_v1',
                'value': jsonEncode({'Food': 900}),
              },
            ],
            'recurring_expenses': [],
          }),
        ),
      );
      await service.restore(
        database: db,
        document: backup,
        passphrase: 'correct',
      );
      final restoredCategory = (await db.query('categories')).single;
      final restoredExpense = (await db.query('expenses')).single;
      expect(restoredExpense['category_id'], restoredCategory['id']);
      expect(restoredExpense['payment_method_id'], isNotNull);

      await expectLater(
        service.restore(database: db, document: backup, passphrase: 'wrong'),
        throwsA(isA<RecoveryPassphraseException>()),
      );
      expect((await db.query('expenses')).single['id'], 'legacy-expense');
      await expectLater(
        service.restore(database: db, document: '{bad', passphrase: 'correct'),
        throwsA(isA<FormatException>()),
      );

      fake.payload = base64UrlEncode(
        utf8.encode(
          jsonEncode({
            'expenses': [
              {'id': 'bad'},
            ],
            'categories': [],
            'payment_methods': [],
            'app_settings': [],
            'recurring_expenses': [],
          }),
        ),
      );
      await expectLater(
        service.restore(database: db, document: backup, passphrase: 'correct'),
        throwsA(anything),
      );
      expect((await db.query('expenses')).single['id'], 'legacy-expense');
      await db.close();
      await deleteDatabase(path);
    },
  );

  testWidgets('manual backup rejects a real AES-GCM-tampered document', (
    tester,
  ) async {
    final path = '${await getDatabasesPath()}/ispend_backup_tamper_test.db';
    await deleteDatabase(path);
    final opened = await ISpendDatabase.open(
      databasePath: path,
      databaseKey: 'backup-tamper-test-key',
    );
    final db = opened.database;
    const service = ManualBackupService();
    const passphrase = 'correct backup passphrase';
    final foodId = (await db.query(
      'categories',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: ['Food'],
    )).single['id'];
    await db.insert('expenses', {
      'id': 'original',
      'amount_cents': 1234,
      'category': 'Food',
      'category_id': foodId,
      'occurred_at_millis': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'created_at_millis': DateTime(2026, 1, 1).millisecondsSinceEpoch,
    });
    final document = await service.export(database: db, passphrase: passphrase);
    final root = jsonDecode(document) as Map<String, dynamic>;
    final encrypted = Map<String, dynamic>.from(
      root['encrypted_payload'] as Map<String, dynamic>,
    );
    final ciphertext = base64Url.decode(encrypted['ciphertext'] as String);
    ciphertext[ciphertext.length ~/ 2] ^= 1;
    encrypted['ciphertext'] = base64UrlEncode(ciphertext);
    root['encrypted_payload'] = encrypted;

    await expectLater(
      service.restore(
        database: db,
        document: jsonEncode(root),
        passphrase: passphrase,
      ),
      throwsA(isA<RecoveryPassphraseException>()),
    );
    expect((await db.query('expenses')).single['id'], 'original');
    await db.close();
    await deleteDatabase(path);
  });
}

Future<Database> _openLegacyDatabase({
  required String path,
  required String password,
  required int version,
}) {
  return openDatabase(
    path,
    password: password,
    version: version,
    onCreate: (database, _) async {
      final recurringColumns = version >= 7
          ? ', is_active INTEGER NOT NULL DEFAULT 1'
          : '';
      final expenseRecurringColumns = version >= 7
          ? ', recurring_rule_id TEXT, recurring_occurrence_millis INTEGER'
          : '';
      final taxColumn = version >= 8
          ? ', is_tax_deductible INTEGER NOT NULL DEFAULT 0'
          : '';
      await database.execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          amount_cents INTEGER NOT NULL,
          category TEXT NOT NULL,
          merchant_or_note TEXT,
          payment_method TEXT,
          occurred_at_millis INTEGER NOT NULL,
          created_at_millis INTEGER NOT NULL$expenseRecurringColumns$taxColumn
        )
      ''');
      await database.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE categories (
          name TEXT PRIMARY KEY,
          icon_key TEXT NOT NULL,
          created_at_millis INTEGER NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE payment_methods (
          name TEXT PRIMARY KEY,
          created_at_millis INTEGER NOT NULL
        )
      ''');
      await database.insert('categories', {
        'name': 'Bills',
        'icon_key': 'bills',
        'created_at_millis': DateTime(2026, 1, 31).millisecondsSinceEpoch,
      });
      if (version >= 6) {
        await database.execute('''
          CREATE TABLE recurring_expenses (
            id TEXT PRIMARY KEY,
            amount_cents INTEGER NOT NULL,
            category TEXT NOT NULL,
            merchant_or_note TEXT,
            payment_method TEXT,
            next_occurrence_millis INTEGER NOT NULL,
            created_at_millis INTEGER NOT NULL$recurringColumns
          )
        ''');
      }
      await database.insert('expenses', {
        'id': 'legacy-expense',
        'amount_cents': 1200,
        'category': 'Bills',
        'occurred_at_millis': DateTime(2026, 1, 31).millisecondsSinceEpoch,
        'created_at_millis': DateTime(2026, 1, 31).millisecondsSinceEpoch,
      });
      if (version >= 6) {
        await database.insert('recurring_expenses', {
          'id': 'legacy-expense',
          'amount_cents': 1200,
          'category': 'Bills',
          'next_occurrence_millis': DateTime(
            2026,
            2,
            28,
          ).millisecondsSinceEpoch,
          'created_at_millis': DateTime(2026, 1, 31).millisecondsSinceEpoch,
        });
      }
    },
  );
}

class _FakeRecoveryKeyService implements RecoveryKeyOperations {
  String? payload;
  final envelope = RecoveryKeyEnvelope(
    salt: Uint8List(16),
    nonce: Uint8List(12),
    ciphertext: Uint8List.fromList([1]),
  );

  @override
  Future<RecoveryKeyEnvelope> wrap({
    required String databaseKey,
    required String passphrase,
  }) async {
    payload = databaseKey;
    return envelope;
  }

  @override
  Future<String> unwrap({
    required RecoveryKeyEnvelope envelope,
    required String passphrase,
  }) async {
    if (passphrase != 'correct' || envelope.ciphertext.length != 1) {
      throw const RecoveryPassphraseException();
    }
    return payload!;
  }
}
