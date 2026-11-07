import 'statement_csv_parser.dart';

/// Parses the text of a Touch 'n Go "Customer Transactions Statement" PDF.
///
/// Each transaction is a block of lines that starts with a transaction number
/// and an entry date, and ends with the line holding the amount, the card
/// balance, and the sector. Cells wrap, so the layout is read from the
/// content-order text rather than from columns.
class TngStatementParser {
  const TngStatementParser();

  static bool canParse(String text) =>
      text.contains('Customer Transactions Statement') &&
      text.contains('Trans No.');

  static final _number = RegExp(r'^\d{1,12}$');
  static final _date = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
  static final _amountLine = RegExp(
    r'(?:^|\s)(-?\d{1,3}(?:,\d{3})*\.\d{2})\s+-?\d{1,3}(?:,\d{3})*\.\d{2}\s+[A-Z][A-Z_ ]*$',
  );
  static final _spending = RegExp(
    r'\b(fare|usage|toll|parking|purchase|payment)\b',
    caseSensitive: false,
  );
  static final _reload = RegExp(
    r'\b(reload|top[- ]?up|refund|reversal|adjustment)\b',
    caseSensitive: false,
  );

  List<StatementRow> parse(String text) {
    // Some PDF engines keep the number and entry date on one line.
    final lines = text
        .replaceAllMapped(
          RegExp(
            r'^(\d{1,12})[ \t]+(\d{2}/\d{2}/\d{4})[ \t]*$',
            multiLine: true,
          ),
          (m) => '${m[1]}\n${m[2]}',
        )
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final result = <StatementRow>[];
    var index = 0;
    while (index < lines.length) {
      if (_number.hasMatch(lines[index]) &&
          index + 1 < lines.length &&
          _date.hasMatch(lines[index + 1])) {
        final block = <String>[];
        var cursor = index + 1;
        int? amountCents;
        var negative = false;
        while (cursor < lines.length) {
          final line = lines[cursor];
          final amount = _amountLine.firstMatch(line);
          if (amount != null) {
            amountCents = _cents(amount[1]!.replaceFirst('-', ''));
            negative = amount[1]!.startsWith('-');
            block.add(line.substring(0, amount.start).trim());
            cursor++;
            break;
          }
          if (cursor > index + 1 &&
              _number.hasMatch(line) &&
              cursor + 1 < lines.length &&
              _date.hasMatch(lines[cursor + 1])) {
            break;
          }
          block.add(line);
          cursor++;
        }
        result.add(_row(result.length + 1, block, amountCents, negative));
        index = cursor;
      } else {
        index++;
      }
    }
    return result;
  }

  StatementRow _row(
    int line,
    List<String> block,
    int? amountCents,
    bool negative,
  ) {
    final entry = _date.firstMatch(block.first)!;
    final date = _validDate(
      int.parse(entry[3]!),
      int.parse(entry[2]!),
      int.parse(entry[1]!),
    );
    // After the dates and times, the posted date is split as "dd/mm" and
    // "/yyyy". The wrapped, mixed-case lines that follow are the type; the
    // first all-capital line without digits is the entry location.
    final afterDates = block.skip(1).where((l) {
      return !RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(l) &&
          !_date.hasMatch(l) &&
          !RegExp(r'^\d{2}/\d{2}$').hasMatch(l) &&
          !RegExp(r'^/\d{4}$').hasMatch(l);
    }).toList();
    final type = afterDates
        .takeWhile((l) => RegExp(r'[a-z]').hasMatch(l))
        .join(' ');
    final location = afterDates.firstWhere(
      (l) =>
          !RegExp(r'[a-z]').hasMatch(l) &&
          !RegExp(r'\d').hasMatch(l) &&
          l.contains(RegExp(r'[A-Z]')),
      orElse: () => '',
    );
    final description = [
      type.isEmpty ? 'Touch n Go' : type,
      if (location.isNotEmpty) location,
    ].join(' · ');

    String? reason;
    if (amountCents == null || amountCents <= 0) {
      reason = 'No clear amount — review before adding';
    } else if (negative || _reload.hasMatch(type)) {
      reason = 'Reload or refund — review before adding';
    } else if (!_spending.hasMatch(type)) {
      reason = 'Unrecognized transaction type — review before adding';
    }
    if (date == null) reason ??= 'Unrecognized date — choose a date';
    return StatementRow(
      line: line,
      description: description,
      date: date,
      amountCents: amountCents,
      reason: reason,
      selected: reason == null,
    );
  }

  int _cents(String raw) {
    final parts = raw.replaceAll(',', '').split('.');
    return int.parse(parts.first) * 100 + int.parse(parts.last);
  }

  DateTime? _validDate(int year, int month, int day) {
    final date = DateTime(year, month, day, 12);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
}
