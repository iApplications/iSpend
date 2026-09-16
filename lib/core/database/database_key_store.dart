import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DatabaseKeyAccess {
  Future<String?> readKey();
  Future<void> writeKey(String key);
  Future<void> deleteKey();
  Future<String> readOrCreateKey();
}

class DatabaseKeyStore implements DatabaseKeyAccess {
  DatabaseKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _databaseKeyName = 'ispend.sqlcipher.database_key.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readKey() => _storage.read(key: _databaseKeyName);

  @override
  Future<void> writeKey(String key) =>
      _storage.write(key: _databaseKeyName, value: key);

  @override
  Future<void> deleteKey() => _storage.delete(key: _databaseKeyName);

  @override
  Future<String> readOrCreateKey() async {
    final existing = await readKey();
    if (existing != null) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await writeKey(key);
    return key;
  }
}
