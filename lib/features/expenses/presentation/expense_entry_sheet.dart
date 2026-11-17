import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/currency_catalog.dart';
import '../../exchange_rates/exchange_rate_providers.dart';
import '../../exchange_rates/presentation/foreign_currency_section.dart';
import '../../tags/data/tag_rules.dart';
import '../../tags/presentation/tag_editor.dart';
import '../data/expense_model.dart';
import '../data/recurring_expense.dart';
import 'entry_choices.dart';

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
  List<Expense> tagHistory = const [],
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
      tagHistory: tagHistory,
    ),
  );
}

class ExpenseEntrySheet extends ConsumerStatefulWidget {
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
    this.tagHistory = const [],
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

  /// Existing expenses, used to suggest tags. Tags are not offered for
  /// recurring expenses, whose series do not carry them yet.
  final List<Expense> tagHistory;

  @override
  ConsumerState<ExpenseEntrySheet> createState() => _ExpenseEntrySheetState();
}

class _ExpenseEntrySheetState extends ConsumerState<ExpenseEntrySheet> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  String _category = 'Food';
  String? _paymentMethod;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _amountError;
  bool _repeatsMonthly = false;
  bool _isTaxDeductible = false;
  List<String> _tags = [];
  ForeignSelection _foreign = const ForeignSelection();
  final _tagController = TextEditingController();

  bool get _tagsAllowed =>
      !_repeatsMonthly &&
      widget.recurringSchedule == null &&
      widget.expense?.recurringRuleId == null &&
      widget.showRecurringOption;

  /// The currency the amount field is typed in.
  AppCurrency get _amountCurrency {
    final code = _foreign.currency;
    return (code == null ? null : currencyForCode(code)) ?? widget.currency;
  }

  String get _saveLabel {
    final cents = parseAmountToCents(_amountController.text);
    if (cents == null || cents <= 0) return 'Save expense';
    // The ISO code, because $ and ¥ alone can mean more than one currency.
    if (_foreign.isForeign) {
      return 'Save ${_foreign.currency} ${formatCents(cents)}';
    }
    return 'Save ${formatCurrencyCents(cents, _amountCurrency)}';
  }

  bool get _isEditing => widget.expense != null;

  /// Opens "More options" when something inside is already set (editing).
  bool get _hasMoreOptionsSet =>
      _tags.isNotEmpty ||
      _foreign.isForeign ||
      _isTaxDeductible ||
      _repeatsMonthly ||
      (widget.expense?.isForeign ?? false);

  String? get _moreOptionsSummary {
    final parts = [
      if (_tags.isNotEmpty) 'Tags ${_tags.length}',
      if (_foreign.isForeign) _foreign.currency!,
      if (_isTaxDeductible) 'Tax-deductible',
      if (_repeatsMonthly) 'Repeats monthly',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  void initState() {
    super.initState();
    _repeatsMonthly = widget.initialRepeatsMonthly;
    final expense = widget.expense;
    if (expense == null) return;
    if (expense.isForeign) {
      // Editing shows what was paid; the app-currency amount follows from it.
      _amountController.text = formatCents(expense.originalAmountCents!);
      _foreign = ForeignSelection(
        currency: expense.originalCurrency,
        rate: expense.exchangeRate,
      );
    } else {
      _amountController.text = formatCents(expense.amountCents);
    }
    _merchantController.text = expense.merchantOrNote ?? '';
    _category = expense.category;
    _paymentMethod = expense.paymentMethod;
    _date = expense.occurredAt;
    _time = TimeOfDay.fromDateTime(expense.occurredAt);
    _isTaxDeductible = expense.isTaxDeductible;
    _tags = [...expense.tags];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _tagController.dispose();
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

    if (_foreign.isForeign && !_tagsAllowed) {
      // Never save a typed foreign amount as if it were in the app currency.
      setState(() => _amountError = 'Choose your own currency to repeat.');
      return;
    }
    var baseCents = amountCents;
    String? originalCurrency;
    int? originalCents;
    double? rate;
    if (_foreign.isForeign && _tagsAllowed) {
      rate = _foreign.rate;
      final converted = rate == null
          ? null
          : convertToBaseCents(amountCents, rate);
      if (converted == null) {
        setState(
          () => _amountError = rate == null
              ? 'Enter a valid exchange rate.'
              : 'That amount converts to less than one cent.',
        );
        return;
      }
      baseCents = converted;
      originalCurrency = _foreign.currency;
      originalCents = amountCents;
      ref
          .read(exchangeRatesProvider.notifier)
          .rememberRate(originalCurrency!, rate!);
    }

    final merchant = _merchantController.text.trim();
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(
      ExpenseEntryResult(
        expense: Expense(
          id: widget.expense?.id ?? const Uuid().v4(),
          amountCents: baseCents,
          originalAmountCents: originalCents,
          originalCurrency: originalCurrency,
          exchangeRate: rate,
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
          tags: _tagsAllowed
              ? normalizeTags([
                  ..._tags,
                  ..._tagController.text.split(','),
                ], known: tagUsage(widget.tagHistory).map((e) => e.key))
              : const [],
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
                currency: _amountCurrency,
                errorText: _amountError,
                onChanged: () {
                  if (_amountError != null) setState(() => _amountError = null);
                  setState(() {});
                },
              ),
              const SizedBox(height: 24),
              Text('Category', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              CategoryChips(
                categories: uniqueCategories,
                selected: _category,
                onChanged: (category) => setState(() => _category = category),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment method',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              PaymentMethodChips(
                methods: uniquePaymentMethods,
                history: widget.tagHistory,
                selected: _paymentMethod,
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
                onChanged: (_) => setState(() {}),
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
              ],
              // Optional extras live together so the common path stays short.
              // maintainState keeps their values while the section is closed.
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                maintainState: true,
                initiallyExpanded: _hasMoreOptionsSet,
                title: const Text('More options'),
                subtitle: _moreOptionsSummary == null
                    ? null
                    : Text(_moreOptionsSummary!),
                children: [
                  if (_tagsAllowed) ...[
                    ForeignCurrencySection(
                      amountCents: parseAmountToCents(_amountController.text),
                      initialCurrency: widget.expense?.originalCurrency,
                      initialRate: widget.expense?.exchangeRate,
                      onChanged: (selection) =>
                          setState(() => _foreign = selection),
                    ),
                    const SizedBox(height: 16),
                    TagEditor(
                      tags: _tags,
                      controller: _tagController,
                      history: widget.tagHistory,
                      merchant: _merchantController.text,
                      onChanged: (tags) => setState(() => _tags = tags),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Count as tax-deductible?'),
                    subtitle: const Text(
                      'For your own tracking — not tax advice',
                    ),
                    value: _isTaxDeductible,
                    onChanged: (value) =>
                        setState(() => _isTaxDeductible = value),
                  ),
                  if (widget.recurringSchedule == null &&
                      widget.showRecurringOption) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repeats monthly'),
                      subtitle: _foreign.isForeign
                          ? const Text('Not available for other currencies yet')
                          : null,
                      value: _repeatsMonthly,
                      onChanged: _foreign.isForeign
                          ? null
                          : (value) => setState(() => _repeatsMonthly = value),
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
                ],
              ),
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
