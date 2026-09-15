import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/widgets/app_toast.dart';
import '../../categories/category_providers.dart';
import '../../settings/currency_preference.dart';
import '../budget_providers.dart';

class BudgetLimitsPage extends ConsumerWidget {
  const BudgetLimitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final limits = ref.watch(budgetLimitsProvider);
    final currency = ref.watch(appCurrencyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Budget limits')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Set a monthly spending target for any category. Limits are for your own tracking.',
              ),
            );
          }
          final category = categories[index - 1];
          final limit = limits[category];
          return Card(
            child: ListTile(
              title: Text(category),
              subtitle: Text(
                limit == null
                    ? 'No monthly limit'
                    : 'Monthly limit: ${formatCurrencyCents(limit, currency)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _edit(context, ref, category, limit, currency),
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String category,
    int? currentLimit,
    AppCurrency currency,
  ) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _BudgetLimitDialog(
        category: category,
        currentLimit: currentLimit,
        currency: currency,
      ),
    );
    if (amount == null) return;
    if (amount == 0) {
      await ref.read(budgetLimitsProvider.notifier).clear(category);
      if (context.mounted) AppToast.show(context, 'Budget limit removed');
    } else {
      await ref.read(budgetLimitsProvider.notifier).set(category, amount);
      if (context.mounted) AppToast.show(context, 'Budget limit saved');
    }
  }
}

class _BudgetLimitDialog extends StatefulWidget {
  const _BudgetLimitDialog({
    required this.category,
    required this.currentLimit,
    required this.currency,
  });
  final String category;
  final int? currentLimit;
  final AppCurrency currency;

  @override
  State<_BudgetLimitDialog> createState() => _BudgetLimitDialogState();
}

class _BudgetLimitDialogState extends State<_BudgetLimitDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.currentLimit;
    _controller = TextEditingController(
      text: current == null ? '' : (current / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final cents = parseAmountToCents(_controller.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter a monthly amount greater than zero.');
      return;
    }
    Navigator.pop(context, cents);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.category} monthly limit'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Amount (${widget.currency.symbol})',
        errorText: _error,
      ),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      if (widget.currentLimit != null)
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: const Text('Remove limit'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save limit')),
    ],
  );
}
