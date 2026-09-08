import 'package:flutter/widgets.dart';

String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final absolute = cents.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  return '$sign$whole.$fraction';
}

class AppCurrency {
  const AppCurrency({required this.code, required this.symbol});

  final String code;
  final String symbol;

  static AppCurrency fromLocale(Locale locale) {
    return switch (locale.countryCode?.toUpperCase()) {
      'MY' => const AppCurrency(code: 'MYR', symbol: 'RM'),
      'SG' => const AppCurrency(code: 'SGD', symbol: 'S\$'),
      'US' => const AppCurrency(code: 'USD', symbol: '\$'),
      'GB' => const AppCurrency(code: 'GBP', symbol: '£'),
      'JP' => const AppCurrency(code: 'JPY', symbol: '¥'),
      _ => const AppCurrency(code: 'MYR', symbol: 'RM'),
    };
  }

  static AppCurrency fromCode(String code) {
    return switch (code) {
      'SGD' => const AppCurrency(code: 'SGD', symbol: 'S\$'),
      'USD' => const AppCurrency(code: 'USD', symbol: '\$'),
      'GBP' => const AppCurrency(code: 'GBP', symbol: '£'),
      'JPY' => const AppCurrency(code: 'JPY', symbol: '¥'),
      _ => const AppCurrency(code: 'MYR', symbol: 'RM'),
    };
  }
}

String formatCurrencyCents(int cents, AppCurrency currency) {
  return '${currency.symbol} ${formatCents(cents)}';
}
