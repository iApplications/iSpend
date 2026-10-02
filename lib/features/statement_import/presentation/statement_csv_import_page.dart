import 'dart:convert';

import 'package:file_picker/file_picker.dart';
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
import '../data/statement_csv_parser.dart';

class StatementCsvImportPage extends ConsumerStatefulWidget {
  const StatementCsvImportPage({super.key});

  @override
  ConsumerState<StatementCsvImportPage> createState() =>
      _StatementCsvImportPageState();
}

class _StatementCsvImportPageState
    extends ConsumerState<StatementCsvImportPage> {
  final _parser = const StatementCsvParser();
  List<List<String>> _table = const [];
  final _rows = <_CsvReviewRow>[];
  StatementAmountMode _mode = StatementAmountMode.debitCredit;
  StatementDateFormat _dateFormat = StatementDateFormat.dayMonthYear;
  int? _dateColumn;
  int? _descriptionColumn;
  int? _amountColumn;
  int? _debitColumn;
  int? _creditColumn;
  bool _saving = false;
  String? _fileName;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (files.isEmpty || !mounted) return;
    try {
      if (await files.first.length() > 10 * 1024 * 1024) {
        throw const FormatException('CSV is larger than 10 MB.');
      }
      final data = await files.first.xFile.readAsBytes();
      final table = _parser.read(utf8.decode(data, allowMalformed: false));
      if (!mounted) return;
      final headers = table.first.map((cell) => cell.toLowerCase()).toList();
      int? find(List<String> words) {
        final index = headers.indexWhere(
          (header) => words.any(header.contains),
        );
        return index < 0 ? null : index;
      }

      _clearRows();
      setState(() {
        _table = table;
        _fileName = files.first.name;
        _dateColumn = find(['date', 'tarikh']);
        _descriptionColumn = find([
          'description',
          'merchant',
          'details',
          'narrative',
        ]);
        _debitColumn = find(['debit', 'withdrawal']);
        _creditColumn = find(['credit', 'deposit']);
        _amountColumn = find(['amount', 'jumlah']);
        _mode = _debitColumn != null && _creditColumn != null
            ? StatementAmountMode.debitCredit
            : StatementAmountMode.unsigned;
      });
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Could not read this CSV. Export it as a UTF-8 CSV and try again.',
        );
      }
    }
  }

  void _clearRows() {
    final old = List<_CsvReviewRow>.of(_rows);
    _rows.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in old) {
        row.dispose();
      }
    });
  }

  void _review() {
    if (_dateColumn == null ||
        _descriptionColumn == null ||
        (_mode == StatementAmountMode.debitCredit
            ? _debitColumn == null || _creditColumn == null
            : _amountColumn == null)) {
      AppToast.showError(
        context,
        'Map the date, description, and amount columns first.',
      );
      return;
    }
    try {
      final parsed = _parser.parse(
        _table,
        StatementColumnMapping(
          date: _dateColumn!,
          description: _descriptionColumn!,
          amount: _amountColumn,
          debit: _debitColumn,
          credit: _creditColumn,
          amountMode: _mode,
          dateFormat: _dateFormat,
        ),
      );
      final categories = ref.read(categoriesProvider);
      final methods = ref.read(paymentMethodsProvider);
      final history = ref.read(expensesProvider);
      final smart = const SmartQuickEntryParser();
      final next = <_CsvReviewRow>[];
      for (final item in parsed) {
        final suggestion = smart.parse(
          input: item.description,
          categories: categories,
          paymentMethods: methods,
          history: history,
        );
        next.add(
          _CsvReviewRow(
            item,
            category: categories.contains(suggestion.category)
                ? suggestion.category
                : categories.first,
            paymentMethod: suggestion.paymentMethod,
          ),
        );
      }
      _clearRows();
      setState(() => _rows.addAll(next));
      if (next.isEmpty) {
        AppToast.showError(context, 'No transaction rows were found.');
      }
    } on FormatException catch (error) {
      AppToast.showError(context, error.message);
    }
  }

  Future<void> _pickDate(_CsvReviewRow row) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: row.date ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (chosen != null && mounted) setState(() => row.date = chosen);
  }

  String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');

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
    String duplicateKey(Expense expense) =>
        '${expense.occurredAt.year}-${expense.occurredAt.month}-${expense.occurredAt.day}|'
        '${expense.amountCents}|${_normalize(expense.merchantOrNote ?? '')}';
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
            '$duplicateCount selected row${duplicateCount == 1 ? '' : 's'} may already be in Expenses or repeated in this CSV. Add anyway?',
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
    final selectedCount = _rows.where((row) => row.selected).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Import bank CSV')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose a CSV, map its columns, then review every transaction before adding it.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _chooseFile,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_fileName ?? 'Choose CSV file'),
            ),
            if (_table.isNotEmpty && _rows.isEmpty) ...[
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'Column mapping',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check that this statement uses ${currency.code}. iSpend does not convert currencies during import.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _columnPicker(
                      'Date',
                      _dateColumn,
                      (v) => setState(() => _dateColumn = v),
                    ),
                    _columnPicker(
                      'Description',
                      _descriptionColumn,
                      (v) => setState(() => _descriptionColumn = v),
                    ),
                    DropdownButtonFormField<StatementDateFormat>(
                      isExpanded: true,
                      initialValue: _dateFormat,
                      decoration: const InputDecoration(
                        labelText: 'Date format',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: StatementDateFormat.dayMonthYear,
                          child: Text('DD/MM/YYYY'),
                        ),
                        DropdownMenuItem(
                          value: StatementDateFormat.monthDayYear,
                          child: Text('MM/DD/YYYY'),
                        ),
                        DropdownMenuItem(
                          value: StatementDateFormat.yearMonthDay,
                          child: Text('YYYY-MM-DD'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _dateFormat = v);
                      },
                    ),
                    DropdownButtonFormField<StatementAmountMode>(
                      isExpanded: true,
                      initialValue: _mode,
                      decoration: const InputDecoration(
                        labelText: 'How does this bank show spending?',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: StatementAmountMode.debitCredit,
                          child: Text('Separate debit and credit columns'),
                        ),
                        DropdownMenuItem(
                          value: StatementAmountMode.negativeSpending,
                          child: Text('Negative amount = spending'),
                        ),
                        DropdownMenuItem(
                          value: StatementAmountMode.positiveSpending,
                          child: Text('Positive amount = spending'),
                        ),
                        DropdownMenuItem(
                          value: StatementAmountMode.unsigned,
                          child: Text('Unsigned amounts — review each row'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _mode = v);
                      },
                    ),
                    if (_mode == StatementAmountMode.debitCredit) ...[
                      _columnPicker(
                        'Debit',
                        _debitColumn,
                        (v) => setState(() => _debitColumn = v),
                      ),
                      _columnPicker(
                        'Credit',
                        _creditColumn,
                        (v) => setState(() => _creditColumn = v),
                      ),
                    ] else
                      _columnPicker(
                        'Amount',
                        _amountColumn,
                        (v) => setState(() => _amountColumn = v),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '${_table.length - 1} data rows · ${_table.first.join(' · ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _review,
                child: const Text('Review transactions'),
              ),
            ] else if (_rows.isNotEmpty) ...[
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

  Widget _columnPicker(
    String label,
    int? value,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonFormField<int>(
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem<int>(value: null, child: Text('Choose column')),
      for (var i = 0; i < _table.first.length; i++)
        DropdownMenuItem(
          value: i,
          child: Text(
            _table.first[i].isEmpty ? 'Column ${i + 1}' : _table.first[i],
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: onChanged,
  );

  Widget _rowCard(
    _CsvReviewRow row,
    List<String> categories,
    List<String> methods,
    String currency,
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
              'CSV row ${row.source.line} · ${row.description.text}',
              maxLines: 2,
            ),
            subtitle: Text(
              row.source.reason ?? 'Spending · review before adding',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            value: row.selected,
            onChanged: valid
                ? (v) => setState(() => row.selected = v ?? false)
                : null,
          ),
          if (row.source.reason != null)
            Text(
              'Review required: ${row.source.reason}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextField(
            controller: row.amount,
            decoration: InputDecoration(labelText: 'Amount ($currency)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: row.description,
            decoration: const InputDecoration(labelText: 'Description'),
            onChanged: (_) => setState(() {}),
          ),
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
          TextButton.icon(
            onPressed: () => _pickDate(row),
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              row.date == null
                  ? 'Choose date'
                  : '${row.date!.day}/${row.date!.month}/${row.date!.year}',
            ),
          ),
        ],
      ),
    );
  }
}

class _CsvReviewRow {
  _CsvReviewRow(
    this.source, {
    required this.category,
    required this.paymentMethod,
  }) : amount = TextEditingController(
         text: source.amountCents == null
             ? ''
             : formatCents(source.amountCents!),
       ),
       description = TextEditingController(text: source.description),
       date = source.date,
       selected = source.selected;
  final StatementRow source;
  final TextEditingController amount;
  final TextEditingController description;
  DateTime? date;
  String category;
  String? paymentMethod;
  bool selected;
  void dispose() {
    amount.dispose();
    description.dispose();
  }
}
