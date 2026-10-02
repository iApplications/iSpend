import 'dart:convert';

import '../../../core/database/app_settings_repository.dart';
import 'statement_csv_parser.dart';

/// Stores only CSV interpretation choices, never statement rows or file paths.
class StatementMappingRepository {
  const StatementMappingRepository(this._settings);

  static const _settingKey = 'statement_csv_mappings_v1';
  static const _maximumMappings = 20;

  final AppSettingsRepository _settings;

  Future<StatementColumnMapping?> read(List<String> headers) async {
    final mappings = await _readAll();
    final value = mappings[_signature(headers)];
    if (value is! Map<String, dynamic>) return null;
    final mode = _enumByName(StatementAmountMode.values, value['amountMode']);
    final dateFormat = _enumByName(
      StatementDateFormat.values,
      value['dateFormat'],
    );
    if (mode == null || dateFormat == null) return null;
    final mapping = StatementColumnMapping(
      date: value['date'] is int ? value['date'] as int : -1,
      description: value['description'] is int
          ? value['description'] as int
          : -1,
      amount: value['amount'] is int ? value['amount'] as int : null,
      debit: value['debit'] is int ? value['debit'] as int : null,
      credit: value['credit'] is int ? value['credit'] as int : null,
      amountMode: mode,
      dateFormat: dateFormat,
    );
    return _isValid(mapping, headers.length) ? mapping : null;
  }

  Future<void> save(
    List<String> headers,
    StatementColumnMapping mapping,
  ) async {
    if (!_isValid(mapping, headers.length)) {
      throw const FormatException('Invalid CSV column mapping.');
    }
    final mappings = await _readAll();
    mappings.remove(_signature(headers));
    mappings[_signature(headers)] = {
      'date': mapping.date,
      'description': mapping.description,
      'amount': mapping.amount,
      'debit': mapping.debit,
      'credit': mapping.credit,
      'amountMode': mapping.amountMode.name,
      'dateFormat': mapping.dateFormat.name,
    };
    while (mappings.length > _maximumMappings) {
      mappings.remove(mappings.keys.first);
    }
    await _settings.write(_settingKey, jsonEncode(mappings));
  }

  Future<void> remove(List<String> headers) async {
    final mappings = await _readAll();
    if (mappings.remove(_signature(headers)) != null) {
      await _settings.write(_settingKey, jsonEncode(mappings));
    }
  }

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final raw = await _settings.read(_settingKey);
      if (raw == null) return {};
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : {};
    } on FormatException {
      return {};
    }
  }

  String _signature(List<String> headers) => jsonEncode([
    for (final header in headers)
      header.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
  ]);

  T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  bool _isValid(StatementColumnMapping mapping, int width) {
    if (width < 2) return false;
    final selected = [
      mapping.date,
      mapping.description,
      if (mapping.amountMode == StatementAmountMode.debitCredit) ...[
        mapping.debit ?? -1,
        mapping.credit ?? -1,
      ] else
        mapping.amount ?? -1,
    ];
    return selected.every((index) => index >= 0 && index < width) &&
        selected.toSet().length == selected.length;
  }
}
