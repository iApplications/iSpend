import 'package:csv/csv.dart';

enum StatementAmountMode {
  debitCredit,
  negativeSpending,
  positiveSpending,
  unsigned,
}

enum StatementDateFormat { dayMonthYear, monthDayYear, yearMonthDay }

class StatementColumnMapping {
  const StatementColumnMapping({
    required this.date,
    required this.description,
    required this.amountMode,
    required this.dateFormat,
    this.amount,
    this.debit,
    this.credit,
  });

  final int date;
  final int description;
  final int? amount;
  final int? debit;
  final int? credit;
  final StatementAmountMode amountMode;
  final StatementDateFormat dateFormat;
}

class StatementRow {
  const StatementRow({
    required this.line,
    required this.description,
    required this.date,
    required this.amountCents,
    required this.reason,
    required this.selected,
  });

  final int line;
  final String description;
  final DateTime? date;
  final int? amountCents;
  final String? reason;
  final bool selected;
}

class StatementCsvParser {
  const StatementCsvParser();

  List<List<String>> read(String text) {
    final normalized = text.replaceFirst('\uFEFF', '');
    final eol = normalized.contains('\r\n') ? '\r\n' : '\n';
    final rows = CsvToListConverter(
      eol: eol,
      shouldParseNumbers: false,
      allowInvalid: false,
      convertEmptyTo: '',
    ).convert(normalized);
    if (rows.isEmpty || rows.first.isEmpty) {
      throw const FormatException('The CSV has no header row.');
    }
    return rows
        .map((row) => row.map((cell) => cell.toString().trim()).toList())
        .toList();
  }

  List<StatementRow> parse(
    List<List<String>> rows,
    StatementColumnMapping mapping,
  ) {
    if (rows.length < 2) return const [];
    final width = rows.first.length;
    final required = [
      mapping.date,
      mapping.description,
      if (mapping.amountMode == StatementAmountMode.debitCredit) ...[
        mapping.debit ?? -1,
        mapping.credit ?? -1,
      ] else
        mapping.amount ?? -1,
    ];
    if (required.any((index) => index < 0 || index >= width) ||
        required.toSet().length != required.length) {
      throw const FormatException(
        'Choose different valid columns for each field.',
      );
    }
    final result = <StatementRow>[];
    for (var index = 1; index < rows.length; index++) {
      final cells = rows[index];
      if (cells.every((cell) => cell.trim().isEmpty)) continue;
      String cell(int column) =>
          column < cells.length ? cells[column].trim() : '';
      final description = cell(mapping.description);
      final date = _date(cell(mapping.date), mapping.dateFormat);
      int? amount;
      String? reason;
      if (mapping.amountMode == StatementAmountMode.debitCredit) {
        final debitRaw = cell(mapping.debit!);
        final creditRaw = cell(mapping.credit!);
        final debit = _money(debitRaw);
        final credit = _money(creditRaw);
        if (creditRaw.isNotEmpty && credit == null) {
          reason = 'Unrecognized credit amount — review before adding';
        } else if (debit != null &&
            debit > 0 &&
            (credit == null || credit == 0)) {
          amount = debit;
        } else {
          reason = credit != null && credit > 0
              ? 'Credit or refund — review before adding'
              : 'No clear debit amount — review before adding';
        }
      } else {
        final signed = _money(cell(mapping.amount!));
        if (signed == null || signed == 0) {
          reason = 'Invalid or empty amount';
        } else {
          amount = signed.abs();
          if (mapping.amountMode == StatementAmountMode.unsigned) {
            reason = 'Amount direction is unknown — review before adding';
          } else if ((signed < 0) !=
              (mapping.amountMode == StatementAmountMode.negativeSpending)) {
            reason = 'Credit or incoming amount — review before adding';
          }
        }
      }
      if (RegExp(
        r'\b(refund|reversal|transfer|repayment|card payment|payment to card)\b',
        caseSensitive: false,
      ).hasMatch(description)) {
        reason =
            'Possible refund, transfer, or repayment — review before adding';
      }
      if (cells.length != width) {
        reason = 'Different number of columns — review the CSV row';
      }
      if (date == null) reason ??= 'Unrecognized date — choose a date';
      if (description.isEmpty) {
        reason ??= 'Missing description — review before adding';
      }
      result.add(
        StatementRow(
          line: index + 1,
          description: description,
          date: date,
          amountCents: amount,
          reason: reason,
          selected: reason == null && amount != null && amount > 0,
        ),
      );
    }
    return result;
  }

  int? _money(String raw) {
    if (raw.isEmpty || raw == '-') return null;
    var value = raw.trim();
    var negative = false;
    if (value.startsWith('(') && value.endsWith(')')) {
      negative = true;
      value = value.substring(1, value.length - 1);
    }
    if (value.startsWith('-')) {
      negative = true;
      value = value.substring(1);
    } else if (value.startsWith('+')) {
      value = value.substring(1);
    }
    if (!RegExp(
      r'^\d{1,3}(,\d{3})*(\.\d{1,2})?$|^\d+(\.\d{1,2})?$',
    ).hasMatch(value)) {
      return null;
    }
    final parts = value.replaceAll(',', '').split('.');
    final whole = int.tryParse(parts.first);
    if (whole == null) return null;
    final fraction = parts.length == 1
        ? 0
        : int.parse(parts.last.padRight(2, '0'));
    final cents = whole * 100 + fraction;
    return negative ? -cents : cents;
  }

  DateTime? _date(String raw, StatementDateFormat format) {
    final match = RegExp(
      r'^(\d{1,4})[-/](\d{1,2})[-/](\d{1,4})$',
    ).firstMatch(raw);
    if (match == null) return null;
    final a = int.parse(match[1]!);
    final b = int.parse(match[2]!);
    final c = int.parse(match[3]!);
    final year = format == StatementDateFormat.yearMonthDay ? a : c;
    final month = format == StatementDateFormat.dayMonthYear
        ? b
        : format == StatementDateFormat.monthDayYear
        ? a
        : b;
    final day = format == StatementDateFormat.dayMonthYear
        ? a
        : format == StatementDateFormat.monthDayYear
        ? b
        : c;
    if (year < 1900 || year > 2100) return null;
    final date = DateTime(year, month, day, 12);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
}
