import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/quick_entry/data/smart_quick_entry_parser.dart';

void main() {
  const parser = SmartQuickEntryParser();
  const categories = ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];
  const methods = ['Cash', 'TNG eWallet'];

  SmartQuickEntryResult parse(
    String input, {
    List<Expense> history = const [],
  }) => parser.parse(
    input: input,
    categories: categories,
    paymentMethods: methods,
    history: history,
  );

  test('uses an explicitly typed category and payment method', () {
    final result = parse('food 8.20 cash');
    expect(result.amountCents, 820);
    expect(result.category, 'Food');
    expect(result.categorySource, QuickEntryCategorySource.explicit);
    expect(result.paymentMethod, 'Cash');
    expect(result.merchantOrNote, isNull);
  });

  test('prefers exact local history over keyword suggestions', () {
    final result = parse(
      'hokkien mee 8.20',
      history: [
        Expense(
          id: '1',
          amountCents: 900,
          category: 'Food',
          merchantOrNote: 'Hokkien mee',
          paymentMethod: 'TNG eWallet',
          occurredAt: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
    );
    expect(result.amountCents, 820);
    expect(result.merchantOrNote, 'hokkien mee');
    expect(result.category, 'Food');
    expect(result.categorySource, QuickEntryCategorySource.history);
    expect(result.paymentMethod, 'TNG eWallet');
  });

  test('uses safe local keyword suggestions when no history matches', () {
    final petrol = parse('petrol 50');
    expect(petrol.amountCents, 5000);
    expect(petrol.merchantOrNote, 'petrol');
    expect(petrol.category, 'Transport');
    expect(petrol.categorySource, QuickEntryCategorySource.keyword);

    final uniqlo = parse('uniqlo 129.90');
    expect(uniqlo.category, 'Shopping');
  });

  test(
    'falls back to the normal category without inventing a payment method',
    () {
      final result = parse('mystery shop 12');
      expect(result.category, 'Food');
      expect(result.categorySource, QuickEntryCategorySource.defaultCategory);
      expect(result.paymentMethod, isNull);
    },
  );
}
