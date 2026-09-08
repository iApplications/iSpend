import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/amount_parser.dart';
import '../data/expense_model.dart';

Future<Expense?> showExpenseEntrySheet(
  BuildContext context, {
  required bool use24HourFormat,
  required List<String> categories,
  required List<String> paymentMethods,
  Expense? expense,
}) {
  return showModalBottomSheet<Expense>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ExpenseEntrySheet(
      use24HourFormat: use24HourFormat,
      categories: categories,
      paymentMethods: paymentMethods,
      expense: expense,
    ),
  );
}

class ExpenseEntrySheet extends StatefulWidget {
  const ExpenseEntrySheet({
    required this.use24HourFormat,
    required this.categories,
    required this.paymentMethods,
    this.expense,
    super.key,
  });

  final bool use24HourFormat;
  final List<String> categories;
  final List<String> paymentMethods;
  final Expense? expense;

  @override
  State<ExpenseEntrySheet> createState() => _ExpenseEntrySheetState();
}

class _ExpenseEntrySheetState extends State<ExpenseEntrySheet> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  String _category = 'Food';
  String? _paymentMethod;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _amountError;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    if (expense == null) return;
    _amountController.text = formatCents(expense.amountCents);
    _merchantController.text = expense.merchantOrNote ?? '';
    _category = expense.category;
    _paymentMethod = expense.paymentMethod;
    _date = expense.occurredAt;
    _time = TimeOfDay.fromDateTime(expense.occurredAt);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _chooseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: widget.use24HourFormat),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _save() {
    final amountCents = parseAmountToCents(_amountController.text);
    if (amountCents == null || amountCents <= 0) {
      setState(() => _amountError = 'Enter an amount greater than zero.');
      return;
    }

    final merchant = _merchantController.text.trim();
    Navigator.of(context).pop(
      Expense(
        id: widget.expense?.id ?? const Uuid().v4(),
        amountCents: amountCents,
        category: _category,
        occurredAt: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _time.hour,
          _time.minute,
        ),
        createdAt: widget.expense?.createdAt ?? DateTime.now(),
        merchantOrNote: merchant.isEmpty ? null : merchant,
        paymentMethod: _paymentMethod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniquePaymentMethods = <String>[];
    final seenPaymentMethodNames = <String>{};
    for (final paymentMethod in widget.paymentMethods) {
      if (seenPaymentMethodNames.add(paymentMethod.toLowerCase())) {
        uniquePaymentMethods.add(paymentMethod);
      }
    }
    if (_paymentMethod != null &&
        !uniquePaymentMethods.contains(_paymentMethod)) {
      _paymentMethod = null;
    }
    final uniqueCategories = <String>[];
    final seenCategoryNames = <String>{};
    for (final category in widget.categories) {
      if (seenCategoryNames.add(category.toLowerCase())) {
        uniqueCategories.add(category);
      }
    }
    if (!uniqueCategories.contains(_category) && uniqueCategories.isNotEmpty) {
      _category = uniqueCategories.first;
    }
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit expense' : 'Add expense',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('amountField'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  errorText: _amountError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _merchantController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Merchant or note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('categoryField'),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: uniqueCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (category) => setState(() => _category = category!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment method (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...uniquePaymentMethods.map(
                    (method) => DropdownMenuItem<String?>(
                      value: method,
                      child: Text(method),
                    ),
                  ),
                ],
                onChanged: (method) => setState(() => _paymentMethod = method),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  'Date: ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                ),
              ),
              TextButton.icon(
                onPressed: _chooseTime,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  'Time: ${_formatTime(_time, widget.use24HourFormat)}',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_isEditing ? 'Save changes' : 'Save expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time, bool use24HourFormat) {
    if (!use24HourFormat) {
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:${time.minute.toString().padLeft(2, '0')} $suffix';
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
