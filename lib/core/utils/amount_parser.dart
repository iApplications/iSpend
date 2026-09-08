/// Parses a user-entered decimal amount into whole cents/sen.
///
/// The conversion operates on text instead of a floating-point number so
/// amounts such as `9.999` round reliably to `1000` cents (10.00).
int? parseAmountToCents(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) {
    return null;
  }

  final parts = value.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null) {
    return null;
  }

  final fraction = parts.length == 2 ? parts.last : '';
  final firstTwoDigits = fraction.padRight(2, '0').substring(0, 2);
  var cents = whole * 100 + int.parse(firstTwoDigits);

  if (fraction.length >= 3 && int.parse(fraction[2]) >= 5) {
    cents += 1;
  }

  return cents;
}
