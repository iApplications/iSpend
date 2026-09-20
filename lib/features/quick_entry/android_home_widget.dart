import 'package:home_widget/home_widget.dart';

import '../../core/utils/amount_formatter.dart';
import '../expenses/data/expense_model.dart';
import 'data/quick_entry_template.dart';

abstract final class AndroidHomeWidget {
  static Future<void> refresh(
    List<QuickEntryTemplate> templates, {
    required List<Expense> expenses,
    required AppCurrency currency,
    required bool hideFinancialDetails,
  }) async {
    final allFavorites = templates
        .where((template) => template.isFavorite)
        .toList();
    final favorites = allFavorites.take(3).toList();
    final now = DateTime.now();
    final todayTotal = expenses
        .where(
          (expense) =>
              expense.occurredAt.year == now.year &&
              expense.occurredAt.month == now.month &&
              expense.occurredAt.day == now.day,
        )
        .fold(0, (total, expense) => total + expense.amountCents);
    final latest = expenses.isEmpty
        ? null
        : expenses.reduce(
            (newest, expense) => expense.occurredAt.isAfter(newest.occurredAt)
                ? expense
                : newest,
          );
    await HomeWidget.saveWidgetData<String>(
      'widget_today_total',
      hideFinancialDetails
          ? 'Quick expense entry'
          : formatCurrencyCents(todayTotal, currency),
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_last_expense',
      hideFinancialDetails
          ? 'Unlock iSpend to view expense details'
          : latest == null
          ? 'No expenses yet'
          : '${latest.merchantOrNote ?? latest.category} · ${latest.category} · ${formatCurrencyCents(latest.amountCents, currency)}',
    );
    for (var index = 0; index < 3; index++) {
      await HomeWidget.saveWidgetData<String>(
        'quick_entry_favorite_${index + 1}',
        index < favorites.length ? favorites[index].name : '',
      );
      await HomeWidget.saveWidgetData<String>(
        'quick_entry_favorite_id_${index + 1}',
        index < favorites.length ? favorites[index].id : '',
      );
    }
    await HomeWidget.saveWidgetData<bool>(
      'quick_entry_has_more_favorites',
      allFavorites.length > favorites.length,
    );
    await HomeWidget.updateWidget(name: 'QuickEntryWidgetProvider');
  }
}
