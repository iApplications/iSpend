import '../../ocr_import/data/shopping_order_candidate.dart';
import 'statement_csv_parser.dart';

class StatementParseResult {
  const StatementParseResult(this.rows, {this.notice});

  final List<StatementRow> rows;

  /// Shown above the review list, e.g. when the parsed total does not match
  /// the total printed on the statement.
  final String? notice;
}

/// How one bank lays out its card statement. Both supported banks print
/// `Post date | Transaction date | Details | Amount (RM)` with a trailing `CR`
/// on credits; they differ in headings and in where the table ends.
class CardStatementLayout {
  const CardStatementLayout({
    required this.bank,
    required this.detect,
    required this.header,
    required this.tableEnd,
    required this.printedTotal,
    this.totalExcludes,
  });

  final String bank;

  /// Lower-case phrases that must all appear somewhere in the statement.
  final List<String> detect;

  /// Lower-case heading of the first column, which starts the table.
  final String header;

  /// Lower-case phrases that end the table.
  final List<String> tableEnd;

  /// Finds the spending total the bank prints, for cross-checking OCR.
  final RegExp printedTotal;

  /// Rows matching this are left out of the cross-check total.
  final RegExp? totalExcludes;

  static final publicBank = CardStatementLayout(
    bank: 'Public Bank',
    detect: ['transaction details', 'posting date', 'public bank'],
    header: 'posting date',
    tableEnd: ['this month total', 'grand total'],
    printedTotal: RegExp(
      r'total\s+debit\D{0,12}(\d{1,3}(?:,\d{3})*\.\d{2})',
      caseSensitive: false,
    ),
  );

  static final hsbc = CardStatementLayout(
    bank: 'HSBC',
    detect: ['transaction details', 'post date', 'hsbc'],
    header: 'post date',
    tableEnd: [
      'your charge',
      'your statement balance',
      'total credit limit used',
    ],
    printedTotal: RegExp(
      r'your\s+charge\(?s?\)?\s+for\s+this\s+month\D{0,8}(\d{1,3}(?:,\d{3})*\.\d{2})',
      caseSensitive: false,
    ),
    // HSBC leaves instalment bookings out of "charges for this month".
    totalExcludes: RegExp(r'instal+ment', caseSensitive: false),
  );

  static final all = [publicBank, hsbc];

  static CardStatementLayout? detectFrom(Iterable<String> pageTexts) {
    final text = pageTexts.join('\n').toLowerCase();
    for (final layout in all) {
      if (layout.detect.every(text.contains)) return layout;
    }
    return null;
  }
}

/// Parses OCR lines from a scanned card statement. The PDF is an image, so
/// rows are rebuilt from the positions of the recognized lines.
class CardStatementOcrParser {
  const CardStatementOcrParser(this.layout);

  final CardStatementLayout layout;

  static const _months = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  static final _rowStart = RegExp(
    r'^(\d{2})\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\b\s*'
    r'(?:(\d{2})\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\b)?\s*(.*)$',
  );
  static final _amountEnd = RegExp(
    r'^(.*?)\s*(\d[\d,]*\.\d{2})\s*(CR)?$',
    caseSensitive: false,
  );

  /// Only used when OCR dropped the `CR` marker; a merchant that merely
  /// contains "payment" is a normal purchase.
  static final _creditPhrases = RegExp(
    r'thank you|payment recd|cash\s*back|refund|reversal|rebate',
    caseSensitive: false,
  );

  /// Page furniture that can follow the last row of a page.
  static final _pageFurniture = RegExp(
    r'^(page\s+\d+|continued|bersambung|muka surat)',
    caseSensitive: false,
  );

