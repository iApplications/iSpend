import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/icon_registry.dart';
import '../../categories/category_providers.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_providers.dart';
import '../../settings/currency_preference.dart';

class SummaryPage extends ConsumerStatefulWidget {
  const SummaryPage({super.key});
  @override
  ConsumerState<SummaryPage> createState() => _SummaryPageState();
}

enum _SummaryPeriod { today, last7Days, last30Days }

class _SummaryPageState extends ConsumerState<SummaryPage> {
  _SummaryPeriod _period = _SummaryPeriod.last30Days;
  DateTime _referenceDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final now = _referenceDate;
    final currency = ref.watch(appCurrencyProvider);
    final categoryIconKeys =
        ref.watch(categoryIconKeysProvider).value ?? const <String, String>{};
    final filteredExpenses = expenses
        .where((expense) => _includes(expense.occurredAt, now))
        .toList();
    final periodLabel = switch (_period) {
      _SummaryPeriod.today => 'Today',
      _SummaryPeriod.last7Days => 'Last 7 days',
      _SummaryPeriod.last30Days => 'Last 30 days',
    };
    return ListView(
      padding: AppSpacing.listScreen,
      children: [
        Text('Summary', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        SegmentedButton<_SummaryPeriod>(
          segments: const [
            ButtonSegment(value: _SummaryPeriod.today, label: Text('Today')),
            ButtonSegment(
              value: _SummaryPeriod.last7Days,
              label: Text('7 days'),
            ),
            ButtonSegment(
              value: _SummaryPeriod.last30Days,
              label: Text('30 days'),
            ),
          ],
          selected: {_period},
          onSelectionChanged: (selection) =>
              setState(() => _period = selection.first),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: _chooseReferenceDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              'Period ending ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _TotalsCard(
          currency: currency,
          periodLabel: periodLabel,
          total: _total(filteredExpenses, (_) => true),
        ),
        const SizedBox(height: AppSpacing.xl),
        _Breakdown(
          title: 'Category breakdown',
          totals: _group(filteredExpenses, (expense) => expense.category),
          currency: currency,
          categoryIconKeys: categoryIconKeys,
          type: _BreakdownType.category,
        ),
        const SizedBox(height: AppSpacing.xl),
        _Breakdown(
          title: 'Payment method breakdown',
          totals: _group(
            filteredExpenses,
            (expense) => expense.paymentMethod ?? 'No payment method',
          ),
          currency: currency,
          type: _BreakdownType.paymentMethod,
        ),
      ],
    );
  }

  bool _includes(DateTime date, DateTime now) => switch (_period) {
    _SummaryPeriod.today => _sameDay(date, now),
    _SummaryPeriod.last7Days =>
      !date.isBefore(DateTime(now.year, now.month, now.day - 6)) &&
          !date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59)),
    _SummaryPeriod.last30Days =>
      !date.isBefore(DateTime(now.year, now.month, now.day - 29)) &&
          !date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59)),
  };

  Future<void> _chooseReferenceDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => _referenceDate = selected);
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.currency,
    required this.periodLabel,
    required this.total,
  });

  final AppCurrency currency;
  final String periodLabel;
  final int total;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spending', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          periodLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          formatCurrencyCents(total, currency),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    ),
  );
}

enum _BreakdownType { category, paymentMethod }

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.totals,
    required this.currency,
    required this.type,
    this.categoryIconKeys = const {},
  });
  final String title;
  final Map<String, int> totals;
  final AppCurrency currency;
  final _BreakdownType type;
  final Map<String, String> categoryIconKeys;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = totals.values.fold(0, (sum, amount) => sum + amount);
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (totals.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No expenses recorded yet.'),
            )
          else
            for (final entry in sortedEntries)
              _BreakdownRow(
                label: entry.key,
                amount: entry.value,
                total: total,
                currency: currency,
                type: type,
                categoryIconKey: categoryIconKeys[entry.key],
              ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.total,
    required this.currency,
    required this.type,
    this.categoryIconKey,
  });

  final String label;
  final int amount;
  final int total;
  final AppCurrency currency;
  final _BreakdownType type;
  final String? categoryIconKey;

  @override
  Widget build(BuildContext context) {
    final percentage = total == 0 ? 0.0 : amount / total;
    final percentLabel = '${(percentage * 100).round()}%';
    final isCategory = type == _BreakdownType.category;
    final categoryStyle = categoryIconKey == null
        ? categoryIconStyle(label)
        : categoryIconStyleForKey(categoryIconKey!);
    final accent = isCategory
        ? categoryStyle.color
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.72);
    final icon = isCategory ? categoryStyle.icon : _paymentMethodIcon(label);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isCategory ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: accent, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatCurrencyCents(amount, currency),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(99),
                        color: accent,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      percentLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

  IconData _paymentMethodIcon(String method) {
    final normalized = method.toLowerCase();
    if (normalized.contains('cash')) return Icons.payments_outlined;
    if (normalized.contains('card') || normalized.contains('visa')) {
      return Icons.credit_card_outlined;
    }
    if (normalized == 'no payment method') return Icons.help_outline;
    return Icons.account_balance_wallet_outlined;
  }
}

int _total(List<Expense> expenses, bool Function(DateTime) includes) => expenses
    .where((expense) => includes(expense.occurredAt))
    .fold(0, (total, expense) => total + expense.amountCents);
Map<String, int> _group(
  List<Expense> expenses,
  String Function(Expense) label,
) {
  final totals = <String, int>{};
  for (final expense in expenses) {
    final name = label(expense);
    totals[name] = (totals[name] ?? 0) + expense.amountCents;
  }
  return totals;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
