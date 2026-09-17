import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../expenses/data/expense_model.dart';
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

class _QuickEntrySheet extends StatefulWidget {
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
  State<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<_QuickEntrySheet> {
  final _input = TextEditingController();
  final _merchant = TextEditingController();
  final _parser = const SmartQuickEntryParser();
  late String _category;
  String? _payment;
  int? _amount;
  String? _error;
  late DateTime _occurredAt;
  bool get _templateMode => widget.template != null;
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
    _merchant.text = t?.merchantOrNote ?? '';
    _occurredAt = DateTime.now();
  }

  @override
  void dispose() {
    _input.dispose();
    _merchant.dispose();
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
      _category = r.category;
      _payment = r.paymentMethod;
      _merchant.text = r.merchantOrNote ?? '';
      _error = null;
    });
  }

  void _save() {
    if (_amount == null || _amount! <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.pop(
      context,
      Expense(
        id: const Uuid().v4(),
        amountCents: _amount!,
        category: _category,
        merchantOrNote: _merchant.text.trim().isEmpty
            ? null
            : _merchant.text.trim(),
        paymentMethod: _payment,
        occurredAt: _occurredAt,
        createdAt: DateTime.now(),
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
                'Amount: ${_amount == null ? '—' : formatCurrencyCents(_amount!, widget.currency)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _merchant,
                decoration: const InputDecoration(
                  labelText: 'Merchant or note',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _payment,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...widget.paymentMethods.map(
                    (v) => DropdownMenuItem<String?>(value: v, child: Text(v)),
                  ),
                ],
                onChanged: (v) => setState(() => _payment = v),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('More options'),
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
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
