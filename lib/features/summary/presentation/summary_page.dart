import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/grouped_list_card.dart';
import '../../../core/widgets/icon_registry.dart';
import '../../categories/category_providers.dart';
import '../../budgets/budget_providers.dart';
import '../../budgets/presentation/budget_limits_page.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_providers.dart';
import '../../payment_methods/payment_method_providers.dart';
import '../../settings/currency_preference.dart';
import '../../reports/presentation/monthly_report_page.dart';
import 'tax_deductible_expenses_page.dart';

class SummaryPage extends ConsumerStatefulWidget {
  const SummaryPage({super.key});
  @override
  ConsumerState<SummaryPage> createState() => _SummaryPageState();
}

enum _SummaryPeriod { today, last7Days, last30Days }

class _SummaryPageState extends ConsumerState<SummaryPage> {
  _SummaryPeriod _period = _SummaryPeriod.last30Days;

  /// A date the user chose. Otherwise the summary follows today's date, so it
  /// rolls over at midnight and at month end instead of freezing at launch.
  DateTime? _pickedDate;
  DateTime get _referenceDate => _pickedDate ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final now = _referenceDate;
    final currency = ref.watch(appCurrencyProvider);
    final budgetLimits = ref.watch(budgetLimitsProvider);
    final paymentMethodColours = ref.watch(paymentMethodColourKeysProvider);
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
        const SizedBox(height: AppSpacing.lg),
        _TotalsCard(
          currency: currency,
          periodLabel: periodLabel,
          total: _total(filteredExpenses, (_) => true),
          endingLabel: _endingLabel(now),
          expenseCount: filteredExpenses.length,
          onPickDate: _chooseReferenceDate,
          comparisonLabel: _comparisonLabel(
            expenses,
            now,
            filteredExpenses,
            currency,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TaxDeductibleCard(
                  expenses: filteredExpenses
                      .where((expense) => expense.isTaxDeductible)
                      .toList(),
                  currency: currency,
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
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(child: _MonthlyReportLink()),
            ],
          ),
        ),
        if (budgetLimits.isNotEmpty) ...[
          const _SectionLabel('Budgets'),
          AppSurface(
            child: _BudgetLimitsCard(
              limits: budgetLimits,
              expenses: expenses,
              referenceDate: now,
              currency: currency,
              categoryIconKeys: categoryIconKeys,
            ),
          ),
        ],
        const _SectionLabel('Where it went'),
        _Breakdown(
          title: 'Category breakdown',
          totals: _group(filteredExpenses, (expense) => expense.category),
          currency: currency,
          categoryIconKeys: categoryIconKeys,
          type: _BreakdownType.category,
        ),
        const SizedBox(height: AppSpacing.lg),
        _Breakdown(
          title: 'Payment method breakdown',
          totals: _group(
            filteredExpenses,
            (expense) => expense.paymentMethod ?? 'No payment method',
          ),
          currency: currency,
          type: _BreakdownType.paymentMethod,
          paymentMethodColours: paymentMethodColours,
        ),
      ],
    );
  }

  /// Spending against the equal stretch just before this period: yesterday for
  /// Today, otherwise the same number of days again.
  String _comparisonLabel(
    List<Expense> all,
    DateTime now,
    List<Expense> current,
    AppCurrency currency,
  ) {
    final days = switch (_period) {
      _SummaryPeriod.today => 1,
      _SummaryPeriod.last7Days => 7,
      _SummaryPeriod.last30Days => 30,
    };
    final previousEnd = DateTime(now.year, now.month, now.day - days);
    final previousTotal = _total(all, (d) => _includes(d, previousEnd));
    final currentTotal = _total(current, (_) => true);
    final noun = switch (_period) {
      _SummaryPeriod.today => 'yesterday',
      _SummaryPeriod.last7Days => 'previous 7 days',
      _SummaryPeriod.last30Days => 'previous 30 days',
    };
    if (previousTotal == 0) return 'No spending in the $noun to compare with';
    final delta = currentTotal - previousTotal;
    if (delta == 0) return 'Same as the $noun';
    final arrow = delta > 0 ? '\u25B2 +' : '\u25BC -';
    return '$arrow${formatCurrencyCents(delta.abs(), currency)} vs $noun';
  }

  static const _shortMonths = [
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

  String _endingLabel(DateTime date) =>
      'Ending ${date.day} ${_shortMonths[date.month - 1]} ${date.year}';

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
    if (selected != null) setState(() => _pickedDate = selected);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, AppSpacing.xl, 4, AppSpacing.sm),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );
}

/// A compact tile that opens another page: icon and name, a value line, and
/// a caption that says where it goes.
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.onTap,
    this.muted = false,
    this.valueIsAmount = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final VoidCallback onTap;
  final bool muted;
  final bool valueIsAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: muted ? scheme.onSurfaceVariant : scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: valueIsAmount
                    ? theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: muted ? scheme.onSurfaceVariant : null,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
              ),
              const Spacer(),
              const SizedBox(height: 8),
              Text(
                caption,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyReportLink extends StatelessWidget {
  const _MonthlyReportLink();

  @override
  Widget build(BuildContext context) => _LinkTile(
    icon: Icons.bar_chart_outlined,
    title: 'Monthly report',
    value: 'Change from last month',
    valueIsAmount: false,
    caption: 'Open \u203A',
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MonthlyReportPage())),
  );
}

class _TaxDeductibleCard extends StatelessWidget {
  const _TaxDeductibleCard({
    required this.expenses,
    required this.currency,
    required this.onView,
  });