  StatementParseResult parse(List<List<RecognizedOcrLine>> pages) {
    final allText = [
      for (final page in pages)
        for (final line in page) line.text,
    ].join('\n');
    final pageRows = [for (final page in pages) _physicalRows(page)];
    final labelled = RegExp(
      r'STATEMENT\s+DATE\D{0,6}(\d{1,2})\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s+(\d{4})',
    );
    // The statement date sets the year of every row, so it is never guessed
    // from some other date on the page.
    final statement = labelled.firstMatch(
      [for (final lines in pageRows) ...lines].join('\n').toUpperCase(),
    );
    if (statement == null) {
      throw const FormatException(
        'Could not read the statement date. Try a clearer or complete PDF.',
      );
    }
    final statementYear = int.parse(statement[3]!);
    final statementMonth = _months[statement[2]]!;

    final rows = <StatementRow>[];
    var spendingCents = 0;
    final excludes = layout.totalExcludes;
    String? pending;
    DateTime? pendingDate;
    var pendingAmount = 0;
    var pendingCredit = false;
    var havePending = false;
    var lineNumber = 0;

    void flush() {
      if (!havePending) return;
      final description = pending!.replaceAll(RegExp(r'\s+'), ' ').trim();
      final lower = description.toLowerCase();
      havePending = false;
      if (lower.startsWith('previous balance') ||
          lower.startsWith('baki terdahulu')) {
        return;
      }
      lineNumber++;
      final credit = pendingCredit || _creditPhrases.hasMatch(description);
      final noAmount = pendingAmount <= 0;
      final noDate = pendingDate == null;
      if (!credit && !noAmount && !(excludes?.hasMatch(description) ?? false)) {
        spendingCents += pendingAmount;
      }
      final reason = noAmount
          ? 'No clear amount — type it in or leave this row unticked'
          : noDate
          ? 'Unrecognized date — choose a date'
          : credit
          ? 'Credit, payment, or refund — review before adding'
          : null;
      rows.add(
        StatementRow(
          line: lineNumber,
          description: description,
          date: pendingDate,
          amountCents: noAmount ? null : pendingAmount,
          reason: reason,
          selected: reason == null && description.isNotEmpty,
        ),
      );
    }

    // A day OCR misread (31 SEP, 00 OCT) must not roll into another month.
    DateTime? dateOf(String day, String month) {
      final m = _months[month]!;
      final d = int.parse(day);
      final year = m > statementMonth ? statementYear - 1 : statementYear;
      final date = DateTime(year, m, d, 12);
      return date.month == m && date.day == d ? date : null;
    }

    var inTable = false;
    for (final pageLines in pageRows) {
      for (final physical in pageLines) {
        final lower = physical.toLowerCase();
        if (lower.contains(layout.header)) {
          inTable = true;
          continue;
        }
        if (!inTable) continue;
        if (layout.tableEnd.any(lower.contains)) {
          flush();
          inTable = false;
          continue;
        }
        final start = _rowStart.firstMatch(physical.toUpperCase());
        if (start != null) {
          flush();
          final posting = dateOf(start[1]!, start[2]!);
          var transaction = start[3] == null
              ? posting
              : dateOf(start[3]!, start[4]!);
          // Instalments keep their original purchase date; use the date they
          // were billed in this statement instead.
          if (posting != null &&
              transaction != null &&
              (posting.difference(transaction).inDays > 40 ||
                  transaction.isAfter(posting))) {
            transaction = posting;
          }
          transaction ??= posting;
          var rest = physical.substring(physical.length - start[5]!.length);
          final amount = _amountEnd.firstMatch(rest);
          if (amount == null) {
            pending = rest;
            pendingAmount = 0;
            pendingCredit = false;
          } else {
            pending = amount[1]!;
            pendingAmount = _cents(amount[2]!);
            pendingCredit = amount[3] != null;
          }
          pendingDate = transaction;
          havePending = true;
        } else if (havePending && !_pageFurniture.hasMatch(physical)) {
          final amount = _amountEnd.firstMatch(physical);
          if (amount != null && pendingAmount == 0) {
            pending = '$pending ${amount[1]!}';
            pendingAmount = _cents(amount[2]!);
            pendingCredit = amount[3] != null;
          } else {
            pending = '$pending $physical';
          }
        }
      }
      flush();
    }
    flush();

    final debit = layout.printedTotal.firstMatch(allText);
    String? notice;
    if (debit != null && _cents(debit[1]!) != spendingCents) {
      notice =
          'Parsed spending does not match the statement total (${debit[1]}). '
          'OCR may have misread a row — check every amount against the PDF.';
    } else if (debit == null) {
      notice =
          'Statement total not found, so amounts could not be cross-checked. '
          'Check every amount against the PDF.';
    }
    return StatementParseResult(rows, notice: notice);
  }

  /// Groups OCR fragments that share a baseline into left-to-right rows.
  List<String> _physicalRows(List<RecognizedOcrLine> page) {
    final sorted = page.toList()..sort((a, b) => a.top.compareTo(b.top));
    final groups = <List<RecognizedOcrLine>>[];
    for (final line in sorted) {
      final centre = line.top + line.height / 2;
      final group = groups.isEmpty ? null : groups.last;
      if (group != null) {
        final first = group.first;
        final groupCentre = first.top + first.height / 2;
        if ((centre - groupCentre).abs() <= first.height * 0.6) {
          group.add(line);
          continue;
        }
      }
      groups.add([line]);
    }
    return [
      for (final group in groups)
        (group..sort((a, b) => a.left.compareTo(b.left)))
            .map((line) => line.text.trim())
            .where((text) => text.isNotEmpty)
            .join(' '),
    ];
  }

  int _cents(String raw) {
    final parts = raw.replaceAll(',', '').split('.');
    return int.parse(parts.first) * 100 + int.parse(parts.last);
  }
}
