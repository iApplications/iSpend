import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/ocr_import/data/shopping_order_candidate.dart';
import 'package:ispend/features/statement_import/data/card_statement_ocr_parser.dart';

RecognizedOcrLine _line(String text, double left, double top) =>
    RecognizedOcrLine(text: text, left: left, top: top, width: 100, height: 16);

/// Fake rows laid out like a Public Bank card statement (posting date,
/// transaction date, description, amount), each as separate OCR fragments.
List<RecognizedOcrLine> _page({String totalDebit = '340.50'}) {
  var y = 100.0;
  final lines = <RecognizedOcrLine>[
    _line('STATEMENT DATE', 700, 10),
    _line('15 OCT 2026', 900, 10),
    _line('Transaction Details', 80, 60),
    _line('Posting Date', 80, y),
    _line('Transaction Date', 200, y),
    _line('Amount (RM)', 900, y),
  ];
  void row(String posting, String? trans, String desc, String? amount) {
    y += 40;
    lines.add(_line(posting, 80, y));
    if (trans != null) lines.add(_line(trans, 210, y));
    lines.add(_line(desc, 340, y));
    if (amount != null) lines.add(_line(amount, 900, y));
  }

  void continuation(String text) {
    y += 20;
    lines.add(_line(text, 340, y));
  }

  row('16 SEP', null, 'Previous Balance', '100.00');
  row('16 SEP', '07 FEB', 'SHOP-ONE KEPONG MY', '100.00');
  continuation('INST#9/12 \$300.00');
  row('21 SEP', '20 SEP', 'CAFE TWO KUALA LUMPUR MY', '40.50');
  row('27 SEP', '26 SEP', 'PLUS TOLL LANE-EC PETALING JAYA MY', '200.00');
  row('28 SEP', '28 SEP', 'MOBILE BANKING PAYMENT RECD-THANK YOU', '100.00CR');
  continuation('TEST USER');
  row('15 OCT', '', 'CASH BACK BONUS', '1.00CR');
  y += 40;
  lines.add(_line('This month total credit', 340, y));
  lines.add(_line('101.00', 600, y));
  y += 20;
  lines.add(_line('This month total debit', 340, y));
  lines.add(_line(totalDebit, 600, y));
  return lines;
}

void main() {
  final parser = CardStatementOcrParser(CardStatementLayout.publicBank);

  test('recognises each bank layout', () {
    expect(
      CardStatementLayout.detectFrom([
        'PUBLIC BANK',
        'Transaction Details',
        'Posting Date',
      ]),
      same(CardStatementLayout.publicBank),
    );
    expect(
      CardStatementLayout.detectFrom([
        'HSBC Account Statement',
        'Transaction details',
        'Post date',
      ]),
      same(CardStatementLayout.hsbc),
    );
    expect(CardStatementLayout.detectFrom(['Date,Description']), isNull);
  });

  test('parses spending, skips the opening balance, flags credits', () {
    final result = parser.parse([_page()]);
    final rows = result.rows;
    expect(rows.map((r) => r.description), [
      'SHOP-ONE KEPONG MY INST#9/12 \$300.00',
      'CAFE TWO KUALA LUMPUR MY',
      'PLUS TOLL LANE-EC PETALING JAYA MY',
      'MOBILE BANKING PAYMENT RECD-THANK YOU TEST USER',
      'CASH BACK BONUS',
    ]);
    expect(rows.map((r) => r.amountCents), [10000, 4050, 20000, 10000, 100]);
    expect(rows.map((r) => r.selected), [true, true, true, false, false]);
    expect(result.notice, isNull);
  });

  test('uses the transaction date, or the posting date for instalments', () {
    final rows = parser.parse([_page()]).rows;
    expect(rows[0].date, DateTime(2026, 9, 16, 12));
    expect(rows[1].date, DateTime(2026, 9, 20, 12));
    expect(rows[2].date, DateTime(2026, 9, 26, 12));
  });

  test('puts December dates in the previous year for a January statement', () {
    final page = _page()
        .map(
          (l) =>
              l.text == '15 OCT 2026' ? _line('15 JAN 2027', l.left, l.top) : l,
        )
        .toList();
    expect(parser.parse([page]).rows[1].date, DateTime(2026, 9, 20, 12));
  });

  test('warns when parsed spending differs from the statement total', () {
    final result = parser.parse([_page(totalDebit: '999.99')]);
    expect(result.notice, contains('999.99'));
  });

  test('parses an HSBC statement with foreign-currency lines', () {
    final hsbc = CardStatementOcrParser(CardStatementLayout.hsbc);
    var y = 100.0;
    final lines = <RecognizedOcrLine>[
      _line('Statement Date', 80, 10),
      _line('20 Oct 2026', 300, 10),
      _line('HSBC', 800, 10),
      _line('Transaction details', 340, 60),
      _line('Post date', 80, y),
      _line('Transaction date', 210, y),
    ];
    void row(String post, String trans, String desc, String amount) {
      y += 40;
      lines
        ..add(_line(post, 80, y))
        ..add(_line(trans, 210, y))
        ..add(_line(desc, 340, y))
        ..add(_line(amount, 900, y));
    }

    void continuation(String text) {
      y += 20;
      lines.add(_line(text, 340, y));
    }

    y += 20;
    lines.add(_line('Your Previous Statement Balance', 340, y));
    lines.add(_line('100.00', 900, y));
    row('28 SEP', '28 SEP', 'PAYMENT - THANK YOU', '100.00CR');
    row('23 SEP', '21 SEP', 'PETRON JALAN SELAYANG BATU CAVES MY', '61.78');
    row('25 SEP', '24 SEP', 'ALP*QRCode8934 Shanghai CN', '60.26');
    continuation('97.00 CNY');
    row('20 OCT', '20 OCT', 'IPP LOAN BOOKING - 18/ 24 INSTALMENT', '91.62');
    y += 30;
    lines.add(_line('Your charge(s) for this month RM122.04', 340, y));
    y += 30;
    lines.add(_line('Your statement balance', 340, y));
    lines.add(_line('213.66', 900, y));

    final result = hsbc.parse([lines]);
    expect(result.rows.map((r) => r.amountCents), [10000, 6178, 6026, 9162]);
    expect(result.rows[2].description, 'ALP*QRCode8934 Shanghai CN 97.00 CNY');
    expect(result.rows.map((r) => r.selected), [false, true, true, true]);
    expect(result.rows[1].date, DateTime(2026, 9, 21, 12));
    // 61.78 + 60.26 = 122.04; the instalment booking is excluded.
    expect(result.notice, isNull);
  });
}