  final List<Expense> expenses;
  final AppCurrency currency;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold<int>(
      0,
      (sum, expense) => sum + expense.amountCents,
    );
    return _LinkTile(
      icon: Icons.receipt_long_outlined,
      title: 'Tax-deductible',
      value: formatCurrencyCents(total, currency),
      muted: expenses.isEmpty,
      caption: expenses.isEmpty
          ? 'None tagged \u203A'
          : '${expenses.length} tagged \u203A',
      onTap: onView,
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.currency,
    required this.periodLabel,
    required this.total,
    required this.endingLabel,
    required this.expenseCount,
    required this.onPickDate,
    required this.comparisonLabel,
  });

  final AppCurrency currency;
  final String periodLabel;
  final int total;
  final String endingLabel;
  final int expenseCount;
  final VoidCallback onPickDate;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: Colors.white);
    Widget pill({required Widget child, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: child,
        ),
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: AppRadii.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              periodLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCurrencyCents(total, currency),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Semantics(
                  button: true,
                  label: 'Change period end date',
                  child: pill(
                    onTap: onPickDate,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$endingLabel \u00B7 $expenseCount '
                            '${expenseCount == 1 ? 'expense' : 'expenses'}',
                            style: labelStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pill(child: Text(comparisonLabel, style: labelStyle)),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
      ..sort((a, b) {
        final aPercentage = (totals[a.key] ?? 0) / a.value;
        final bPercentage = (totals[b.key] ?? 0) / b.value;
        final comparison = bPercentage.compareTo(aPercentage);
        return comparison != 0 ? comparison : a.key.compareTo(b.key);
      });
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly budgets', style: theme.textTheme.titleLarge),
                  Text(
                    '${_monthName(referenceDate.month)} ${referenceDate.year} \u00B7 calendar month',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _BudgetLimitRow(
            category: entries[i].key,
            spent: totals[entries[i].key] ?? 0,
            limit: entries[i].value,
            currency: currency,
            categoryIconKey: categoryIconKeys[entries[i].key],
          ),
        ],
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
    final theme = Theme.of(context);
    final difference = limit - spent;
    final isOverBudget = difference < 0;
    final style = categoryIconKey == null
        ? categoryIconStyle(category)
        : categoryIconStyleForKey(categoryIconKey!);
    final valueColor = isOverBudget
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final status = isOverBudget
        ? 'Over by ${formatCurrencyCents(-difference, currency)} \u00B7 limit ${formatCurrencyCents(limit, currency)}'
        : '${formatCurrencyCents(difference, currency)} left \u00B7 limit ${formatCurrencyCents(limit, currency)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: style.icon, color: style.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(category, style: theme.textTheme.titleSmall),
                    ),
                    Text(
                      formatCurrencyCents(spent, currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: AppRadii.pillBorder,
                  child: LinearProgressIndicator(
                    value: (spent / limit).clamp(0, 1),
                    minHeight: 6,
                    color: valueColor,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (isOverBudget) ...[
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: valueColor,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isOverBudget
                              ? valueColor
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isOverBudget ? FontWeight.w600 : null,
                        ),
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
}

enum _BreakdownType { category, paymentMethod }

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.totals,
    required this.currency,
    required this.type,
    this.categoryIconKeys = const {},
    this.paymentMethodColours = const {},
  });
  final String title;
  final Map<String, int> totals;
  final AppCurrency currency;
  final _BreakdownType type;
  final Map<String, String> categoryIconKeys;
  final Map<String, String> paymentMethodColours;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = totals.values.fold(0, (sum, amount) => sum + amount);
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (totals.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No expenses recorded yet.'),
            )
          else ...[
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < sortedEntries.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _BreakdownLegendRow(
                label: sortedEntries[i].key,
                amount: sortedEntries[i].value,
                total: total,
                currency: currency,
                type: type,
                categoryIconKey: categoryIconKeys[sortedEntries[i].key],
                paymentMethodColour: paymentMethodColours[sortedEntries[i].key],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BreakdownLegendRow extends StatelessWidget {
  const _BreakdownLegendRow({
    required this.label,
    required this.amount,
    required this.total,
    required this.currency,
    required this.type,
    this.categoryIconKey,
    this.paymentMethodColour,
  });

  final String label;
  final int amount;
  final int total;
  final AppCurrency currency;
  final _BreakdownType type;
  final String? categoryIconKey;
  final String? paymentMethodColour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = total == 0 ? 0.0 : amount / total;
    final percentLabel = '${(percentage * 100).round()}%';
    final color = _breakdownColor(
      label: label,
      type: type,
      categoryIconKey: categoryIconKey,
    );
    final badge = type == _BreakdownType.category
        ? (categoryIconKey == null
              ? categoryIconStyle(label)
              : categoryIconStyleForKey(categoryIconKey!))
        : paymentMethodIconStyle(label);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: badge.icon,
            color: badge.color,
            background: type == _BreakdownType.paymentMethod
                ? paymentMethodBadgeColor(
                    paymentMethodColour ?? 'default',
                    theme.brightness,
                    badge.color,
                  )
                : null,
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
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formatCurrencyCents(amount, currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // The bar only shows scale; the amount and percentage are text.
                ClipRRect(
                  borderRadius: AppRadii.pillBorder,
                  child: LinearProgressIndicator(
                    value: percentage.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    percentLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _breakdownColor({
  required String label,
  required _BreakdownType type,
  String? categoryIconKey,
}) {
  final style = type == _BreakdownType.category
      ? categoryIconKey == null
            ? categoryIconStyle(label)
            : categoryIconStyleForKey(categoryIconKey)
      : paymentMethodIconStyle(label);
  // The bar uses the strong icon colour, not the pale badge tint, so it stays
  // visible on both light and dark cards.
  return style.color;
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
