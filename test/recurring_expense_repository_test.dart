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
      expect(reactivated.anchorDay, 10);
      expect(await recurring.getAll(), hasLength(1));
      expect(
        await recurring.dueOnOrBefore(nextDate),
        contains(predicate<RecurringExpense>((item) => item.id == schedule.id)),
      );
    },
  );

  test(
    'tax setting can update only the current recurring occurrence',
    () async {
      final expenses = InMemoryExpenseRepository();
      final recurring = InMemoryRecurringExpenseRepository(expenses);
      await recurring.enableForExpense(_expense('june', DateTime(2026, 6, 10)));
      final julySchedule = (await recurring.getAll()).single;
      await recurring.confirm(
        julySchedule,
        _expense('july', DateTime(2026, 7, 10)),
      );
      final july = (await expenses.getAll()).singleWhere(
        (item) => item.id == 'july',
      );

      await recurring.saveLinkedExpense(
        july.copyWith(isTaxDeductible: true),
        updateTaxDefault: false,
      );

      expect(
        (await expenses.getAll())
            .singleWhere((item) => item.id == 'june')
            .isTaxDeductible,
        isFalse,
      );
      expect(
        (await expenses.getAll())
            .singleWhere((item) => item.id == 'july')
            .isTaxDeductible,
        isTrue,
      );
      expect((await recurring.getAll()).single.isTaxDeductible, isFalse);
      expect(
        (await recurring.getAll()).single.draftExpense().isTaxDeductible,
        isFalse,
      );
    },
  );

  test(
    'tax setting updates future recurring default without changing past',
    () async {
      final expenses = InMemoryExpenseRepository();
      final recurring = InMemoryRecurringExpenseRepository(expenses);
      await recurring.enableForExpense(_expense('june', DateTime(2026, 6, 10)));
      final julySchedule = (await recurring.getAll()).single;
      await recurring.confirm(
        julySchedule,
        _expense('july', DateTime(2026, 7, 10)),
      );
      final july = (await expenses.getAll()).singleWhere(
        (item) => item.id == 'july',
      );

      await recurring.saveLinkedExpense(july.copyWith(isTaxDeductible: true));
      final augustSchedule = (await recurring.getAll()).single;
      expect(
        (await expenses.getAll())
            .singleWhere((item) => item.id == 'june')
            .isTaxDeductible,
        isFalse,
      );
      expect(augustSchedule.draftExpense().isTaxDeductible, isTrue);

      await recurring.confirm(
        augustSchedule,
        _expense(
          'august',
          augustSchedule.nextOccurrence,
        ).copyWith(isTaxDeductible: augustSchedule.isTaxDeductible),
      );
      final august = (await expenses.getAll()).singleWhere(
        (item) => item.recurringOccurrence == augustSchedule.nextOccurrence,
      );
      expect(august.isTaxDeductible, isTrue);
      await recurring.saveLinkedExpense(
        august.copyWith(isTaxDeductible: false),
      );
      expect(
        (await recurring.getAll()).single.draftExpense().isTaxDeductible,
        isFalse,
      );
      expect(
        (await expenses.getAll())
            .singleWhere((item) => item.id == 'july')
            .isTaxDeductible,
        isTrue,
      );
    },
  );

  test('monthly occurrence retains its original anchor day', () {
    expect(
      nextMonthlyOccurrence(DateTime(2026, 1, 28), 28),
      DateTime(2026, 2, 28),
    );
    expect(
      nextMonthlyOccurrence(DateTime(2026, 1, 29), 29),
      DateTime(2026, 2, 28),
    );
    expect(
      nextMonthlyOccurrence(DateTime(2026, 1, 30), 30),
      DateTime(2026, 2, 28),
    );
    expect(
      nextMonthlyOccurrence(DateTime(2026, 1, 31), 31),
      DateTime(2026, 2, 28),
    );
    expect(
      nextMonthlyOccurrence(DateTime(2024, 1, 31), 31),
      DateTime(2024, 2, 29),
    );
    expect(
      nextMonthlyOccurrence(DateTime(2026, 2, 28), 31),
      DateTime(2026, 3, 31),
    );
    expect(
      nextMonthlyOccurrence(DateTime(2026, 12, 31), 31),
      DateTime(2027, 1, 31),
    );
  });
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
