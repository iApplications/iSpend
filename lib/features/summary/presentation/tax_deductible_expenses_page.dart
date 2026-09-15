import 'package:flutter/material.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../expenses/data/expense_model.dart';

class TaxDeductibleExpensesPage extends StatelessWidget {
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tax-deductible expenses')),
    body: expenses.isEmpty
        ? Center(child: Text('No tagged expenses in $periodLabel.'))
        : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: expenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final expense = expenses[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(expense.merchantOrNote ?? expense.category),
                  subtitle: Text(
                    '${expense.category} · ${expense.occurredAt.day}/${expense.occurredAt.month}/${expense.occurredAt.year}',
                  ),
                  trailing: Text(
                    formatCurrencyCents(expense.amountCents, currency),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
            },
          ),
  );
}
