import 'dart:convert';
import 'dart:typed_data';

import '../../../core/utils/amount_formatter.dart';
import '../../expenses/data/expense_model.dart';

/// Builds a spreadsheet-friendly CSV from the user's own expenses. Nothing is
/// calculated or advised: it only lists what the user entered.
class ExpenseCsvExporter {
  const ExpenseCsvExporter();

  static const header = [
    'Date',
    'Time',
    'Amount',
    'Currency',
    'Category',
    'Merchant or note',
    'Payment method',
    'Tags',
    'Tax deductible',
  ];

  /// UTF-8 bytes with a byte-order mark so Excel opens non-English merchant
  /// names correctly. Rows are newest first.
  Uint8List build(List<Expense> expenses, {required String currencyCode}) {
    final sorted = expenses.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final lines = [
      header.join(','),
      for (final expense in sorted) _row(expense, currencyCode).join(','),
    ];
    return Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('${lines.join('\r\n')}\r\n'),
    ]);
  }

  List<String> _row(Expense expense, String currencyCode) {
    final at = expense.occurredAt;
    String two(int value) => value.toString().padLeft(2, '0');
    return [
      '${at.year}-${two(at.month)}-${two(at.day)}',
      '${two(at.hour)}:${two(at.minute)}',
      formatCents(expense.amountCents),
      currencyCode,
      _cell(expense.category),
      _cell(expense.merchantOrNote ?? ''),
      _cell(expense.paymentMethod ?? ''),
      _cell(expense.tags.join('; ')),
      expense.isTaxDeductible ? 'Yes' : 'No',
    ];
  }

  /// Quotes a cell, and defuses spreadsheet formulas: a merchant named
  /// "=HYPERLINK(...)" must open as text, not run.
  String _cell(String value) {
    var text = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (text.isNotEmpty && '=+-@\t'.contains(text[0])) text = "'$text";
    if (text.contains(',') || text.contains('"')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
