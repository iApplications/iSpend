import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/icon_registry.dart';
import '../../categories/category_providers.dart';
import '../../settings/time_format_preference.dart';
import '../data/expense_model.dart';
import '../expense_providers.dart';
import 'expense_entry_sheet.dart';

class ExpenseListPage extends ConsumerWidget {
  const ExpenseListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final categories = ref.watch(categoriesProvider);
    final currency = AppCurrency.fromLocale(Localizations.localeOf(context));
    final timePreference = ref.watch(timeFormatPreferenceProvider);
    final use24HourFormat = timePreference.resolve(
      deviceUses24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final expense = await showExpenseEntrySheet(
            context,
            use24HourFormat: use24HourFormat,
            categories: categories,
          );
          if (expense != null) {
            await ref.read(expensesProvider.notifier).add(expense);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
            const SizedBox(height: 24),
            Expanded(
              child: expenses.isEmpty
                  ? _EmptyExpenses()
                  : ListView.separated(
                      itemCount: expenses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _ExpenseRow(
                        expense: expenses[index],
                        currency: currency,
                        use24HourFormat: use24HourFormat,
                        onEdit: () => _editExpense(
                          context,
                          ref,
                          expenses[index],
                          use24HourFormat,
                        ),
                        onDelete: () =>
                            _confirmDelete(context, ref, expenses[index]),
                      ),
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
      expense: expense,
    );
    if (updatedExpense != null) {
      await ref.read(expensesProvider.notifier).add(updatedExpense);
    }
  }

  Future<void> _confirmDelete(
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
    if (shouldDelete == true) {
      await ref.read(expensesProvider.notifier).delete(expense.id);
    }
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
            'Your recorded expenses will appear here.',
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
    required this.use24HourFormat,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final AppCurrency currency;
  final bool use24HourFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final categoryStyle = categoryIconStyle(expense.category);
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
            IconButton(
              tooltip: 'Delete expense',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
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
