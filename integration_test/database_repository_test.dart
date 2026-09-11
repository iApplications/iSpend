import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ispend/core/database/database.dart';
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
}
