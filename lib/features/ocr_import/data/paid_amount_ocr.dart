import '../../../core/utils/amount_parser.dart';

/// Reads the numeric value from an already-recognized paid-total reference.
/// The caller must explicitly opt in before using it as an app-currency amount.
int? scannedPaidAmountCents(String? reference) {
  if (reference == null) return null;
  final match = RegExp(r'(\d[\d,]*(?:\.\d{1,2})?)$').firstMatch(reference);
  if (match == null) return null;
  final cents = parseAmountToCents(match.group(1)!.replaceAll(',', ''));
  return cents == null || cents <= 0 ? null : cents;
}

/// Fixes a narrow OCR confusion in a currency-prefixed paid total: the
/// leading digit 1 can be read as T, I, l, or | on dense screenshots.
/// Call only after identifying an explicit final-payment label.
String normalizePaidAmountOcr(String text) => text.replaceAllMapped(
  RegExp(r'((?:MYR|RM)\s*)[TIl|](?=\d{1,2}\.\d{2}\b)', caseSensitive: false),
  (match) => '${match.group(1)}1',
);

/// Returns a clearly labeled amount in a currency other than the app's.
/// A marker joined directly to digits (MYR12.33) is still a currency marker.
String? foreignPaidAmountReference(
  String text,
  String selectedCode,
  String selectedSymbol,
) {
  final normalized = normalizePaidAmountOcr(text);
  final amounts = RegExp(
    r'(?<![A-Za-z])(?:MYR|RM|SGD|USD|GBP|JPY|EUR|CNY|RMB|[£$¥€])\s*\d[\d,]*(?:\.\d{1,2})?\b',
    caseSensitive: false,
  );
  final markerPattern = RegExp(
    r'^(?:MYR|RM|SGD|USD|GBP|JPY|EUR|CNY|RMB|[£$¥€])',
    caseSensitive: false,
  );
  for (final match in amounts.allMatches(normalized)) {
    final value = match.group(0)!;
    final marker = markerPattern.firstMatch(value)!.group(0)!;
    final selected =
        marker.toUpperCase() == selectedCode.toUpperCase() ||
        (selectedCode.toUpperCase() == 'MYR' && marker.toUpperCase() == 'RM') ||
        marker == selectedSymbol;
    if (!selected) return value;
  }
  return null;
}
