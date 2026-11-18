import '../../guides/data/guide_catalog.dart';
import '../../guides/presentation/contextual_guide.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/grouped_list_card.dart';
import '../../../core/widgets/icon_registry.dart';
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
    final iconKeys =
        ref.watch(categoryIconKeysProvider).value ?? const <String, String>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring expenses')),
      body: GuidedBody(
        guideId: GuideIds.recurring,
        child: items.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  EmptyState(
                    icon: Icons.repeat_outlined,
                    title: 'Track bills that repeat',
                    message:
                        'Turn on Repeats monthly under More options when you add an expense. A draft appears each month for you to confirm.',
                    previewRows: 2,
                    previewLabel: 'Your schedules will look like this',
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  GroupedListCard(
                    children: [
                      for (final item in items)
                        _recurringTile(context, ref, item, currency, iconKeys),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _recurringTile(
    BuildContext context,
    WidgetRef ref,
    RecurringExpense item,
    AppCurrency currency,
    Map<String, String> iconKeys,
  ) {
    final theme = Theme.of(context);
    final style = categoryIconStyleForKey(
      iconKeys[item.category] ?? defaultCategoryIconKey(item.category),
    );
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: style.icon, color: style.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.merchantOrNote ?? item.category,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      formatCurrencyCents(item.amountCents, currency),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    item.category,
                    if (item.paymentMethod != null) item.paymentMethod!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: item.isActive
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        child: Text(
                          item.isActive ? 'Active' : 'Stopped',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: item.isActive
                                ? theme.colorScheme.onPrimaryContainer
                                : muted,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      item.isActive
                          ? 'Next: ${_date(item.nextOccurrence)}'
                          : 'Last due ${_date(item.nextOccurrence)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (item.isActive) ...[
                      OutlinedButton(
                        onPressed: () => _edit(context, ref, item),
                        child: const Text('Edit schedule'),
                      ),
                      OutlinedButton(
                        onPressed: () => _stop(context, ref, item),
                        child: const Text('Stop recurring'),
                      ),
                    ] else
                      FilledButton.tonal(
                        onPressed: () => _reactivate(context, ref, item),
                        child: const Text('Reactivate recurring'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            isTaxDeductible: result.expense.isTaxDeductible,
            nextOccurrence: result.expense.occurredAt,
            createdAt: item.createdAt,
            // The edited date is the new schedule; keep the day it repeats on.
            anchorDay: result.expense.occurredAt.day,
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
      builder: (_) => const ConfirmDeleteDialog(
        title: 'Stop recurring expense?',
        message:
            'No more monthly drafts will be created. Existing expenses are kept.',
        confirmLabel: 'Stop recurring',
        icon: Icons.stop_circle_outlined,
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
