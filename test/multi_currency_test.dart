import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/app_settings_repository.dart';
import 'package:ispend/core/utils/amount_formatter.dart';
import 'package:ispend/core/utils/currency_catalog.dart';
import 'package:ispend/features/exchange_rates/data/exchange_rate_service.dart';
import 'package:ispend/features/exchange_rates/exchange_rate_providers.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/presentation/expense_entry_sheet.dart';
import 'package:ispend/features/settings/currency_preference.dart';

const _myr = AppCurrency(code: 'MYR', symbol: 'RM');

class _FakeFetcher implements ExchangeRateFetcher {
  int calls = 0;
  bool fail = false;

  @override
  Future<RateTable> fetch(String base) async {
    calls++;
    if (fail) throw Exception('offline');
    return RateTable(
      base: base,
      date: '2026-11-06',
      fetchedAt: DateTime.now(),
      rates: const {'USD': 0.25, 'JPY': 40.0},
    );
  }
}

ProviderContainer _container(_FakeFetcher fetcher, {AppSettingsRepository? s}) {
  final container = ProviderContainer(
    overrides: [
      exchangeRateFetcherProvider.overrideWithValue(fetcher),
      appSettingsRepositoryProvider.overrideWithValue(
        s ?? InMemoryAppSettingsRepository(),
      ),
      startupAppCurrencyProvider.overrideWithValue(_myr),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('currency maths', () {
    test('parses typed rates with a dot or a comma and rejects bad ones', () {
      expect(parseExchangeRate('4.05'), 4.05);
      expect(parseExchangeRate(' 4,05 '), 4.05);
      expect(parseExchangeRate('0'), isNull);
      expect(parseExchangeRate('-2'), isNull);
      expect(parseExchangeRate('abc'), isNull);
      expect(parseExchangeRate('1e5'), isNull);
      expect(parseExchangeRate('99999999'), isNull);
    });

    test('converts to the nearest cent', () {
      expect(convertToBaseCents(1200, 4.05), 4860); // USD 12.00 -> RM 48.60
      expect(convertToBaseCents(333, 0.0256), 9); // 8.52 rounds to 9
      expect(convertToBaseCents(1, 0.001), isNull); // under one cent
    });

    test('shows rates without trailing zeros', () {
      expect(formatExchangeRate(4.05), '4.05');
      expect(formatExchangeRate(4), '4');
      expect(formatExchangeRate(0.0256), '0.0256');
    });

    test('knows the supported currencies', () {
      expect(currencyForCode('usd')!.symbol, '\$');
      expect(currencyForCode('XXX'), isNull);
    });
  });

  group('RateTable', () {
    test('inverts a base-to-currency rate and ignores bad entries', () {
      final table = RateTable.fromJson({
        'base': 'MYR',
        'date': '2026-11-06',
        'fetched_at': 1,
        'rates': {'USD': 0.25, 'bad': 1, 'EUR': -3, 'JPY': 'x'},
      })!;
      expect(table.rates.keys, ['USD']);
      expect(table.rateToBase('USD'), 4.0);
      expect(table.rateToBase('MYR'), 1);
      expect(table.rateToBase('EUR'), isNull);
    });

    test('rejects a malformed table', () {
      expect(RateTable.fromJson('nope'), isNull);
      expect(
        RateTable.fromJson({
          'base': 'MYR',
          'date': 'x',
          'fetched_at': 1,
          'rates': <String, Object>{},
        }),
        isNull,
      );
    });
  });

  group('exchange rate notifier', () {
    test('downloads nothing until suggestions are turned on', () async {
      final fetcher = _FakeFetcher();
      final container = _container(fetcher);
      container.read(exchangeRatesProvider);
      await _settle();
      await container.read(exchangeRatesProvider.notifier).refresh();
      expect(fetcher.calls, 0);
      expect(
        container.read(exchangeRatesProvider.notifier).suggestedRate('USD'),
        isNull,
      );
    });

    test('suggests the inverse of the downloaded rate once on', () async {
      final fetcher = _FakeFetcher();
      final container = _container(fetcher);
      container.read(exchangeRatesProvider);
      await _settle();
      final notifier = container.read(exchangeRatesProvider.notifier);
      await notifier.setSuggestionsEnabled(true);
      expect(fetcher.calls, 1);
      expect(notifier.suggestedRate('USD'), 4.0);
      expect(notifier.suggestedRate('JPY'), closeTo(0.025, 1e-9));
      // A fresh table is not downloaded again.
      await notifier.refresh();
      expect(fetcher.calls, 1);
    });

    test('a failed download keeps manual entry and the last rate', () async {
      final fetcher = _FakeFetcher()..fail = true;
      final container = _container(fetcher);
      container.read(exchangeRatesProvider);
      await _settle();
      final notifier = container.read(exchangeRatesProvider.notifier);
      await notifier.rememberRate('USD', 4.1);
      await notifier.setSuggestionsEnabled(true);
      expect(container.read(exchangeRatesProvider).error, isNotNull);
      expect(notifier.suggestedRate('USD'), isNull);
      expect(notifier.prefillRate('USD'), 4.1);
    });

    test('remembers the rate the user confirmed across restarts', () async {
      final settings = InMemoryAppSettingsRepository();
      final first = _container(_FakeFetcher(), s: settings);
      first.read(exchangeRatesProvider);
      await _settle();
      await first.read(exchangeRatesProvider.notifier).rememberRate('USD', 4.2);

      final second = _container(_FakeFetcher(), s: settings);
      second.read(exchangeRatesProvider);
      await _settle();
      expect(second.read(exchangeRatesProvider).lastUsed['USD'], 4.2);
    });
  });

  testWidgets('saves a foreign expense converted at the typed rate', (
    tester,
  ) async {
    ExpenseEntryResult? saved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exchangeRateFetcherProvider.overrideWithValue(_FakeFetcher()),
          startupAppCurrencyProvider.overrideWithValue(_myr),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showExpenseEntrySheet(
                    context,
                    use24HourFormat: true,
                    categories: const ['Food', 'Other'],
                    paymentMethods: const ['Cash'],
                    currency: _myr,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '12');
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Currency'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD (\$)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Exchange rate'),
      '4.05',
    );
    await tester.pump();
    expect(find.textContaining('48.60'), findsWidgets);

    await tester.ensureVisible(find.textContaining('Save'));
    await tester.tap(find.textContaining('Save USD'));
    await tester.pumpAndSettle();

    final expense = saved!.expense;
    expect(expense.amountCents, 4860);
    expect(expense.originalAmountCents, 1200);
    expect(expense.originalCurrency, 'USD');
    expect(expense.exchangeRate, 4.05);
    expect(expense.isForeign, isTrue);
  });

  testWidgets('will not save a foreign amount without a valid rate', (
    tester,
  ) async {
    ExpenseEntryResult? saved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exchangeRateFetcherProvider.overrideWithValue(_FakeFetcher()),
          startupAppCurrencyProvider.overrideWithValue(_myr),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showExpenseEntrySheet(
                    context,
                    use24HourFormat: true,
                    categories: const ['Food'],
                    paymentMethods: const [],
                    currency: _myr,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12');
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Currency'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD (\$)').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Save'));
    await tester.tap(find.textContaining('Save USD'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    expect(find.text('Enter a valid exchange rate.'), findsOneWidget);
  });

  test('in-memory repository keeps the original amount and rate', () async {
    final repo = InMemoryExpenseRepository();
    await repo.save(
      Expense(
        id: '1',
        amountCents: 4860,
        category: 'Food',
        occurredAt: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 10, 1),
        originalAmountCents: 1200,
        originalCurrency: 'USD',
        exchangeRate: 4.05,
      ),
    );
    await repo.renameCategory('Food', 'Dining');
    final expense = (await repo.getAll()).single;
    expect(expense.category, 'Dining');
    expect(expense.originalCurrency, 'USD');
    expect(expense.exchangeRate, 4.05);
  });
}
