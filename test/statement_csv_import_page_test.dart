import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/app_settings_repository.dart';
import 'package:ispend/core/utils/amount_formatter.dart';
import 'package:ispend/features/settings/currency_preference.dart';
import 'package:ispend/features/statement_import/data/statement_mapping_repository.dart';
import 'package:ispend/features/statement_import/data/statement_csv_template.dart';
import 'package:ispend/features/statement_import/presentation/statement_csv_import_page.dart';

void main() {
  testWidgets('exports a blank CSV template through the save picker', (
    tester,
  ) async {
    final fileAccess = _FakeTemplateFileAccess();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statementTemplateFileAccessProvider.overrideWithValue(fileAccess),
        ],
        child: const MaterialApp(home: StatementCsvImportPage()),
      ),
    );

    await tester.tap(find.text('Export CSV template'));
    await tester.pumpAndSettle();
    expect(fileAccess.fileName, StatementCsvTemplate.fileName);
    expect(fileAccess.bytes, StatementCsvTemplate.bytes);
    expect(find.text('CSV template saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('remembered CSV mapping is restored but still requires review', (
    tester,
  ) async {
    final settings = InMemoryAppSettingsRepository();

    Widget page(String csv) => ProviderScope(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
        startupAppCurrencyProvider.overrideWithValue(
          AppCurrency.fromCode('MYR'),
        ),
      ],
      child: MaterialApp(home: StatementCsvImportPage(initialCsvText: csv)),
    );

    await tester.pumpWidget(
      page('Date,Description,Amount\n10/09/2026,Lunch,12.50\n'),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final remember = find.widgetWithText(
      CheckboxListTile,
      'Remember this column mapping',
    );
    expect(find.text('Column mapping'), findsOneWidget);
    await tester.scrollUntilVisible(remember, 250);
    expect(tester.widget<CheckboxListTile>(remember).value, isFalse);
    await tester.tap(remember);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review transactions'));
    await tester.pumpAndSettle();

    final repository = StatementMappingRepository(settings);
    expect(await repository.read(['Date', 'Description', 'Amount']), isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      page('Date,Description,Amount\n11/09/2026,Dinner,8.20\n'),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.textContaining('Saved mapping restored'), findsOneWidget);
    await tester.scrollUntilVisible(remember, 250);
    expect(tester.widget<CheckboxListTile>(remember).value, isTrue);
    expect(find.text('Review transactions'), findsOneWidget);
    expect(find.textContaining('transactions ·'), findsNothing);

    final forget = find.text('Forget saved mapping');
    await tester.scrollUntilVisible(forget, 250);
    await tester.tap(forget);
    await tester.pumpAndSettle();
    expect(await repository.read(['Date', 'Description', 'Amount']), isNull);
    expect(tester.widget<CheckboxListTile>(remember).value, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });
}

class _FakeTemplateFileAccess implements StatementTemplateFileAccess {
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
