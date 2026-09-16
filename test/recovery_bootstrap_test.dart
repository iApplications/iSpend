import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/database_key_store.dart';
import 'package:ispend/core/database/recovery_bootstrap.dart';
import 'package:ispend/core/database/recovery_envelope_store.dart';
import 'package:ispend/core/database/recovery_key.dart';

void main() {
  test('fresh install creates a key then requires recovery setup', () async {
    final keyStore = _FakeKeyStore();
    final envelopeStore = _FakeEnvelopeStore();
    final bootstrap = RecoveryBootstrap(
      keyStore: keyStore,
      envelopeStore: envelopeStore,
      recoveryKeyService: _FakeRecoveryKeyService(),
      localDatabaseDeleter: () async {},
    );

    final state = await bootstrap.initialise();

    expect(state.path, RecoveryBootstrapPath.setup);
    expect(state.databaseKey, 'fresh-database-key');
    expect(keyStore.createdKey, isTrue);
  });

  test(
    'restore path only persists a recovered key after the caller confirms it',
    () async {
      final keyStore = _FakeKeyStore();
      final envelopeStore = _FakeEnvelopeStore(envelope: _testEnvelope);
      final bootstrap = RecoveryBootstrap(
        keyStore: keyStore,
        envelopeStore: envelopeStore,
        recoveryKeyService: _FakeRecoveryKeyService(),
        localDatabaseDeleter: () async {},
      );

      final state = await bootstrap.initialise();
      expect(state.path, RecoveryBootstrapPath.restore);
      expect(keyStore.key, isNull);

      await expectLater(
        bootstrap.restore(state.envelope!, 'wrong passphrase'),
        throwsA(isA<RecoveryPassphraseException>()),
      );
      expect(keyStore.key, isNull);

      final restoredKey = await bootstrap.restore(
        state.envelope!,
        'correct passphrase',
      );
      expect(restoredKey, 'restored-database-key');
      expect(keyStore.key, isNull);
      await bootstrap.persistRecoveredKey(restoredKey);
      expect(keyStore.key, 'restored-database-key');
    },
  );

  test(
    'start fresh clears only local recovery state then requires setup',
    () async {
      final keyStore = _FakeKeyStore();
      final envelopeStore = _FakeEnvelopeStore(envelope: _testEnvelope);
      var localDatabaseWasDeleted = false;
      final bootstrap = RecoveryBootstrap(
        keyStore: keyStore,
        envelopeStore: envelopeStore,
        recoveryKeyService: _FakeRecoveryKeyService(),
        localDatabaseDeleter: () async => localDatabaseWasDeleted = true,
      );

      expect(
        (await bootstrap.initialise()).path,
        RecoveryBootstrapPath.restore,
      );

      final fresh = await bootstrap.startFresh();

      expect(localDatabaseWasDeleted, isTrue);
      expect(envelopeStore.envelope, isNull);
      expect(keyStore.key, 'fresh-database-key');
      expect(fresh.path, RecoveryBootstrapPath.setup);
      expect((await bootstrap.initialise()).path, RecoveryBootstrapPath.setup);
    },
  );
}

final _testEnvelope = RecoveryKeyEnvelope(
  salt: Uint8List.fromList([1]),
  nonce: Uint8List.fromList([2]),
  ciphertext: Uint8List.fromList([3]),
);

class _FakeKeyStore implements DatabaseKeyAccess {
  String? key;
  bool createdKey = false;

  @override
  Future<String?> readKey() async => key;

  @override
  Future<String> readOrCreateKey() async {
    createdKey = true;
    return key ??= 'fresh-database-key';
  }

  @override
  Future<void> writeKey(String value) async {
    key = value;
  }

  @override
  Future<void> deleteKey() async {
    key = null;
  }
}

class _FakeEnvelopeStore implements RecoveryEnvelopeAccess {
  _FakeEnvelopeStore({this.envelope});

  RecoveryKeyEnvelope? envelope;

  @override
  Future<RecoveryKeyEnvelope?> read() async => envelope;

  @override
  Future<void> write(RecoveryKeyEnvelope value) async {
    envelope = value;
  }

  @override
  Future<void> delete() async {
    envelope = null;
  }
}

class _FakeRecoveryKeyService implements RecoveryKeyOperations {
  @override
  Future<RecoveryKeyEnvelope> wrap({
    required String databaseKey,
    required String passphrase,
  }) async => _testEnvelope;

  @override
  Future<String> unwrap({
    required RecoveryKeyEnvelope envelope,
    required String passphrase,
  }) async {
    if (passphrase != 'correct passphrase') {
      throw const RecoveryPassphraseException();
    }
    return 'restored-database-key';
  }
}
