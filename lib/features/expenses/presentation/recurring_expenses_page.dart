import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/app_toast.dart';
import '../../categories/category_providers.dart';
import '../../payment_methods/payment_method_providers.dart';
import '../../settings/currency_preference.dart';
import '../../settings/time_format_preference.dart';
import '../data/recurring_expense.dart';
import '../expense_providers.dart';
import 'expense_entry_sheet.dart';

class RecurringExpensesPage extends ConsumerWidget {
  const RecurringExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringExpensesProvider).value ?? const [];
    final currency = ref.watch(appCurrencyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring expenses')),
      body: items.isEmpty
          ? const Center(child: Text('No recurring expenses yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.merchantOrNote ?? item.category,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatCurrencyCents(item.amountCents, currency)} · ${item.category}',
                        ),
                        if (item.paymentMethod != null)
                          Text('Payment: ${item.paymentMethod}'),
                        Text(
                          item.isActive
                              ? 'Next: ${_date(item.nextOccurrence)}'
                              : 'Stopped · last next date ${_date(item.nextOccurrence)}',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (item.isActive) ...[
                              TextButton(
                                onPressed: () => _edit(context, ref, item),
                                child: const Text('Edit schedule'),
                              ),
                              TextButton(
                                onPressed: () => _stop(context, ref, item),
                                child: const Text('Stop recurring'),
                              ),
                            ] else
                              FilledButton.tonal(
                                onPressed: () =>
                                    _reactivate(context, ref, item),
                                child: const Text('Reactivate recurring'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    RecurringExpense item,
  ) async {
    final timePreference = ref.read(timeFormatPreferenceProvider);
    final result = await showExpenseEntrySheet(
      context,
      use24HourFormat: timePreference.resolve(
        deviceUses24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
      ),
      categories: ref.read(categoriesProvider),
      paymentMethods: ref.read(paymentMethodsProvider),
      currency: ref.read(appCurrencyProvider),
      expense: item.draftExpense(),
      showRecurringOption: false,
      title: 'Edit recurring schedule',
      saveButtonLabel: 'Save schedule',
    );
    if (result == null) return;
    await ref
        .read(recurringExpenseRepositoryProvider)
        .updateSchedule(
          RecurringExpense(
            id: item.id,
            amountCents: result.expense.amountCents,
            category: result.expense.category,
            merchantOrNote: result.expense.merchantOrNote,
            paymentMethod: result.expense.paymentMethod,
            nextOccurrence: result.expense.occurredAt,
            createdAt: item.createdAt,
            isActive: item.isActive,
          ),
        );
    ref.invalidate(recurringExpensesProvider);
    ref.invalidate(dueRecurringExpensesProvider);
    await ref.read(expensesProvider.notifier).refresh();
    if (context.mounted) AppToast.show(context, 'Recurring schedule updated');
  }

  Future<void> _stop(
    BuildContext context,
    WidgetRef ref,
    RecurringExpense item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop recurring expense?'),
        content: const Text(
          'No more monthly drafts will be created. Existing expenses are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Stop recurring'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recurringExpenseRepositoryProvider).stop(item.id);
    ref.invalidate(recurringExpensesProvider);
    ref.invalidate(dueRecurringExpensesProvider);
    if (context.mounted) AppToast.show(context, 'Recurring expense stopped');
  }

  Future<void> _reactivate(
    BuildContext context,
    WidgetRef ref,
    RecurringExpense item,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initialDate = item.nextOccurrence.isBefore(today)
        ? today
        : item.nextOccurrence;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(today.year + 10),
      helpText: 'Choose next occurrence',
    );
    if (selectedDate == null) return;
    final nextOccurrence = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      item.nextOccurrence.hour,
      item.nextOccurrence.minute,
    );
    await ref
        .read(recurringExpenseRepositoryProvider)
        .reactivate(item.id, nextOccurrence);
    ref.invalidate(recurringExpensesProvider);
    ref.invalidate(dueRecurringExpensesProvider);
    if (context.mounted) {
      AppToast.show(context, 'Recurring expense reactivated');
    }
  }

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
