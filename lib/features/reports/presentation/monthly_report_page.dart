import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/app_surface.dart';
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

String _arrow(int cents) => cents > 0
    ? '\u25B2 '
    : cents < 0
    ? '\u25BC '
    : '';

/// Up (more spending) and down (less spending) text colours; the arrow and
/// sign carry the meaning too, so colour is never the only signal.
Color _changeColor(BuildContext context, int cents) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (cents > 0) {
    return dark ? const Color(0xFFF4A77B) : const Color(0xFF9A3412);
  }
  if (cents < 0) {
    return dark ? const Color(0xFF7FD9A8) : const Color(0xFF0F6B45);
  }
  return Theme.of(context).colorScheme.onSurfaceVariant;
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
          _MonthSwitcher(
            label: _monthLabel(_month),
            onPrevious: () => _shift(-1),
            onNext: _isCurrentMonth ? null : () => _shift(1),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ReportHero(
            total: formatCurrencyCents(report.totalCents, currency),
            comparison: report.previousTotalCents == 0
                ? 'No spending recorded in $previousLabel to compare with.'
                : 'vs $previousLabel ${formatCurrencyCents(report.previousTotalCents, currency)}: '
                      '${_arrow(report.deltaCents)}${_signed(report.deltaCents, currency)} '
                      '(${_percent(report.percentChange)})',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By category', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (report.categories.isEmpty)
                  Text(
                    'No expenses in ${_monthLabel(_month)}.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  for (var i = 0; i < report.categories.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _CategoryRow(
                      item: report.categories[i],
                      share: report.totalCents == 0
                          ? 0
                          : report.categories[i].currentCents *
                                100 /
                                report.totalCents,
                      currency: currency,
                      iconKey: iconKeys[report.categories[i].category],
                      previousLabel: previousLabel,
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last ${report.trend.length} months',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final item in report.trend)
                  _TrendRow(
                    item: item,
                    fraction: largestMonth == 0
                        ? 0
                        : item.totalCents / largestMonth,
                    currency: currency,
                    highlight:
                        item.month.year == _month.year &&
                        item.month.month == _month.month,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.total, required this.comparison});

  final String total;
  final String comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              'Total spent',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                total,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              comparison,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
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
        ? 'New this month'
        : '${_arrow(item.deltaCents)}${_signed(item.deltaCents, currency)} (${_percent(item.percentChange)}) vs $previousLabel';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.category,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      formatCurrencyCents(item.currentCents, currency),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (share / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: change.isEmpty
                          ? const SizedBox.shrink()
                          : Text(
                              change,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _changeColor(context, item.deltaCents),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                    Text(
                      '${share.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall,
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
