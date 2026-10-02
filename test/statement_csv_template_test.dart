import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/statement_import/data/statement_csv_parser.dart';
import 'package:ispend/features/statement_import/data/statement_csv_template.dart';

void main() {
  test('exported template is a blank importable CSV', () {
    expect(StatementCsvTemplate.fileName, endsWith('.csv'));
    final csv = utf8.decode(StatementCsvTemplate.bytes);
    expect(csv, 'Date,Description,Amount\r\n');
    expect(const StatementCsvParser().read(csv), [
      ['Date', 'Description', 'Amount'],
    ]);
  });
}
