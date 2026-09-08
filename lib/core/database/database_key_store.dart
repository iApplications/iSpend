import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseKeyStore {
  DatabaseKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _databaseKeyName = 'ispend.sqlcipher.database_key.v1';

  final FlutterSecureStorage _storage;

  Future<String> readOrCreateKey() async {
    final existing = await _storage.read(key: _databaseKeyName);
    if (existing != null) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _databaseKeyName, value: key);
    return key;
  }
}
