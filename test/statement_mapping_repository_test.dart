import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/app_settings_repository.dart';
import 'package:ispend/features/statement_import/data/statement_csv_parser.dart';
import 'package:ispend/features/statement_import/data/statement_mapping_repository.dart';

void main() {
  const headers = ['Date', 'Description', 'Debit', 'Credit'];
  const mapping = StatementColumnMapping(
    date: 0,
    description: 1,
    debit: 2,
    credit: 3,
    amountMode: StatementAmountMode.debitCredit,
    dateFormat: StatementDateFormat.monthDayYear,
  );

  test(
    'restores a mapping only for the same normalized column layout',
    () async {
      final settings = InMemoryAppSettingsRepository();
      final repository = StatementMappingRepository(settings);
      await repository.save(headers, mapping);

      final restored = await repository.read([
        ' date ',
        'DESCRIPTION',
        'Debit',
        'Credit',
      ]);
      expect(restored?.date, 0);
      expect(restored?.description, 1);
      expect(restored?.debit, 2);
      expect(restored?.credit, 3);
      expect(restored?.amountMode, StatementAmountMode.debitCredit);
      expect(restored?.dateFormat, StatementDateFormat.monthDayYear);
      expect(await repository.read(['Date', 'Description', 'Amount']), isNull);
      expect(
        await repository.read(['Description', 'Date', 'Debit', 'Credit']),
        isNull,
      );
      final stored = await settings.read('statement_csv_mappings_v1');
      expect(stored, isNot(contains('Lunch, cafe')));
    },
  );

  test('invalid mapping cannot be saved or restored', () async {
    final settings = InMemoryAppSettingsRepository();
    final repository = StatementMappingRepository(settings);
    await expectLater(
      repository.save(
        headers,
        const StatementColumnMapping(
          date: 0,
          description: 0,
          debit: 2,
          credit: 3,
          amountMode: StatementAmountMode.debitCredit,
          dateFormat: StatementDateFormat.dayMonthYear,
        ),
      ),
      throwsFormatException,
    );
    await settings.write('statement_csv_mappings_v1', '{bad JSON');
    expect(await repository.read(headers), isNull);
  });

  test('forgotten mapping is not suggested again', () async {
    final settings = InMemoryAppSettingsRepository();
    final repository = StatementMappingRepository(settings);
    await repository.save(headers, mapping);
    await repository.remove(headers);
    expect(await repository.read(headers), isNull);
  });
}
