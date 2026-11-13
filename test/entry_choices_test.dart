import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/presentation/entry_choices.dart';

Expense _expense(String id, String? method, DateTime at) => Expense(
  id: id,
  amountCents: 100,
  category: 'Food',
  paymentMethod: method,
  occurredAt: at,
  createdAt: at,
);

void main() {
  const available = ['Cash', 'TNG eWallet', 'Maybank', 'CIMB', 'Boost'];

  test('offers the three most recently used methods, newest first', () {
    final history = [
      _expense('a', 'Cash', DateTime(2026, 9, 1)),
      _expense('b', 'Maybank', DateTime(2026, 9, 5)),
      _expense('c', 'Maybank', DateTime(2026, 9, 4)),
      _expense('d', 'CIMB', DateTime(2026, 9, 3)),
      _expense('e', 'Boost', DateTime(2026, 8, 1)),
    ];
    expect(recentPaymentMethods(history: history, available: available), [
      'Maybank',
      'CIMB',
      'Cash',
    ]);
  });

  test('keeps the selected method visible even if it is not recent', () {
    final history = [_expense('a', 'Cash', DateTime(2026, 9, 1))];
    expect(
      recentPaymentMethods(
        history: history,
        available: available,
        selected: 'Boost',
      ),
      ['Boost', 'Cash'],
    );
  });

  test('falls back to the first configured methods with no history', () {
    expect(recentPaymentMethods(history: const [], available: available), [
      'Cash',
      'TNG eWallet',
      'Maybank',
    ]);
  });

  test('ignores history for methods that no longer exist', () {
    final history = [_expense('a', 'Old bank', DateTime(2026, 9, 1))];
    expect(recentPaymentMethods(history: history, available: available), [
      'Cash',
      'TNG eWallet',
      'Maybank',
    ]);
  });
}
