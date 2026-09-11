import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/data/recurring_expense.dart';
import 'package:ispend/features/expenses/data/recurring_expense_repository.dart';

void main() {
  test('standalone expense can enable one recurring schedule', () async {
    final expenses = InMemoryExpenseRepository();
    final recurring = InMemoryRecurringExpenseRepository(expenses);
    final original = _expense('original', DateTime(2026, 8, 10));

    final linked = await recurring.enableForExpense(original);

    expect(linked.recurringRuleId, original.id);
    expect(await recurring.getAll(), hasLength(1));
    await expectLater(
      recurring.enableForExpense(linked),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'confirmation links occurrence and is idempotent per due date',
    () async {
      final expenses = InMemoryExpenseRepository();
      final recurring = InMemoryRecurringExpenseRepository(expenses);
      await recurring.enableForExpense(
        _expense('original', DateTime(2026, 8, 10)),
      );
      final due = (await recurring.dueOnOrBefore(DateTime(2026, 9, 10))).single;
      final occurrence = _expense(
        'generated',
        DateTime(2026, 9, 10),
        description: 'Confirmed description',
      );

      expect(await recurring.confirm(due, occurrence), isTrue);
      expect(await recurring.confirm(due, occurrence), isFalse);
      expect(await recurring.dueOnOrBefore(DateTime(2026, 9, 10)), isEmpty);

      final generated = (await expenses.getAll()).singleWhere(
        (expense) => expense.id == 'generated',
      );
      expect(generated.recurringRuleId, due.id);
      expect(generated.recurringOccurrence, due.nextOccurrence);
      expect(
        (await expenses.getAll()).every(
          (expense) => expense.merchantOrNote == 'Confirmed description',
        ),
        isTrue,
      );
      expect(
        (await expenses.getAll()).where(
          (expense) =>
              expense.recurringRuleId == due.id &&
              expense.recurringOccurrence == due.nextOccurrence,
        ),
        hasLength(1),
      );
      await expectLater(
        recurring.enableForExpense(generated),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('editing linked series fields synchronizes the whole series', () async {
    final expenses = InMemoryExpenseRepository();
    final recurring = InMemoryRecurringExpenseRepository(expenses);
    final original = _expense(
      'original',
      DateTime(2026, 8, 10),
      description: 'Old description',
    );
    await recurring.enableForExpense(original);
    final september = (await recurring.dueOnOrBefore(
      DateTime(2026, 9, 10),
    )).single;
    await recurring.confirm(
      september,
      _expense(
        'september',
        DateTime(2026, 9, 10),
        description: 'Old description',
      ),
    );
    final savedSeptember = (await expenses.getAll()).singleWhere(
      (expense) => expense.id == 'september',
    );

    await recurring.saveLinkedExpense(
      _withSeriesFields(
        savedSeptember,
        category: 'Shopping',
        description: 'Updated description',
        paymentMethod: 'Credit Card',
      ),
    );

    final schedule = (await recurring.getAll()).single;
    final linkedExpenses = (await expenses.getAll()).where(
      (expense) => expense.recurringRuleId == schedule.id,
    );
    expect(schedule.merchantOrNote, 'Updated description');
    expect(schedule.category, 'Shopping');
    expect(schedule.paymentMethod, 'Credit Card');
    expect(linkedExpenses, hasLength(2));
    expect(
      linkedExpenses.every(
        (expense) => expense.merchantOrNote == 'Updated description',
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
    expect(schedule.draftExpense().merchantOrNote, 'Updated description');
    expect(schedule.draftExpense().category, 'Shopping');

    await recurring.saveLinkedExpense(
      _withSeriesFields(
        savedSeptember,
        category: 'Shopping',
        description: null,
        paymentMethod: 'Credit Card',
      ),
    );
    expect((await recurring.getAll()).single.merchantOrNote, isNull);
    expect(
      (await expenses.getAll()).every(
        (expense) => expense.merchantOrNote == null,
      ),
      isTrue,
    );
  });

  test(
    'a stopped schedule reactivates the same rule with a chosen next date',
    () async {
      final expenses = InMemoryExpenseRepository();
      final recurring = InMemoryRecurringExpenseRepository(expenses);
      await recurring.enableForExpense(
        _expense('original', DateTime(2026, 8, 10)),
      );
      final schedule = (await recurring.getAll()).single;

      await recurring.stop(schedule.id);
      expect((await recurring.getById(schedule.id))!.isActive, isFalse);
      expect(await recurring.dueOnOrBefore(DateTime(2030)), isEmpty);

      final nextDate = DateTime(2026, 12, 10, 9, 30);
      await recurring.reactivate(schedule.id, nextDate);

      final reactivated = (await recurring.getById(schedule.id))!;
      expect(reactivated.isActive, isTrue);
      expect(reactivated.nextOccurrence, nextDate);
      expect(await recurring.getAll(), hasLength(1));
      expect(
        await recurring.dueOnOrBefore(nextDate),
        contains(predicate<RecurringExpense>((item) => item.id == schedule.id)),
      );
    },
  );
}

Expense _expense(String id, DateTime occurredAt, {String? description}) =>
    Expense(
      id: id,
      amountCents: 2500,
      category: 'Food',
      merchantOrNote: description,
      paymentMethod: 'Cash',
      occurredAt: occurredAt,
      createdAt: occurredAt,
    );

Expense _withSeriesFields(
  Expense expense, {
  required String category,
  required String? description,
  required String? paymentMethod,
}) => Expense(
  id: expense.id,
  amountCents: expense.amountCents,
  category: category,
  merchantOrNote: description,
  paymentMethod: paymentMethod,
  occurredAt: expense.occurredAt,
  createdAt: expense.createdAt,
  recurringRuleId: expense.recurringRuleId,
  recurringOccurrence: expense.recurringOccurrence,
);
