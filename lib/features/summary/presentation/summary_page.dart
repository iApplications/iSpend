import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_surface.dart';
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
        ),
        const SizedBox(height: AppSpacing.xl),
        _Breakdown(
          title: 'Payment method breakdown',
          totals: _group(
            filteredExpenses,
            (expense) => expense.paymentMethod ?? 'No payment method',
          ),
          currency: currency,
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

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.totals,
    required this.currency,
  });
  final String title;
  final Map<String, int> totals;
  final AppCurrency currency;
  @override
  Widget build(BuildContext context) => AppSurface(
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
          for (final entry in totals.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              trailing: Text(
                formatCurrencyCents(entry.value, currency),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
      ],
    ),
  );
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
