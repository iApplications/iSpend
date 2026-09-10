import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/database/recovery_key.dart';

/// Creates a complete, encrypted logical backup without exposing a raw
/// database file. The document can only be opened with the recovery passphrase.
class ManualBackupService {
  const ManualBackupService({RecoveryKeyOperations? recoveryKeyService})
    : _recoveryKeyService = recoveryKeyService ?? const RecoveryKeyService();

  static const format = 'ispend-manual-backup';
  static const version = 1;

  final RecoveryKeyOperations _recoveryKeyService;

  Future<String> export({
    required Database database,
    required String passphrase,
  }) async {
    final payload = <String, Object>{
      'expenses': await database.query('expenses'),
      'categories': await database.query('categories'),
      'payment_methods': await database.query('payment_methods'),
      'app_settings': await database.query('app_settings'),
    };
    final encodedPayload = base64UrlEncode(utf8.encode(jsonEncode(payload)));
    final encryptedPayload = await _recoveryKeyService.wrap(
      databaseKey: encodedPayload,
      passphrase: passphrase,
    );
    return jsonEncode({
      'format': format,
      'version': version,
      'created_at_millis': DateTime.now().millisecondsSinceEpoch,
      'encrypted_payload': encryptedPayload.toJson(),
    });
  }

  Future<void> restore({
    required Database database,
    required String document,
    required String passphrase,
  }) async {
    final root = jsonDecode(document);
    if (root is! Map<String, dynamic> ||
        root['format'] != format ||
        root['version'] != version ||
        root['encrypted_payload'] is! Map<String, dynamic>) {
      throw const FormatException('This is not a supported iSpend backup.');
    }
    final envelope = RecoveryKeyEnvelope.fromJson(
      root['encrypted_payload'] as Map<String, dynamic>,
    );
    final encodedPayload = await _recoveryKeyService.unwrap(
      envelope: envelope,
      passphrase: passphrase,
    );
    final decodedPayload = jsonDecode(
      utf8.decode(base64Url.decode(encodedPayload)),
    );
    if (decodedPayload is! Map<String, dynamic>) {
      throw const FormatException('The backup data is invalid.');
    }

    final expenses = _rows(decodedPayload['expenses']);
    final categories = _rows(decodedPayload['categories']);
    final paymentMethods = _rows(decodedPayload['payment_methods']);
    final settings = _rows(decodedPayload['app_settings']);

    await database.transaction((transaction) async {
      for (final table in const [
        'expenses',
        'categories',
        'payment_methods',
        'app_settings',
      ]) {
        await transaction.delete(table);
      }
      await _insertAll(transaction, 'expenses', expenses);
      await _insertAll(transaction, 'categories', categories);
      await _insertAll(transaction, 'payment_methods', paymentMethods);
      await _insertAll(transaction, 'app_settings', settings);
    });
  }

  static List<Map<String, Object?>> _rows(Object? value) {
    if (value is! List) {
      throw const FormatException('The backup data is invalid.');
    }
    return value.map((row) {
      if (row is! Map) {
        throw const FormatException('The backup data is invalid.');
      }
      return row.map((key, value) => MapEntry(key as String, value));
    }).toList();
  }

  static Future<void> _insertAll(
    Transaction transaction,
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    final batch = transaction.batch();
    for (final row in rows) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.abort);
    }
    await batch.commit(noResult: true);
  }
}
