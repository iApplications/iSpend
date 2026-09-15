import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/widgets/icon_registry.dart';
import '../data/expense_model.dart';
import '../data/recurring_expense.dart';

Future<ExpenseEntryResult?> showExpenseEntrySheet(
  BuildContext context, {
  required bool use24HourFormat,
  required List<String> categories,
  required List<String> paymentMethods,
  required AppCurrency currency,
  Expense? expense,
  bool showRecurringOption = true,
  bool initialRepeatsMonthly = false,
  RecurringExpense? recurringSchedule,
  VoidCallback? onViewRecurringSchedule,
  String? title,
  String? saveButtonLabel,
}) {
  return showModalBottomSheet<ExpenseEntryResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ExpenseEntrySheet(
      use24HourFormat: use24HourFormat,
      categories: categories,
      paymentMethods: paymentMethods,
      currency: currency,
      expense: expense,
      showRecurringOption: showRecurringOption,
      initialRepeatsMonthly: initialRepeatsMonthly,
      recurringSchedule: recurringSchedule,
      onViewRecurringSchedule: onViewRecurringSchedule,
      title: title,
      saveButtonLabel: saveButtonLabel,
    ),
  );
}

class ExpenseEntrySheet extends StatefulWidget {
  const ExpenseEntrySheet({
    required this.use24HourFormat,
    required this.categories,
    required this.paymentMethods,
    required this.currency,
    this.expense,
    this.showRecurringOption = true,
    this.initialRepeatsMonthly = false,
    this.recurringSchedule,
    this.onViewRecurringSchedule,
    this.title,
    this.saveButtonLabel,
    super.key,
  });

  final bool use24HourFormat;
  final List<String> categories;
  final List<String> paymentMethods;
  final AppCurrency currency;
  final Expense? expense;
  final bool showRecurringOption;
  final bool initialRepeatsMonthly;
  final RecurringExpense? recurringSchedule;
  final VoidCallback? onViewRecurringSchedule;
  final String? title;
  final String? saveButtonLabel;

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
  bool _repeatsMonthly = false;
  bool _isTaxDeductible = false;

  String get _saveLabel {
    final cents = parseAmountToCents(_amountController.text);
    if (cents == null || cents <= 0) return 'Save expense';
    return 'Save ${formatCurrencyCents(cents, widget.currency)}';
  }

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _repeatsMonthly = widget.initialRepeatsMonthly;
    final expense = widget.expense;
    if (expense == null) return;
    _amountController.text = formatCents(expense.amountCents);
    _merchantController.text = expense.merchantOrNote ?? '';
    _category = expense.category;
    _paymentMethod = expense.paymentMethod;
    _date = expense.occurredAt;
    _time = TimeOfDay.fromDateTime(expense.occurredAt);
    _isTaxDeductible = expense.isTaxDeductible;
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
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(
      ExpenseEntryResult(
        expense: Expense(
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
          recurringRuleId: widget.expense?.recurringRuleId,
          recurringOccurrence: widget.expense?.recurringOccurrence,
          isTaxDeductible: _isTaxDeductible,
        ),
        repeatsMonthly: _repeatsMonthly,
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
    final commonCategories = [
      for (final category in const ['Food', 'Transport', 'Shopping', 'Bills'])
        if (uniqueCategories.contains(category)) category,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title ?? (_isEditing ? 'Edit expense' : 'Add expense'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _AmountField(
                controller: _amountController,
                currency: widget.currency,
                errorText: _amountError,
                onChanged: () {
                  if (_amountError != null) setState(() => _amountError = null);
                  setState(() {});
                },
              ),
              const SizedBox(height: 24),
              Text('Category', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in commonCategories)
                    _CategoryChoice(
                      category: category,
                      selected: category == _category,
                      onTap: () => setState(() => _category = category),
                    ),
                ],
              ),
              if (uniqueCategories.length > commonCategories.length) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _chooseMoreCategory(uniqueCategories),
                    icon: const Icon(Icons.more_horiz),
                    label: const Text('More categories'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Payment method',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  hintText: 'Select payment method (optional)',
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
              const SizedBox(height: 16),
              TextField(
                controller: _merchantController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Merchant or note',
                  hintText: 'Add an optional note',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Count as tax-deductible?'),
                subtitle: const Text('For your own tracking — not tax advice'),
                value: _isTaxDeductible,
                onChanged: (value) => setState(() => _isTaxDeductible = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateTimePickerField(
                      label: 'Date',
                      icon: Icons.calendar_today_outlined,
                      value:
                          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                      onPressed: _chooseDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateTimePickerField(
                      label: 'Time',
                      icon: Icons.schedule_outlined,
                      value: _formatTime(_time, widget.use24HourFormat),
                      onPressed: _chooseTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.recurringSchedule != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.repeat),
                  title: const Text('Part of recurring expense'),
                  subtitle: Text(
                    widget.recurringSchedule!.isActive
                        ? 'Monthly · next ${_formatDate(widget.recurringSchedule!.nextOccurrence)}'
                        : 'Monthly · stopped',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onViewRecurringSchedule == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onViewRecurringSchedule!();
                          },
                    child: const Text('View recurring schedule >'),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (widget.showRecurringOption) ...[
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('More options'),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repeats monthly'),
                      value: _repeatsMonthly,
                      onChanged: (value) =>
                          setState(() => _repeatsMonthly = value),
                    ),
                    if (_repeatsMonthly)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'A draft will be created next month for you to confirm.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const Divider(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('saveExpenseButton'),
                  onPressed: _save,
                  child: Text(
                    widget.saveButtonLabel ??
                        (_isEditing ? 'Save changes' : _saveLabel),
                  ),
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _chooseMoreCategory(List<String> categories) async {
    final category = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final category in categories)
              ListTile(
                leading: Icon(
                  categoryIconStyle(category).icon,
                  color: categoryIconStyle(category).color,
                ),
                title: Text(category),
                trailing: category == _category
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, category),
              ),
          ],
        ),
      ),
    );
    if (category != null) setState(() => _category = category);
  }
}

class ExpenseEntryResult {
  const ExpenseEntryResult({
    required this.expense,
    required this.repeatsMonthly,
  });

  final Expense expense;
  final bool repeatsMonthly;
}

class _DateTimePickerField extends StatelessWidget {
  const _DateTimePickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $value',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(labelText: label),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.currency,
    required this.errorText,
    required this.onChanged,
  });
  final TextEditingController controller;
  final AppCurrency currency;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('amountField'),
    controller: controller,
    autofocus: true,
    textAlign: TextAlign.center,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
    ],
    style: Theme.of(
      context,
    ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
    decoration: InputDecoration(
      prefixText: '${currency.symbol} ',
      prefixStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
      hintText: '0.00',
      errorText: errorText,
    ),
    onChanged: (_) => onChanged(),
  );
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    duration: const Duration(milliseconds: 140),
    curve: Curves.easeOut,
    scale: selected ? 1.02 : 1,
    child: ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(style.icon, size: 18, color: selected ? style.color : null),
      label: Text(category),
      showCheckmark: selected,
    ),
  );

  CategoryIconStyle get style => categoryIconStyle(category);
}
