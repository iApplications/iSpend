import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/icon_registry.dart';
import '../../categories/category_providers.dart';
import '../../expenses/expense_providers.dart';
import '../../settings/currency_preference.dart';
import '../data/monthly_report.dart';

const _monthNames = [
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
];

String _monthLabel(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

String _signed(int cents, AppCurrency currency) {
  if (cents == 0) return formatCurrencyCents(0, currency);
  return '${cents > 0 ? '+' : '-'}${formatCurrencyCents(cents.abs(), currency)}';
}

String _percent(double? value) {
  if (value == null) return 'new';
  final rounded = value.round();
  return '${rounded > 0 ? '+' : ''}$rounded%';
}

/// Spending for one month by category, compared with the month before, plus a
/// short run of month totals. Numbers come first; the bars only show scale.
class MonthlyReportPage extends ConsumerStatefulWidget {
  const MonthlyReportPage({super.key});

  @override
  ConsumerState<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends ConsumerState<MonthlyReportPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final currency = ref.watch(appCurrencyProvider);
    final iconKeys =
        ref.watch(categoryIconKeysProvider).value ?? const <String, String>{};
    final now = DateTime.now();
    final report = MonthlyReport.build(
      expenses,
      month: _month,
      now: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final theme = Theme.of(context);
    final previousLabel =
        _monthNames[DateTime(_month.year, _month.month - 1).month - 1];
    final largestMonth = report.trend.fold<int>(
      0,
      (best, item) => item.totalCents > best ? item.totalCents : best,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly report')),
      body: ListView(
        padding: AppSpacing.listScreen,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _monthLabel(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: _isCurrentMonth ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Total spent', style: theme.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            formatCurrencyCents(report.totalCents, currency),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            report.previousTotalCents == 0
                ? 'No spending recorded in $previousLabel to compare with.'
                : 'vs $previousLabel ${formatCurrencyCents(report.previousTotalCents, currency)}: '
                      '${_signed(report.deltaCents, currency)} '
                      '(${_percent(report.percentChange)})',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('By category', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (report.categories.isEmpty)
            Text(
              'No expenses in ${_monthLabel(_month)}.',
              style: theme.textTheme.bodyMedium,
            )
          else
            for (final item in report.categories)
              _CategoryRow(
                item: item,
                share: report.totalCents == 0
                    ? 0
                    : item.currentCents * 100 / report.totalCents,
                currency: currency,
                iconKey: iconKeys[item.category],
                previousLabel: previousLabel,
              ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Last ${report.trend.length} months',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in report.trend)
            _TrendRow(
              item: item,
              fraction: largestMonth == 0 ? 0 : item.totalCents / largestMonth,
              currency: currency,
              highlight:
                  item.month.year == _month.year &&
                  item.month.month == _month.month,
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.share,
    required this.currency,
    required this.iconKey,
    required this.previousLabel,
  });

  final CategoryChange item;
  final double share;
  final AppCurrency currency;
  final String? iconKey;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = categoryIconStyleForKey(
      iconKey ?? defaultCategoryIconKey(item.category),
    );
    final change = item.previousCents == 0 && item.currentCents == 0
        ? ''
        : item.previousCents == 0
        ? 'new this month'
        : '${_signed(item.deltaCents, currency)} (${_percent(item.percentChange)}) vs $previousLabel';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(style.icon, color: style.color, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.category, style: theme.textTheme.titleSmall),
                if (change.isNotEmpty)
                  Text(change, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrencyCents(item.currentCents, currency),
                style: theme.textTheme.titleSmall,
              ),
              Text(
                '${share.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.item,
    required this.fraction,
    required this.currency,
    required this.highlight,
  });

  final MonthTotal item;
  final double fraction;
  final AppCurrency currency;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '${_monthNames[item.month.month - 1].substring(0, 3)} '
              '${item.month.year % 100}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: highlight ? FontWeight.w700 : null,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0, 1),
                minHeight: 8,
                color: highlight ? scheme.primary : scheme.outline,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 96,
            child: Text(
              formatCurrencyCents(item.totalCents, currency),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: highlight ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
