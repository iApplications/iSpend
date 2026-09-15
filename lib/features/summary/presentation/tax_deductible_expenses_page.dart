import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/icon_registry.dart';
import '../../categories/category_providers.dart';
import '../../expenses/data/expense_model.dart';

class TaxDeductibleExpensesPage extends ConsumerWidget {
  const TaxDeductibleExpensesPage({
    required this.expenses,
    required this.currency,
    required this.periodLabel,
    super.key,
  });
  final List<Expense> expenses;
  final AppCurrency currency;
  final String periodLabel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryIconKeys =
        ref.watch(categoryIconKeysProvider).value ?? const <String, String>{};
    final total = expenses.fold<int>(
      0,
      (sum, expense) => sum + expense.amountCents,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Tax-deductible expenses')),
      body: expenses.isEmpty
          ? Center(child: Text('No tagged expenses in $periodLabel.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${formatCurrencyCents(total, currency)} · ${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'} · $periodLabel',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                for (final expense in expenses) ...[
                  Builder(
                    builder: (context) {
                      final style = categoryIconStyleForKey(
                        categoryIconKeys[expense.category] ??
                            defaultCategoryIconKey(expense.category),
                      );
                      return Card(
                        child: ListTile(
                          leading: DecoratedBox(
                            decoration: BoxDecoration(
                              color: style.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(style.icon, color: style.color),
                            ),
                          ),
                          title: Text(
                            expense.merchantOrNote ?? expense.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${expense.category} · ${expense.occurredAt.day}/${expense.occurredAt.month}/${expense.occurredAt.year}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            formatCurrencyCents(expense.amountCents, currency),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}
