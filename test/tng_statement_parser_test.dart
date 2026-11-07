import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/statement_import/data/tng_statement_parser.dart';

// Synthetic text in the content order produced by a TNG statement PDF.
const _statement = '''
Customer Transactions Statement
Account Name
: TEST USER
Trans No.
Entry Date
and Time
Offline Card Transactions
100
31/10/2026
19:14:12
31/10/2026
19:14:27
02/11
/2026
Fare
Usage -
Parking
LRT PWTC
TCB26
TC_B26
LRT PWTC
TCB26
TC_B26 5.30 33.52 PARKING
101
30/10/2026
19:07:01
30/10/2026
19:07:01
01/11
/2026
Reload
LRT PWTC
TCB26
TC_B26
LRT PWTC
TCB26
TC_B26 1,050.00 1,083.52 RELOAD
102
29/10/2026
19:09:52
29/10/2026
19:09:53
31/10
/2026
Fare
Usage -
Parking
~~ End of the statement ~~
''';

void main() {
  const parser = TngStatementParser();

  test('recognises a TNG statement', () {
    expect(TngStatementParser.canParse(_statement), isTrue);
    expect(TngStatementParser.canParse('Date,Description,Amount'), isFalse);
  });

  test('parses fare usage as a selected spending row', () {
    final rows = parser.parse(_statement);
    expect(rows, hasLength(3));
    expect(rows[0].amountCents, 530);
    expect(rows[0].date, DateTime(2026, 10, 31, 12));
    expect(rows[0].description, 'Fare Usage - Parking · LRT PWTC');
    expect(rows[0].reason, isNull);
    expect(rows[0].selected, isTrue);
  });

  test('leaves reloads unchecked and keeps thousands separators', () {
    final reload = parser.parse(_statement)[1];
    expect(reload.amountCents, 105000);
    expect(reload.selected, isFalse);
    expect(reload.reason, contains('Reload'));
  });

  test('accepts number and entry date on one line', () {
    final rows = parser.parse(
      _statement.replaceFirst('100\n31/10/2026', '100 31/10/2026'),
    );
    expect(rows, hasLength(3));
    expect(rows[0].amountCents, 530);
  });

  test('a block without an amount line is unchecked', () {
    final row = parser.parse(_statement)[2];
    expect(row.amountCents, isNull);
    expect(row.selected, isFalse);
  });

  test('a negative amount is treated as a refund, not spending', () {
    final rows = parser.parse(
      _statement.replaceFirst(
        'TC_B26 5.30 33.52 PARKING',
        'TC_B26 -5.30 33.52 PARKING',
      ),
    );
    expect(rows[0].amountCents, 530);
    expect(rows[0].selected, isFalse);
  });
}
