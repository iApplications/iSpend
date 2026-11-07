import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_settings_repository.dart';
import '../../core/utils/currency_catalog.dart';
import '../settings/currency_preference.dart';
import 'data/exchange_rate_service.dart';

final exchangeRateFetcherProvider = Provider<ExchangeRateFetcher>(
  (_) => const FrankfurterRateFetcher(),
);

class ExchangeRatesState {
  const ExchangeRatesState({
    this.loaded = false,
    this.suggestionsEnabled = false,
    this.cache,
    this.lastUsed = const {},
    this.refreshing = false,
    this.error,
  });

  final bool loaded;

  /// Whether the user allowed downloading recommended rates. Off by default.
  final bool suggestionsEnabled;
  final RateTable? cache;

  /// The rate the user last confirmed for each currency.
  final Map<String, double> lastUsed;
  final bool refreshing;
  final String? error;

  ExchangeRatesState copyWith({
    bool? loaded,
    bool? suggestionsEnabled,
    RateTable? cache,
    Map<String, double>? lastUsed,
    bool? refreshing,
    String? error,
    bool clearError = false,
  }) => ExchangeRatesState(
    loaded: loaded ?? this.loaded,
    suggestionsEnabled: suggestionsEnabled ?? this.suggestionsEnabled,
    cache: cache ?? this.cache,
    lastUsed: lastUsed ?? this.lastUsed,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : error ?? this.error,
  );
}

final exchangeRatesProvider =
    NotifierProvider<ExchangeRatesNotifier, ExchangeRatesState>(
      ExchangeRatesNotifier.new,
    );

class ExchangeRatesNotifier extends Notifier<ExchangeRatesState> {
  static const staleAfter = Duration(hours: 24);

  late ExchangeRateStore _store;
  late String _base;

  @override
  ExchangeRatesState build() {
    _store = ExchangeRateStore(ref.watch(appSettingsRepositoryProvider));
    _base = ref.watch(appCurrencyProvider).code;
    Future<void>.microtask(refreshFromStorage);
    return const ExchangeRatesState();
  }

  /// Reloads saved preferences, e.g. after a backup was restored.
  Future<void> refreshFromStorage() async {
    final enabled = await _store.readEnabled();
    final cache = await _store.readCache();
    final lastUsed = await _store.readLastUsed();
    state = ExchangeRatesState(
      loaded: true,
      suggestionsEnabled: enabled,
      cache: cache,
      lastUsed: lastUsed,
    );
  }

  Future<void> setSuggestionsEnabled(bool enabled) async {
    await _store.writeEnabled(enabled);
    state = state.copyWith(suggestionsEnabled: enabled, clearError: true);
    if (enabled) await refresh(force: true);
  }

  bool _isFresh(RateTable? cache) =>
      cache != null &&
      cache.base == _base &&
      DateTime.now().difference(cache.fetchedAt) < staleAfter;

  /// Downloads the latest rates when suggestions are on and the saved ones are
  /// more than a day old (or [force]). A failure leaves the saved rates and
  /// manual entry untouched.
  Future<void> refresh({bool force = false}) async {
    if (!state.suggestionsEnabled || state.refreshing) return;
    if (!force && _isFresh(state.cache)) return;
    state = state.copyWith(refreshing: true, clearError: true);
    try {
      final table = await ref.read(exchangeRateFetcherProvider).fetch(_base);
      await _store.writeCache(table);
      state = state.copyWith(cache: table, refreshing: false);
    } catch (_) {
      state = state.copyWith(
        refreshing: false,
        error: 'Could not reach the rate service. You can still type a rate.',
      );
    }
  }

  /// The recommended rate for [currency], or null when suggestions are off or
  /// no rate for it was downloaded.
  double? suggestedRate(String currency) {
    if (!state.suggestionsEnabled) return null;
    final cache = state.cache;
    if (cache == null || cache.base != _base) return null;
    return cache.rateToBase(currency);
  }

  Future<void> rememberRate(String currency, double rate) async {
    final next = {...state.lastUsed, currency: rate};
    state = state.copyWith(lastUsed: next);
    try {
      await _store.writeLastUsed(next);
    } catch (_) {
      // Remembering a rate is a convenience; the expense is already saved.
    }
  }

  /// Rate to pre-fill: the one the user last confirmed for this currency,
  /// otherwise the recommended one. A suggestion never replaces a rate the
  /// user chose themselves; it is offered beside it instead.
  double? prefillRate(String currency) {
    final last = state.lastUsed[currency];
    if (last != null && last >= minExchangeRate && last <= maxExchangeRate) {
      return last;
    }
    return suggestedRate(currency);
  }
}
