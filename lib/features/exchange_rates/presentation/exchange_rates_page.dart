import '../../guides/data/guide_catalog.dart';
import '../../guides/presentation/contextual_guide.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_surface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_catalog.dart';
import '../../settings/currency_preference.dart';
import '../exchange_rate_providers.dart';

/// Controls the optional recommended exchange rates. iSpend works fully
/// offline without them: a rate can always be typed when adding an expense.
class ExchangeRatesPage extends ConsumerWidget {
  const ExchangeRatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(appCurrencyProvider);
    final rates = ref.watch(exchangeRatesProvider);
    final notifier = ref.read(exchangeRatesProvider.notifier);
    final cache = rates.cache;
    final theme = Theme.of(context);
    final shown = ['USD', 'SGD', 'EUR', 'GBP', 'JPY', 'CNY', 'THB']
        .where((code) => code != base.code)
        .map(
          (code) =>
              (code, cache?.base == base.code ? cache?.rateToBase(code) : null),
        )
        .where((entry) => entry.$2 != null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Exchange rates')),
      body: GuidedBody(
        guideId: GuideIds.foreignCurrency,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(
                'When you add an expense in another currency, iSpend converts it '
                'once using a rate you confirm, and keeps the original amount. '
                'Past expenses never change when rates move.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            AppSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Suggest rates from the internet'),
                    subtitle: const Text(
                      'Off by default. When on, iSpend downloads the European Central '
                      'Bank\'s daily rates (about once a day) to suggest a rate. The '
                      'request contains only your currency code, never your expenses. '
                      'You can always type your own rate instead.',
                    ),
                    value: rates.suggestionsEnabled,
                    onChanged: rates.loaded
                        ? notifier.setSuggestionsEnabled
                        : null,
                  ),
                  if (rates.suggestionsEnabled) ...[
                    const SizedBox(height: 8),
                    if (cache != null && cache.base == base.code)
                      Text(
                        'Rates published ${cache.date}.',
                        style: theme.textTheme.bodyMedium,
                      )
                    else
                      Text(
                        rates.refreshing
                            ? 'Downloading rates…'
                            : 'No rates downloaded yet.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    if (rates.error != null) ...[
                      const SizedBox(height: 4),
                      Text(rates.error!, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: rates.refreshing
                          ? null
                          : () => notifier.refresh(force: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Update now'),
                    ),
                  ],
                ],
              ),
            ),
            if (rates.suggestionsEnabled && shown.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent rates', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final (code, rate) in shown)
                      _RateRow(
                        label: '1 $code',
                        value: '${formatExchangeRate(rate!)} ${base.code}',
                      ),
                  ],
                ),
              ),
            ],
            if (rates.lastUsed.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rates you used', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final entry in rates.lastUsed.entries)
                      _RateRow(
                        label: '1 ${entry.key}',
                        value:
                            '${formatExchangeRate(entry.value)} ${base.code}',
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}
