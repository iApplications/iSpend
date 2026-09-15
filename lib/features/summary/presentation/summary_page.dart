import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/icon_registry.dart';
import '../../categories/category_providers.dart';
import '../../budgets/budget_providers.dart';
import '../../budgets/presentation/budget_limits_page.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_providers.dart';
import '../../settings/currency_preference.dart';
import 'tax_deductible_expenses_page.dart';

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
    final budgetLimits = ref.watch(budgetLimitsProvider);
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
        if (budgetLimits.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _BudgetLimitsCard(
            limits: budgetLimits,
            expenses: expenses,
            referenceDate: now,
            currency: currency,
            categoryIconKeys: categoryIconKeys,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _TaxDeductibleCard(
          expenses: filteredExpenses
              .where((expense) => expense.isTaxDeductible)
              .toList(),
          currency: currency,
          periodLabel: periodLabel,
          onView: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TaxDeductibleExpensesPage(
                expenses: filteredExpenses
                    .where((expense) => expense.isTaxDeductible)
                    .toList(),
                currency: currency,
                periodLabel: periodLabel,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _Breakdown(
          title: 'Category breakdown',
          totals: _group(filteredExpenses, (expense) => expense.category),
          currency: currency,
          categoryIconKeys: categoryIconKeys,
          type: _BreakdownType.category,
          useSurface: true,
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
          useSurface: false,
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

class _TaxDeductibleCard extends StatelessWidget {
  const _TaxDeductibleCard({
    required this.expenses,
    required this.currency,
    required this.periodLabel,
    required this.onView,
  });

  final List<Expense> expenses;
  final AppCurrency currency;
  final String periodLabel;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold<int>(
      0,
      (sum, expense) => sum + expense.amountCents,
    );
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax-deductible expenses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${expenses.length} tagged in $periodLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrencyCents(total, currency),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onView,
              child: const Text('View tagged expenses'),
            ),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: AppColors.heroGradient,
      borderRadius: AppRadii.cardBorder,
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$periodLabel spending',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrencyCents(total, currency),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BudgetLimitsCard extends StatelessWidget {
  const _BudgetLimitsCard({
    required this.limits,
    required this.expenses,
    required this.referenceDate,
    required this.currency,
    required this.categoryIconKeys,
  });

  final Map<String, int> limits;
  final List<Expense> expenses;
  final DateTime referenceDate;
  final AppCurrency currency;
  final Map<String, String> categoryIconKeys;

  @override
  Widget build(BuildContext context) {
    final monthlyExpenses = expenses
        .where(
          (expense) =>
              expense.occurredAt.year == referenceDate.year &&
              expense.occurredAt.month == referenceDate.month,
        )
        .toList();
    final totals = _group(monthlyExpenses, (expense) => expense.category);
    final entries = limits.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Monthly budgets',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BudgetLimitsPage(),
                ),
              ),
              child: const Text('Manage budgets >'),
            ),
          ],
        ),
        Text(
          '${_monthName(referenceDate.month)} ${referenceDate.year}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in entries)
          _BudgetLimitRow(
            category: entry.key,
            spent: totals[entry.key] ?? 0,
            limit: entry.value,
            currency: currency,
            categoryIconKey: categoryIconKeys[entry.key],
          ),
      ],
    );
  }
}

class _BudgetLimitRow extends StatelessWidget {
  const _BudgetLimitRow({
    required this.category,
    required this.spent,
    required this.limit,
    required this.currency,
    this.categoryIconKey,
  });

  final String category;
  final int spent;
  final int limit;
  final AppCurrency currency;
  final String? categoryIconKey;

  @override
  Widget build(BuildContext context) {
    final difference = limit - spent;
    final status = difference >= 0
        ? '${formatCurrencyCents(difference, currency)} remaining'
        : '${formatCurrencyCents(-difference, currency)} over budget';
    final style = categoryIconKey == null
        ? categoryIconStyle(category)
        : categoryIconStyleForKey(categoryIconKey!);
    final statusColor = difference < 0
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
              borderRadius: AppRadii.rowBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(style.icon, color: style.color, size: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${formatCurrencyCents(spent, currency)} of '
                  '${formatCurrencyCents(limit, currency)} used',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (spent / limit).clamp(0, 1),
                  minHeight: 4,
                  borderRadius: AppRadii.pillBorder,
                  color: difference < 0
                      ? Theme.of(context).colorScheme.error
                      : style.color,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _BreakdownType { category, paymentMethod }

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.totals,
    required this.currency,
    required this.type,
    this.categoryIconKeys = const {},
    required this.useSurface,
  });
  final String title;
  final Map<String, int> totals;
  final AppCurrency currency;
  final _BreakdownType type;
  final Map<String, String> categoryIconKeys;
  final bool useSurface;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = totals.values.fold(0, (sum, amount) => sum + amount);
    final content = Column(
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
    );
    return useSurface
        ? AppSurface(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: content,
          )
        : content;
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

String _monthName(int month) => const [
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
][month - 1];
