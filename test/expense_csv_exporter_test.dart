import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/utils/amount_formatter.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/expense_providers.dart';
import 'package:ispend/features/export/data/expense_csv_exporter.dart';
import 'package:ispend/features/export/export_providers.dart';
import 'package:ispend/features/export/presentation/export_data_page.dart';
import 'package:ispend/features/settings/currency_preference.dart';
import 'dart:typed_data';

Expense _expense(
  String id,
  int cents,
  DateTime at, {
  String? note,
  bool tax = false,
}) => Expense(
  id: id,
  amountCents: cents,
  category: 'Food',
  occurredAt: at,
  createdAt: at,
  merchantOrNote: note,
  paymentMethod: 'Cash',
  isTaxDeductible: tax,
);

String _text(Uint8List bytes) => utf8.decode(bytes.sublist(3));

void main() {
  const exporter = ExpenseCsvExporter();

  test('writes a header, a byte-order mark and rows newest first', () {
    final bytes = exporter.build([
      _expense('a', 1250, DateTime(2026, 10, 1, 9, 5), note: 'Lunch'),
      _expense('b', 99900, DateTime(2026, 10, 3, 18, 30), tax: true),
    ], currencyCode: 'MYR');
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final lines = _text(bytes).trim().split('\r\n');
    expect(lines.first, ExpenseCsvExporter.headerFor('MYR').join(','));
    expect(lines[1], '2026-10-03,18:30,999.00,MYR,Food,,Cash,,Yes,999.00,');
    expect(lines[2], '2026-10-01,09:05,12.50,MYR,Food,Lunch,Cash,,No,12.50,');
  });

  test('a foreign expense shows what was paid, then the converted amount', () {
    final lines = _text(
      exporter.build([
        Expense(
          id: 'f',
          amountCents: 4860,
          category: 'Food',
          occurredAt: DateTime(2026, 10, 5, 12, 30),
          createdAt: DateTime(2026, 10, 5),
          originalAmountCents: 1200,
          originalCurrency: 'USD',
          exchangeRate: 4.05,
        ),
      ], currencyCode: 'MYR'),
    ).trim().split('\r\n');
    expect(lines.first, contains('Amount in MYR'));
    expect(lines[1], '2026-10-05,12:30,12.00,USD,Food,,,,No,48.60,4.05');
  });

  test('quotes commas and quotes, and keeps one row per expense', () {
    final text = _text(
      exporter.build([
        _expense(
          'a',
          100,
          DateTime(2026, 10, 1),
          note: 'Tea, "large"\nwith milk',
        ),
      ], currencyCode: 'MYR'),
    );
    expect(text, contains('"Tea, ""large"" with milk"'));
    expect(text.trim().split('\r\n'), hasLength(2));
  });

  test('defuses spreadsheet formulas in text cells', () {
    final text = _text(
      exporter.build([
        _expense('a', 100, DateTime(2026, 10, 1), note: '=HYPERLINK("x")'),
        _expense('b', 100, DateTime(2026, 10, 2), note: '+cmd'),
      ], currencyCode: 'MYR'),
    );
    expect(text, contains("\"'=HYPERLINK(\"\"x\"\")\""));
    expect(text, contains("'+cmd"));
  });

  testWidgets('exports only tax-deductible expenses for the chosen year', (
    tester,
  ) async {
    final access = _FakeExportAccess();
    final notifier = _FixedExpenses([
      _expense('a', 1000, DateTime(2025, 5, 1), tax: true),
      _expense('b', 2000, DateTime(2026, 5, 1), tax: true),
      _expense('c', 3000, DateTime(2026, 6, 1)),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportFileAccessProvider.overrideWithValue(access),
          expensesProvider.overrideWith(() => notifier),
          startupAppCurrencyProvider.overrideWithValue(
            AppCurrency.fromCode('MYR'),
          ),
        ],
        child: const MaterialApp(home: ExportDataPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export tax-deductible'));
    await tester.pumpAndSettle();
    expect(find.text('Save an unencrypted file?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(access.fileName, 'ispend-tax-deductible-2026.csv');
    final lines = _text(access.bytes!).trim().split('\r\n');
    expect(lines, hasLength(2));
    expect(lines[1], contains('20.00'));
    await tester.pump(const Duration(seconds: 3));
  });
}

class _FakeExportAccess implements ExportFileAccess {
  String? fileName;
  Uint8List? bytes;

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    this.fileName = fileName;
    this.bytes = bytes;
    return true;
  }
}

class _FixedExpenses extends ExpensesNotifier {
  _FixedExpenses(this._items);
  final List<Expense> _items;

  @override
  List<Expense> build() => _items;
}
