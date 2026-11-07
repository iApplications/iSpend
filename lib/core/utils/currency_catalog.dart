import 'amount_formatter.dart';

/// Currencies a foreign expense can be recorded in. The app's own currency is
/// still fixed at first launch; these are only used for individual expenses.
const supportedForeignCurrencies = <AppCurrency>[
  AppCurrency(code: 'MYR', symbol: 'RM'),
  AppCurrency(code: 'SGD', symbol: 'S\$'),
  AppCurrency(code: 'USD', symbol: '\$'),
  AppCurrency(code: 'EUR', symbol: '€'),
  AppCurrency(code: 'GBP', symbol: '£'),
  AppCurrency(code: 'JPY', symbol: '¥'),
  AppCurrency(code: 'CNY', symbol: '¥'),
  AppCurrency(code: 'HKD', symbol: 'HK\$'),
  AppCurrency(code: 'TWD', symbol: 'NT\$'),
  AppCurrency(code: 'KRW', symbol: '₩'),
  AppCurrency(code: 'THB', symbol: '฿'),
  AppCurrency(code: 'IDR', symbol: 'Rp'),
  AppCurrency(code: 'PHP', symbol: '₱'),
  AppCurrency(code: 'VND', symbol: '₫'),
  AppCurrency(code: 'INR', symbol: '₹'),
  AppCurrency(code: 'AUD', symbol: 'A\$'),
  AppCurrency(code: 'NZD', symbol: 'NZ\$'),
  AppCurrency(code: 'CAD', symbol: 'C\$'),
  AppCurrency(code: 'CHF', symbol: 'CHF'),
];

/// Looks up a currency by its ISO code, or null when it is not supported.
AppCurrency? currencyForCode(String code) {
  final upper = code.toUpperCase();
  for (final currency in supportedForeignCurrencies) {
    if (currency.code == upper) return currency;
  }
  return null;
}

/// The widest range a rate may take; anything outside is a typing mistake.
const minExchangeRate = 0.000001;
const maxExchangeRate = 1000000.0;

/// Reads a rate typed by the user ("4.05", "4,05"). Returns null when it is
/// not a positive number in range.
double? parseExchangeRate(String text) {
  final cleaned = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < minExchangeRate || value > maxExchangeRate) {
    return null;
  }
  return value;
}

/// Converts an amount in a foreign currency to the app currency, rounding to
/// the nearest cent. [rate] is how many app-currency units one foreign unit
/// is worth (1 USD = 4.05 RM gives 4.05). Returns null if the result is not a
/// positive whole number of cents.
int? convertToBaseCents(int foreignCents, double rate) {
  final converted = (foreignCents * rate).roundToDouble();
  if (converted < 1 || converted > 9007199254740991 / 1000) return null;
  return converted.toInt();
}

/// Shows a rate without trailing zeros, e.g. 4.05 or 0.000256.
String formatExchangeRate(double rate) {
  final fixed = rate.toStringAsFixed(rate >= 1 ? 4 : 6);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
