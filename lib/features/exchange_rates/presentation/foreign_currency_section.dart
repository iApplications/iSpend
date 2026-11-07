import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/currency_catalog.dart';
import '../../settings/currency_preference.dart';
import '../exchange_rate_providers.dart';

/// What the user chose for an expense: the app currency ([currency] null), or
/// another currency with the rate they will convert at.
class ForeignSelection {
  const ForeignSelection({this.currency, this.rate});

  final String? currency;
  final double? rate;

  bool get isForeign => currency != null;
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Currency choice, exchange rate and the converted amount for one expense.
/// The rate is always typed or confirmed by the user; a downloaded rate is only
/// ever a suggestion that fills the field.
class ForeignCurrencySection extends ConsumerStatefulWidget {
  const ForeignCurrencySection({
    required this.amountCents,
    required this.onChanged,
    this.initialCurrency,
    this.initialRate,
    super.key,
  });

  /// The amount as typed, in the chosen currency; null while it is invalid.
  final int? amountCents;
  final String? initialCurrency;
  final double? initialRate;
  final ValueChanged<ForeignSelection> onChanged;

  @override
  ConsumerState<ForeignCurrencySection> createState() =>
      _ForeignCurrencySectionState();
}

class _ForeignCurrencySectionState
    extends ConsumerState<ForeignCurrencySection> {
  late final _rateController = TextEditingController(
    text: widget.initialRate == null
        ? ''
        : formatExchangeRate(widget.initialRate!),
  );
  String? _currency;

  /// True once the user typed in the rate field, so a later download never
  /// overwrites what they entered.
  bool _rateTouched = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency;
    _rateTouched = widget.initialRate != null;
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged(
    ForeignSelection(
      currency: _currency,
      rate: _currency == null ? null : parseExchangeRate(_rateController.text),
    ),
  );

  void _chooseCurrency(String? code, String baseCode) {
    final next = code == baseCode ? null : code;
    setState(() {
      _currency = next;
      _rateTouched = false;
      _rateController.clear();
    });
    if (next != null) {
      final notifier = ref.read(exchangeRatesProvider.notifier);
      final prefill = notifier.prefillRate(next);
      if (prefill != null) _rateController.text = formatExchangeRate(prefill);
      // Fetches only when the user turned suggestions on and rates are old.
      notifier.refresh();
    }
    _notify();
  }

  void _useRate(double rate) {
    setState(() {
      _rateTouched = true;
      _rateController.text = formatExchangeRate(rate);
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(appCurrencyProvider);
    final rates = ref.watch(exchangeRatesProvider);
    final notifier = ref.read(exchangeRatesProvider.notifier);
    final theme = Theme.of(context);

    // A download that finishes after the user picked a currency fills the rate
    // only when they have not typed one.
    ref.listen(exchangeRatesProvider, (previous, next) {
      final code = _currency;
      if (code == null || _rateTouched) return;
      final prefill = notifier.prefillRate(code);
      if (prefill != null && _rateController.text.isEmpty) {
        _rateController.text = formatExchangeRate(prefill);
        setState(() {});
        _notify();
      }
    });

    final options = [
      base,
      ...supportedForeignCurrencies.where((c) => c.code != base.code),
    ];
    final code = _currency;
    final foreign = code == null ? null : currencyForCode(code);
    final rate = parseExchangeRate(_rateController.text);
    final converted = (rate == null || widget.amountCents == null)
        ? null
        : convertToBaseCents(widget.amountCents!, rate);
    final suggested = code == null ? null : notifier.suggestedRate(code);
    final lastUsed = code == null ? null : rates.lastUsed[code];
    final cache = rates.cache;
    DateTime? published;
    if (cache != null) published = DateTime.tryParse(cache.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: code ?? base.code,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option.code,
                child: Text(
                  option.code == base.code
                      ? '${option.code} (${option.symbol}) · your currency'
                      : '${option.code} (${option.symbol})',
                ),
              ),
          ],
          onChanged: (value) => _chooseCurrency(value, base.code),
        ),
        if (code != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Exchange rate',
              prefixText: '1 $code = ',
              suffixText: base.code,
              errorText:
                  _rateController.text.isNotEmpty &&
                      parseExchangeRate(_rateController.text) == null
                  ? 'Enter a rate above 0'
                  : null,
            ),
            onChanged: (_) {
              setState(() => _rateTouched = true);
              _notify();
            },
          ),
          const SizedBox(height: 8),
          Text(
            converted == null
                ? 'Enter the amount and rate to see the ${base.code} amount.'
                : '≈ ${formatCurrencyCents(converted, base)} will be saved in '
                      '${base.code}${foreign == null ? '' : ' (${foreign.code} ${formatCents(widget.amountCents!)})'}',
            style: theme.textTheme.bodyMedium,
          ),
          if (lastUsed != null || suggested != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (lastUsed != null)
                  ActionChip(
                    avatar: const Icon(Icons.history, size: 16),
                    label: Text('Last used ${formatExchangeRate(lastUsed)}'),
                    onPressed: () => _useRate(lastUsed),
                  ),
                if (suggested != null)
                  ActionChip(
                    avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                    label: Text('Suggested ${formatExchangeRate(suggested)}'),
                    onPressed: () => _useRate(suggested),
                  ),
              ],
            ),
            if (suggested != null && published != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Suggested: ECB rate, ${published.day} ${_monthNames[published.month - 1]}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          if (rates.refreshing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Checking for a recommended rate…',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (rates.error != null && rates.suggestionsEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(rates.error!, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 4),
          Text(
            'The amount is converted once now, so this expense keeps its value '
            'when rates change.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
