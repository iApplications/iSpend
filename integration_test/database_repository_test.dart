import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ispend/core/database/database.dart';
import 'package:ispend/features/categories/data/category_repository.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
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
}
