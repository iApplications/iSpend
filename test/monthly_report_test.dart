import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/reports/data/monthly_report.dart';

Expense _e(String category, int cents, DateTime at) => Expense(
  id: '$category$cents${at.millisecondsSinceEpoch}',
  amountCents: cents,
  category: category,
  occurredAt: at,
  createdAt: at,
);

void main() {
  final now = DateTime(2026, 10, 20, 23, 59);

  test('splits the month by category and compares with the month before', () {
    final report = MonthlyReport.build(
      [
        _e('Food', 3000, DateTime(2026, 10, 3)),
        _e('Food', 2000, DateTime(2026, 10, 9)),
        _e('Transport', 1000, DateTime(2026, 10, 5)),
        _e('Food', 4000, DateTime(2026, 9, 12)),
        _e('Bills', 6000, DateTime(2026, 9, 1)),
      ],
      month: DateTime(2026, 10, 15),
      now: now,
    );
    expect(report.totalCents, 6000);
    expect(report.previousTotalCents, 10000);
    expect(report.deltaCents, -4000);
    expect(report.percentChange, -40);
    expect(report.categories.map((c) => c.category), [
      'Food',
      'Transport',
      'Bills',
    ]);
    final food = report.categories.first;
    expect(food.currentCents, 5000);
    expect(food.previousCents, 4000);
    expect(food.percentChange, 25);
    final transport = report.categories[1];
    expect(transport.percentChange, isNull);
    final bills = report.categories.last;
    expect(bills.currentCents, 0);
    expect(bills.deltaCents, -6000);
  });

  test('leaves out expenses dated after today', () {
    final report = MonthlyReport.build(
      [
        _e('Food', 1000, DateTime(2026, 10, 19)),
        _e('Food', 9999, DateTime(2026, 10, 28)),
      ],
      month: DateTime(2026, 10),
      now: now,
    );
    expect(report.totalCents, 1000);
  });

  test('trend lists the chosen month last and crosses a year boundary', () {
    final report = MonthlyReport.build(
      [
        _e('Food', 100, DateTime(2025, 12, 5)),
        _e('Food', 200, DateTime(2026, 1, 5)),
        _e('Food', 300, DateTime(2026, 2, 5)),
      ],
      month: DateTime(2026, 2),
      now: now,
      trendMonths: 3,
    );
    expect(report.trend.map((m) => m.month), [
      DateTime(2025, 12),
      DateTime(2026, 1),
      DateTime(2026, 2),
    ]);
    expect(report.trend.map((m) => m.totalCents), [100, 200, 300]);
    expect(report.previousTotalCents, 200);
  });

  test('an empty month has no percentage to show', () {
    final report = MonthlyReport.build(
      const [],
      month: DateTime(2026, 10),
      now: now,
    );
    expect(report.totalCents, 0);
    expect(report.categories, isEmpty);
    expect(report.percentChange, isNull);
  });
}
