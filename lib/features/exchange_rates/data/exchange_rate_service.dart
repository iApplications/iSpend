import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/database/app_settings_repository.dart';
import '../../../core/utils/currency_catalog.dart';

/// Rates for one base currency: one base unit buys [rates] units of each other
/// currency. [date] is the day the rates are published for.
class RateTable {
  const RateTable({
    required this.base,
    required this.date,
    required this.fetchedAt,
    required this.rates,
  });

  final String base;
  final String date;
  final DateTime fetchedAt;
  final Map<String, double> rates;

  Map<String, Object?> toJson() => {
    'base': base,
    'date': date,
    'fetched_at': fetchedAt.millisecondsSinceEpoch,
    'rates': rates,
  };

  /// Returns null for anything that is not a well-formed table, so a damaged
  /// cache or an odd server reply is ignored rather than trusted.
  static RateTable? fromJson(Object? json) {
    if (json is! Map) return null;
    final base = json['base'];
    final date = json['date'];
    final fetched = json['fetched_at'];
    final raw = json['rates'];
    if (base is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(base) ||
        date is! String ||
        date.length > 20 ||
        fetched is! int ||
        raw is! Map) {
      return null;
    }
    final rates = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String &&
          RegExp(r'^[A-Z]{3}$').hasMatch(key) &&
          value is num &&
          value > 0 &&
          value.isFinite) {
        rates[key] = value.toDouble();
      }
    }
    if (rates.isEmpty) return null;
    return RateTable(
      base: base,
      date: date,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetched),
      rates: rates,
    );
  }

  /// App-currency units per one [currency] unit, or null if unknown.
  double? rateToBase(String currency) {
    if (currency == base) return 1;
    final perBase = rates[currency];
    if (perBase == null || perBase <= 0) return null;
    return 1 / perBase;
  }
}

abstract interface class ExchangeRateFetcher {
  Future<RateTable> fetch(String base);
}

/// Downloads the European Central Bank's published reference rates through
/// the Frankfurter service. The request carries only the base currency code:
/// no account, device or expense information is sent.
class FrankfurterRateFetcher implements ExchangeRateFetcher {
  const FrankfurterRateFetcher();

  static const _maxBytes = 64 * 1024;

  @override
  Future<RateTable> fetch(String base) async {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(base)) {
      throw const FormatException('Unsupported currency.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'iSpend';
    try {
      final request = await client
          .getUrl(
            Uri.https('api.frankfurter.dev', '/v1/latest', {'base': base}),
          )
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw HttpException('Rate service replied ${response.statusCode}.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) {
          throw const FormatException('The rate reply was too large.');
        }
      }
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map || json['base'] != base) {
        throw const FormatException('Unexpected rate reply.');
      }
      final table = RateTable.fromJson({
        'base': base,
        'date': json['date'],
        'fetched_at': DateTime.now().millisecondsSinceEpoch,
        'rates': json['rates'],
      });
      if (table == null) throw const FormatException('Unexpected rate reply.');
      return table;
    } finally {
      client.close(force: true);
    }
  }
}

/// Stores the rate preferences in the encrypted app settings: whether
/// suggestions are on, the last downloaded table, and the rate the user last
/// confirmed for each currency.
class ExchangeRateStore {
  const ExchangeRateStore(this._settings);

  final AppSettingsRepository _settings;

  static const enabledKey = 'exchange_rate_suggestions_enabled';
  static const cacheKey = 'exchange_rates_cache';
  static const lastUsedKey = 'exchange_rates_last_used';

  Future<bool> readEnabled() async =>
      await _settings.read(enabledKey) == 'true';

  Future<void> writeEnabled(bool value) =>
      _settings.write(enabledKey, value.toString());

  Future<RateTable?> readCache() async {
    final raw = await _settings.read(cacheKey);
    if (raw == null) return null;
    try {
      return RateTable.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCache(RateTable table) =>
      _settings.write(cacheKey, jsonEncode(table.toJson()));

  Future<Map<String, double>> readLastUsed() async {
    final raw = await _settings.read(lastUsedKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return {
        for (final entry in json.entries)
          if (entry.key is String &&
              entry.value is num &&
              (entry.value as num) >= minExchangeRate &&
              (entry.value as num) <= maxExchangeRate)
            entry.key as String: (entry.value as num).toDouble(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> writeLastUsed(Map<String, double> rates) =>
      _settings.write(lastUsedKey, jsonEncode(rates));
}
