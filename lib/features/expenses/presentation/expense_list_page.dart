import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/icon_registry.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../categories/category_providers.dart';
import '../../payment_methods/payment_method_providers.dart';
import '../../settings/time_format_preference.dart';
import '../../settings/currency_preference.dart';
import '../data/expense_model.dart';
import '../expense_providers.dart';
import 'expense_entry_sheet.dart';

class ExpenseListPage extends ConsumerWidget {
  const ExpenseListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final categories = ref.watch(categoriesProvider);
    final categoryIconKeys =
        ref.watch(categoryIconKeysProvider).value ?? const <String, String>{};
    final paymentMethods = ref.watch(paymentMethodsProvider);
    final currency = ref.watch(appCurrencyProvider);
    final timePreference = ref.watch(timeFormatPreferenceProvider);
    final use24HourFormat = timePreference.resolve(
      deviceUses24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final expensesByDay = _groupByDay(expenses);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final expense = await showExpenseEntrySheet(
            context,
            use24HourFormat: use24HourFormat,
            categories: categories,
            paymentMethods: paymentMethods,
            currency: currency,
          );
          if (expense != null) {
            await ref.read(expensesProvider.notifier).add(expense);
            if (!context.mounted) return;
            AppToast.show(context, 'Expense saved');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Padding(
        padding: AppSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expenses',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  '${currency.code} (${currency.symbol})',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SpendingContextCard(expenses: expenses, currency: currency),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: expenses.isEmpty
                  ? _EmptyExpenses()
                  : ListView(
                      children: [
                        for (final entry in expensesByDay.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                            child: Text(
                              _dateLabel(entry.key),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          for (final expense in entry.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Dismissible(
                                key: Key('expense-${expense.id}'),
                                direction: DismissDirection.endToStart,
                                background: const _DeleteBackground(),
                                confirmDismiss: (_) =>
                                    _confirmDelete(context, ref, expense),
                                onDismissed: (_) => ref
                                    .read(expensesProvider.notifier)
                                    .delete(expense.id),
                                child: _ExpenseRow(
                                  expense: expense,
                                  currency: currency,
                                  categoryIconKey:
                                      categoryIconKeys[expense.category],
                                  use24HourFormat: use24HourFormat,
                                  onEdit: () => _editExpense(
                                    context,
                                    ref,
                                    expense,
                                    use24HourFormat,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editExpense(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    bool use24HourFormat,
  ) async {
    final updatedExpense = await showExpenseEntrySheet(
      context,
      use24HourFormat: use24HourFormat,
      categories: ref.read(categoriesProvider),
      paymentMethods: ref.read(paymentMethodsProvider),
      currency: ref.read(appCurrencyProvider),
      expense: expense,
    );
    if (updatedExpense != null) {
      await ref.read(expensesProvider.notifier).add(updatedExpense);
      if (!context.mounted) return;
      AppToast.show(context, 'Expense updated');
    }
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This expense will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return shouldDelete ?? false;
  }

  Map<DateTime, List<Expense>> _groupByDay(List<Expense> expenses) {
    final groups = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final day = DateTime(
        expense.occurredAt.year,
        expense.occurredAt.month,
        expense.occurredAt.day,
      );
      (groups[day] ??= []).add(expense);
    }
    return groups;
  }

  String _dateLabel(DateTime date) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    if (date == todayDay) return 'Today';
    if (date == todayDay.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _EmptyExpenses extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No expenses yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your spending history will appear here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.currency,
    this.categoryIconKey,
    required this.use24HourFormat,
    required this.onEdit,
  });

  final Expense expense;
  final AppCurrency currency;
  final String? categoryIconKey;
  final bool use24HourFormat;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final categoryStyle = categoryIconKey == null
        ? categoryIconStyle(expense.category)
        : categoryIconStyleForKey(categoryIconKey!);
    final detailParts = <String>[
      if (expense.merchantOrNote != null) expense.category,
      if (expense.paymentMethod != null) expense.paymentMethod!,
    ];
    return Card(
      child: ListTile(
        onTap: onEdit,
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: categoryStyle.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(categoryStyle.icon, color: categoryStyle.color),
          ),
        ),
        title: Text(expense.merchantOrNote ?? expense.category),
        subtitle: detailParts.isEmpty ? null : Text(detailParts.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrencyCents(expense.amountCents, currency),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _formatTime(expense.occurredAt, use24HourFormat),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime, bool use24HourFormat) {
    if (!use24HourFormat) {
      final hourOfPeriod = dateTime.hour % 12;
      final hour = hourOfPeriod == 0 ? 12 : hourOfPeriod;
      final suffix = dateTime.hour < 12 ? 'AM' : 'PM';
      return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $suffix';
    }
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Align(
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    ),
  );
}

class _SpendingContextCard extends StatelessWidget {
  const _SpendingContextCard({required this.expenses, required this.currency});

  final List<Expense> expenses;
  final AppCurrency currency;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthTotal = _sumSince(monthStart);
    final todayTotal = _sumSince(DateTime(now.year, now.month, now.day));
    final weekTotal = _sumSince(
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
    );
    final monthName = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][now.month - 1];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$monthName spending',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrencyCents(monthTotal, currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ContextAmount(
                  label: 'Today',
                  amount: todayTotal,
                  currency: currency,
                ),
                _ContextAmount(
                  label: '7 days',
                  amount: weekTotal,
                  currency: currency,
                ),
                _ContextAmount(
                  label: 'This month',
                  amount: monthTotal,
                  currency: currency,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _sumSince(DateTime start) => expenses
      .where((expense) => !expense.occurredAt.isBefore(start))
      .fold(0, (total, expense) => total + expense.amountCents);
}

class _ContextAmount extends StatelessWidget {
  const _ContextAmount({
    required this.label,
    required this.amount,
    required this.currency,
  });

  final String label;
  final int amount;
  final AppCurrency currency;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrencyCents(amount, currency),
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
