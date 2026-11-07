import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/app_toast.dart';
import '../../categories/category_providers.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_providers.dart';
import '../../payment_methods/payment_method_providers.dart';
import '../../quick_entry/data/smart_quick_entry_parser.dart';
import '../../settings/currency_preference.dart';
import '../../settings/time_format_preference.dart';
import '../data/statement_row.dart';

/// Lets the user review the transactions read from a statement PDF, fix them,
/// and choose which ones to add as expenses.
class StatementReviewPage extends ConsumerStatefulWidget {
  const StatementReviewPage({
    super.key,
    required this.parsedRows,
    required this.sourceLabel,
    this.notice,
  });

  final List<StatementRow> parsedRows;
  final String sourceLabel;

  /// A warning about the extracted rows, shown above the review list.
  final String? notice;

  @override
  ConsumerState<StatementReviewPage> createState() =>
      _StatementReviewPageState();
}

class _StatementReviewPageState extends ConsumerState<StatementReviewPage> {
  final _rows = <_ReviewRow>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reviewParsed(widget.parsedRows);
    });
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  List<_ReviewRow> _reviewRows(List<StatementRow> parsed) {
    final categories = ref.read(categoriesProvider);
    final methods = ref.read(paymentMethodsProvider);
    final history = ref.read(expensesProvider);
    final smart = const SmartQuickEntryParser();
    return [
      for (final item in parsed)
        () {
          final suggestion = smart.parse(
            input: item.description,
            categories: categories,
            paymentMethods: methods,
            history: history,
          );
          return _ReviewRow(
            item,
            // Statement lines are rarely food by default, so an unmatched
            // merchant goes to Other for the user to review.
            category:
                suggestion.categorySource ==
                        QuickEntryCategorySource.defaultCategory &&
                    categories.contains('Other')
                ? 'Other'
                : categories.contains(suggestion.category)
                ? suggestion.category
                : categories.first,
            paymentMethod: suggestion.paymentMethod,
          );
        }(),
    ];
  }

  void _reviewParsed(List<StatementRow> parsed) {
    final next = _reviewRows(parsed);
    setState(() => _rows.addAll(next));
    if (next.isEmpty) {
      AppToast.showError(context, 'No transaction rows were found.');
    }
  }

  Future<void> _pickDate(_ReviewRow row) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: row.date ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (chosen == null || !mounted) return;
    // Keep the time already on the row; the picker only returns a date.
    final old = row.date;
    setState(
      () => row.date = DateTime(
        chosen.year,
        chosen.month,
        chosen.day,
        old?.hour ?? 12,
        old?.minute ?? 0,
        old?.second ?? 0,
      ),
    );
  }

  Future<void> _pickTime(_ReviewRow row, bool use24HourFormat) async {
    final base = row.date ?? DateTime.now();
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: use24HourFormat),
        child: child!,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      row.date = DateTime(
        base.year,
        base.month,
        base.day,
        chosen.hour,
        chosen.minute,
      );
      row.hasTime = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final selected = _rows.where((row) => row.selected).toList();
    if (selected.isEmpty) return;
    final expenses = <Expense>[];
    for (final row in selected) {
      final amount = parseAmountToCents(row.amount.text);
      if (amount == null ||
          amount <= 0 ||
          row.date == null ||
          row.description.text.trim().isEmpty) {
        AppToast.showError(
          context,
          'Each selected row needs a valid amount, date, and description.',
        );
        return;
      }
      expenses.add(
        Expense(
          id: const Uuid().v4(),
          amountCents: amount,
          category: row.category,
          merchantOrNote: row.description.text.trim(),
          paymentMethod: row.paymentMethod,
          occurredAt: row.date!,
          createdAt: DateTime.now(),
        ),
      );
    }
    final history = ref.read(expensesProvider);
    // Same day and amount is enough to warn: a statement describes a purchase
    // differently ("GRAB*A-123") from how it was typed by hand ("Grab").
    String duplicateKey(Expense expense) =>
        '${expense.occurredAt.year}-${expense.occurredAt.month}-${expense.occurredAt.day}|'
        '${expense.amountCents}';
    final seenInFile = <String>{};
    final duplicateCount = expenses.where((expense) {
      final key = duplicateKey(expense);
      final repeatedInFile = !seenInFile.add(key);
      return repeatedInFile || history.any((old) => duplicateKey(old) == key);
    }).length;
    if (duplicateCount > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Possible duplicates'),
          content: Text(
            '$duplicateCount selected row${duplicateCount == 1 ? '' : 's'} may already be in Expenses or repeated in this statement. Add anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Review again'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(expensesProvider.notifier).addAll(expenses);
      if (!mounted) return;
      AppToast.show(context, 'Added ${expenses.length} expenses');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'The selected transactions could not be saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final methods = ref.watch(paymentMethodsProvider);
    final currency = ref.watch(appCurrencyProvider);
    final use24HourFormat = ref
        .watch(timeFormatPreferenceProvider)
        .resolve(
          deviceUses24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
        );
    final selectedCount = _rows.where((row) => row.selected).length;
    return Scaffold(
      appBar: AppBar(title: Text('Import ${widget.sourceLabel} statement')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review every transaction from ${widget.sourceLabel} before adding it. iSpend does not convert currencies during import.',
            ),
            if (widget.notice != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.notice!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_rows.length} transactions · $selectedCount selected',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _rowCard(
                    _rows[index],
                    categories,
                    methods,
                    currency.code,
                    use24HourFormat,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: selectedCount == 0 || _saving ? null : _save,
                icon: const Icon(Icons.add),
                label: Text('Add selected ($selectedCount)'),
              ),
            ] else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _rowCard(
    _ReviewRow row,
    List<String> categories,
    List<String> methods,
    String currency,
    bool use24HourFormat,
  ) {
    final valid =
        (parseAmountToCents(row.amount.text) ?? 0) > 0 &&
        row.date != null &&
        row.description.text.trim().isNotEmpty;
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${widget.sourceLabel} row ${row.source.line} · ${row.description.text}',
              maxLines: 2,
            ),
            subtitle: Text(
              row.source.reason ?? 'Spending · review before adding',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            value: row.selected,
            // A ticked row that is not valid yet can always be unticked.
            onChanged: valid || row.selected
                ? (v) => setState(() => row.selected = v ?? false)
                : null,
          ),
          if (row.source.reason != null)
            Text(
              'Review required: ${row.source.reason}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: row.amount,
            decoration: InputDecoration(labelText: 'Amount ($currency)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: row.description,
            decoration: const InputDecoration(labelText: 'Description'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: row.category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => row.category = v);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: row.paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Not specified'),
              ),
              for (final method in methods)
                DropdownMenuItem<String?>(value: method, child: Text(method)),
            ],
            onChanged: (v) => setState(() => row.paymentMethod = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _pickDate(row),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  row.date == null
                      ? 'Choose date'
                      : '${row.date!.day}/${row.date!.month}/${row.date!.year}',
                ),
              ),
              TextButton.icon(
                onPressed: () => _pickTime(row, use24HourFormat),
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  row.hasTime && row.date != null
                      ? MaterialLocalizations.of(context).formatTimeOfDay(
                          TimeOfDay.fromDateTime(row.date!),
                          alwaysUse24HourFormat: use24HourFormat,
                        )
                      : 'Add time',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewRow {
  _ReviewRow(this.source, {required this.category, required this.paymentMethod})
    : amount = TextEditingController(
        text: source.amountCents == null
            ? ''
            : formatCents(source.amountCents!),
      ),
      description = TextEditingController(text: source.description),
      date = source.date,
      hasTime = source.hasTime,
      selected = source.selected;
  final StatementRow source;
  final TextEditingController amount;
  final TextEditingController description;
  DateTime? date;
  bool hasTime;
  String category;
  String? paymentMethod;
  bool selected;
  void dispose() {
    amount.dispose();
    description.dispose();
  }
}
