import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/currency_catalog.dart';
import '../../exchange_rates/exchange_rate_providers.dart';
import '../../exchange_rates/presentation/foreign_currency_section.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/presentation/entry_choices.dart';
import '../../tags/data/tag_rules.dart';
import '../../tags/presentation/tag_editor.dart';
import '../data/quick_entry_template.dart';
import '../data/smart_quick_entry_parser.dart';

Future<Expense?> showQuickEntrySheet(
  BuildContext context, {
  required List<String> categories,
  required List<String> paymentMethods,
  required List<Expense> history,
  required AppCurrency currency,
  QuickEntryTemplate? template,
  required Map<String, String> categoryNamesById,
  required Map<String, String> paymentMethodNamesById,
}) => showModalBottomSheet<Expense>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _QuickEntrySheet(
    categories: categories,
    paymentMethods: paymentMethods,
    history: history,
    currency: currency,
    template: template,
    categoryNamesById: categoryNamesById,
    paymentMethodNamesById: paymentMethodNamesById,
  ),
);

class _QuickEntrySheet extends ConsumerStatefulWidget {
  const _QuickEntrySheet({
    required this.categories,
    required this.paymentMethods,
    required this.history,
    required this.currency,
    required this.categoryNamesById,
    required this.paymentMethodNamesById,
    this.template,
  });
  final List<String> categories;
  final List<String> paymentMethods;
  final List<Expense> history;
  final AppCurrency currency;
  final QuickEntryTemplate? template;
  final Map<String, String> categoryNamesById;
  final Map<String, String> paymentMethodNamesById;
  @override
  ConsumerState<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<_QuickEntrySheet> {
  final _input = TextEditingController();
  final _merchant = TextEditingController();
  final _parser = const SmartQuickEntryParser();
  late String _category;
  String? _payment;
  int? _amount;
  String? _error;
  late DateTime _occurredAt;
  bool _saving = false;
  List<String> _tags = [];
  ForeignSelection _foreign = const ForeignSelection();
  final _tagController = TextEditingController();

  // Fields the user set by hand. Typing in the smart input must not undo them.
  bool _categoryTouched = false;
  bool _paymentTouched = false;
  bool _merchantTouched = false;
  bool get _templateMode => widget.template != null;

  /// The currency the typed amount is in.
  AppCurrency get _amountCurrency {
    final code = _foreign.currency;
    return (code == null ? null : currencyForCode(code)) ?? widget.currency;
  }

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _category = t == null
        ? (widget.categories.contains('Food')
              ? 'Food'
              : widget.categories.first)
        : widget.categoryNamesById[t.categoryId] ?? widget.categories.first;
    final storedPayment = t?.paymentMethodId;
    _payment = storedPayment == null
        ? null
        : widget.paymentMethodNamesById[storedPayment] ??
              (widget.paymentMethods.contains(storedPayment)
                  ? storedPayment
                  : null);
    _merchant.text = t == null ? '' : (t.merchantOrNote ?? t.name);
    _occurredAt = DateTime.now();
  }

  @override
  void dispose() {
    _input.dispose();
    _merchant.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _parse(String value) {
    if (_templateMode) {
      final result = _parser.parse(
        input: value,
        categories: widget.categories,
        paymentMethods: widget.paymentMethods,
        history: const [],
      );
      setState(() {
        _amount = result.amountCents;
        _error = null;
      });
      return;
    }
    final r = _parser.parse(
      input: value,
      categories: widget.categories,
      paymentMethods: widget.paymentMethods,
      history: widget.history,
    );
    setState(() {
      _amount = r.amountCents;
      if (!_categoryTouched) _category = r.category;
      if (!_paymentTouched) _payment = r.paymentMethod;
      if (!_merchantTouched) _merchant.text = r.merchantOrNote ?? '';
      _error = null;
    });
  }

  void _save() {
    if (_saving) return;
    if (_amount == null || _amount! <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    var baseCents = _amount!;
    String? originalCurrency;
    int? originalCents;
    double? rate;
    if (_foreign.isForeign && !_templateMode) {
      rate = _foreign.rate;
      final converted = rate == null
          ? null
          : convertToBaseCents(_amount!, rate);
      if (converted == null) {
        setState(
          () => _error = rate == null
              ? 'Enter a valid exchange rate.'
              : 'That amount converts to less than one cent.',
        );
        return;
      }
      baseCents = converted;
      originalCurrency = _foreign.currency;
      originalCents = _amount;
      ref
          .read(exchangeRatesProvider.notifier)
          .rememberRate(originalCurrency!, rate!);
    }
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    Navigator.pop(
      context,
      Expense(
        id: const Uuid().v4(),
        amountCents: baseCents,
        originalAmountCents: originalCents,
        originalCurrency: originalCurrency,
        exchangeRate: rate,
        category: _category,
        merchantOrNote: _merchant.text.trim().isEmpty
            ? null
            : _merchant.text.trim(),
        paymentMethod: _payment,
        occurredAt: _occurredAt,
        createdAt: DateTime.now(),
        tags: _templateMode
            ? const []
            : normalizeTags([
                ..._tags,
                ..._tagController.text.split(','),
              ], known: tagUsage(widget.history).map((e) => e.key)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
        () => _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _occurredAt.hour,
          _occurredAt.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (picked != null) {
      setState(
        () => _occurredAt = DateTime(
          _occurredAt.year,
          _occurredAt.month,
          _occurredAt.day,
          picked.hour,
          picked.minute,
        ),
      );
    }
  }

  String? get _moreOptionsSummary {
    final parts = [
      if (_tags.isNotEmpty) 'Tags ${_tags.length}',
      if (_foreign.isForeign) _foreign.currency!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _templateMode ? 'Quick entry' : 'Add expense',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _input,
                autofocus: true,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: _templateMode ? 'Amount' : 'What did you spend?',
                  hintText: _templateMode ? '8.20' : 'hokkien mee 8.20',
                  errorText: _error,
                ),
                onChanged: _parse,
              ),
              const SizedBox(height: 16),
              Text(
                'Amount: ${_amount == null ? '—' : formatCurrencyCents(_amount!, _amountCurrency)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _merchant,
                decoration: const InputDecoration(
                  labelText: 'Merchant or note',
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _merchantTouched = true),
              ),
              const SizedBox(height: 16),
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              CategoryChips(
                categories: widget.categories,
                selected: _category,
                onChanged: (category) => setState(() {
                  _category = category;
                  _categoryTouched = true;
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment method',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              PaymentMethodChips(
                methods: widget.paymentMethods,
                history: widget.history,
                selected: _payment,
                onChanged: (method) => setState(() {
                  _payment = method;
                  _paymentTouched = true;
                }),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                maintainState: true,
                title: const Text('More options'),
                subtitle: _moreOptionsSummary == null
                    ? null
                    : Text(_moreOptionsSummary!),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-${_occurredAt.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            TimeOfDay.fromDateTime(_occurredAt).format(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_templateMode) ...[
                    const SizedBox(height: 16),
                    ForeignCurrencySection(
                      amountCents: _amount,
                      onChanged: (selection) =>
                          setState(() => _foreign = selection),
                    ),
                    const SizedBox(height: 16),
                    TagEditor(
                      tags: _tags,
                      controller: _tagController,
                      history: widget.history,
                      merchant: _merchant.text,
                      onChanged: (tags) => setState(() => _tags = tags),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
