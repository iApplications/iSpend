import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/categories/data/category_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('copyWith preserves optional fields when they are not replaced', () {
    final expense = Expense(
      id: 'expense-1',
      amountCents: 1234,
      category: 'Food',
      occurredAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      merchantOrNote: 'Cafe',
      paymentMethod: 'Cash',
    );

    final updated = expense.copyWith(amountCents: 2500);

    expect(updated.amountCents, 2500);
    expect(updated.merchantOrNote, 'Cafe');
    expect(updated.paymentMethod, 'Cash');
  });

  test('UUID v4 creates distinct expense identifiers', () {
    final uuid = const Uuid();
    final identifiers = {for (var index = 0; index < 1000; index++) uuid.v4()};

    expect(identifiers, hasLength(1000));
  });

  test('renaming an in-memory category preserves its icon key', () async {
    final repository = InMemoryCategoryRepository();

    await repository.rename('Food', 'Meals');

    expect((await repository.getIconKeys())['Meals'], 'food');
  });
}
