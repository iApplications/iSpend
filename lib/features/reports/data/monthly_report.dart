import '../../expenses/data/expense_model.dart';

/// One category's spending in the chosen month compared with the month before.
class CategoryChange {
  const CategoryChange({
    required this.category,
    required this.currentCents,
    required this.previousCents,
  });

  final String category;
  final int currentCents;
  final int previousCents;

  int get deltaCents => currentCents - previousCents;

  /// Null when there was no spending last month, so a percentage is undefined.
  double? get percentChange =>
      previousCents == 0 ? null : deltaCents * 100 / previousCents;
}

class MonthTotal {
  const MonthTotal(this.month, this.totalCents);

  /// The first day of the month.
  final DateTime month;
  final int totalCents;
}

/// Spending for one calendar month, its category split, and how it compares
/// with the month before. It only restates the user's own entries.
class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.totalCents,
    required this.previousTotalCents,
    required this.categories,
    required this.trend,
  });

  final DateTime month;
  final int totalCents;
  final int previousTotalCents;

  /// Largest current spending first. Categories used only last month come
  /// last, with zero spending now.
  final List<CategoryChange> categories;

  /// The chosen month and the months before it, oldest first.
  final List<MonthTotal> trend;

  int get deltaCents => totalCents - previousTotalCents;

  double? get percentChange =>
      previousTotalCents == 0 ? null : deltaCents * 100 / previousTotalCents;

  /// [now] keeps expenses dated later than today out of every figure, like the
  /// rest of the app's totals.
  static MonthlyReport build(
    List<Expense> expenses, {
    required DateTime month,
    required DateTime now,
    int trendMonths = 6,
  }) {
    final first = DateTime(month.year, month.month);
    final previous = DateTime(first.year, first.month - 1);

    final counted = [
      for (final expense in expenses)
        if (!expense.occurredAt.isAfter(now)) expense,
    ];

    Map<String, int> byCategory(DateTime start) {
      final result = <String, int>{};
      for (final expense in counted) {
        if (expense.occurredAt.year == start.year &&
            expense.occurredAt.month == start.month) {
          result[expense.category] =
              (result[expense.category] ?? 0) + expense.amountCents;
        }
      }
      return result;
    }

    final current = byCategory(first);
    final before = byCategory(previous);
    int sum(Map<String, int> values) =>
        values.values.fold<int>(0, (a, b) => a + b);

    final names = {...current.keys, ...before.keys};
    final categories =
        [
          for (final name in names)
            CategoryChange(
              category: name,
              currentCents: current[name] ?? 0,
              previousCents: before[name] ?? 0,
            ),
        ]..sort((a, b) {
          final byCurrent = b.currentCents.compareTo(a.currentCents);
          return byCurrent != 0
              ? byCurrent
              : b.previousCents.compareTo(a.previousCents);
        });

    final trend = [
      for (var i = trendMonths - 1; i >= 0; i--)
        MonthTotal(
          DateTime(first.year, first.month - i),
          sum(byCategory(DateTime(first.year, first.month - i))),
        ),
    ];

    return MonthlyReport(
      month: first,
      totalCents: sum(current),
      previousTotalCents: sum(before),
      categories: categories,
      trend: trend,
    );
  }
}
