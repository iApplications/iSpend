import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/statement_import/data/statement_csv_parser.dart';

void main() {
  const parser = StatementCsvParser();

  test('quoted commas and separate debit/credit keep credits unchecked', () {
    final rows = parser.read(
      'Date,Description,Debit,Credit\n'
      '10/09/2026,"Lunch, cafe",12.50,\n'
      '11/09/2026,Refund,,12.50\n',
    );
    final parsed = parser.parse(
      rows,
      const StatementColumnMapping(
        date: 0,
        description: 1,
        debit: 2,
        credit: 3,
        amountMode: StatementAmountMode.debitCredit,
        dateFormat: StatementDateFormat.dayMonthYear,
      ),
    );
    expect(parsed[0].description, 'Lunch, cafe');
    expect(parsed[0].amountCents, 1250);
    expect(parsed[0].selected, isTrue);
    expect(parsed[1].selected, isFalse);
  });

  test(
    'signed interpretation, repayments, and unsigned rows are conservative',
    () {
      final rows = parser.read(
        'Date,Description,Amount\n'
        '2026-09-10,Groceries,-1,234.50\n',
      );
      // A comma in an amount must be quoted in CSV; malformed bank rows stay unchecked.
      final malformed = parser.parse(
        rows,
        const StatementColumnMapping(
          date: 0,
          description: 1,
          amount: 2,
          amountMode: StatementAmountMode.negativeSpending,
          dateFormat: StatementDateFormat.yearMonthDay,
        ),
      );
      expect(malformed.single.selected, isFalse);
      final valid = parser.read(
        'Date,Description,Amount\n'
        '2026-09-10,Groceries,"-1,234.50"\n'
        '2026-09-11,Card repayment,-50.00\n'
        '2026-09-12,Salary,500.00\n',
      );
      const mapping = StatementColumnMapping(
        date: 0,
        description: 1,
        amount: 2,
        amountMode: StatementAmountMode.negativeSpending,
        dateFormat: StatementDateFormat.yearMonthDay,
      );
      final parsed = parser.parse(valid, mapping);
      expect(parsed[0].amountCents, 123450);
      expect(parsed[0].selected, isTrue);
      expect(parsed[1].selected, isFalse);
      expect(parsed[2].selected, isFalse);
      final unsigned = parser.parse(
        valid,
        const StatementColumnMapping(
          date: 0,
          description: 1,
          amount: 2,
          amountMode: StatementAmountMode.unsigned,
          dateFormat: StatementDateFormat.yearMonthDay,
        ),
      );
      expect(unsigned.every((row) => !row.selected), isTrue);
    },
  );

  test('date convention is explicit and impossible dates stay unchecked', () {
    final rows = parser.read(
      'Date,Description,Amount\n'
      '09/10/2026,Coffee,-8.20\n'
      '31/02/2026,Food,-5.00\n',
    );
    final dmy = parser.parse(
      rows,
      const StatementColumnMapping(
        date: 0,
        description: 1,
        amount: 2,
        amountMode: StatementAmountMode.negativeSpending,
        dateFormat: StatementDateFormat.dayMonthYear,
      ),
    );
    final mdy = parser.parse(
      rows,
      const StatementColumnMapping(
        date: 0,
        description: 1,
        amount: 2,
        amountMode: StatementAmountMode.negativeSpending,
        dateFormat: StatementDateFormat.monthDayYear,
      ),
    );
    expect(dmy[0].date?.month, 10);
    expect(mdy[0].date?.month, 9);
    expect(dmy[1].selected, isFalse);
  });

  test(
    'positive-spending mode never auto-selects negative, foreign or transfer',
    () {
      final rows = parser.read(
        'Date,Description,Amount\n'
        '2026-09-10,Petrol,50.00\n'
        '2026-09-11,Refund,-50.00\n'
        '2026-09-12,Transfer,20.00\n'
        '2026-09-13,Foreign shop,USD 12.00\n',
      );
      final parsed = parser.parse(
        rows,
        const StatementColumnMapping(
          date: 0,
          description: 1,
          amount: 2,
          amountMode: StatementAmountMode.positiveSpending,
          dateFormat: StatementDateFormat.yearMonthDay,
        ),
      );
      expect(parsed.map((row) => row.selected), [true, false, false, false]);
    },
  );

  test('unrecognized credit text keeps otherwise valid debit unchecked', () {
    final rows = parser.read(
      'Date,Description,Debit,Credit\n'
      '10/09/2026,Shop,20.00,unknown\n',
    );
    final parsed = parser.parse(
      rows,
      const StatementColumnMapping(
        date: 0,
        description: 1,
        debit: 2,
        credit: 3,
        amountMode: StatementAmountMode.debitCredit,
        dateFormat: StatementDateFormat.dayMonthYear,
      ),
    );
    expect(parsed.single.selected, isFalse);
  });

  test('missing or overlapping mappings fail before review', () {
    final rows = parser.read(
      'Date,Description,Amount\n2026-09-10,Coffee,8.20\n',
    );
    expect(
      () => parser.parse(
        rows,
        const StatementColumnMapping(
          date: 0,
          description: 1,
          amount: 1,
          amountMode: StatementAmountMode.positiveSpending,
          dateFormat: StatementDateFormat.yearMonthDay,
        ),
      ),
      throwsFormatException,
    );
  });
}
