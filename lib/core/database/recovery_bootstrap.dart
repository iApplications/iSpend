import 'database_key_store.dart';
import 'recovery_envelope_store.dart';
import 'recovery_key.dart';

enum RecoveryBootstrapPath { setup, restore, ready }

class RecoveryBootstrapState {
  const RecoveryBootstrapState({
    required this.path,
    required this.databaseKey,
    required this.envelope,
  });

  final RecoveryBootstrapPath path;
  final String? databaseKey;
  final RecoveryKeyEnvelope? envelope;
}

/// Resolves the recovery-key state before the encrypted database is opened.
/// Keeping this separate from the widget makes the security-critical paths
/// directly testable without a device database.
class RecoveryBootstrap {
  RecoveryBootstrap({
    required DatabaseKeyAccess keyStore,
    required RecoveryEnvelopeAccess envelopeStore,
    required RecoveryKeyOperations recoveryKeyService,
  }) : _keyStore = keyStore,
       _envelopeStore = envelopeStore,
       _recoveryKeyService = recoveryKeyService;

  final DatabaseKeyAccess _keyStore;
  final RecoveryEnvelopeAccess _envelopeStore;
  final RecoveryKeyOperations _recoveryKeyService;

  Future<RecoveryBootstrapState> initialise() async {
    final envelope = await _envelopeStore.read();
    final existingKey = await _keyStore.readKey();
    if (existingKey == null && envelope != null) {
      return RecoveryBootstrapState(
        path: RecoveryBootstrapPath.restore,
        databaseKey: null,
        envelope: envelope,
      );
    }

    final databaseKey = existingKey ?? await _keyStore.readOrCreateKey();
    return RecoveryBootstrapState(
      path: envelope == null
          ? RecoveryBootstrapPath.setup
          : RecoveryBootstrapPath.ready,
      databaseKey: databaseKey,
      envelope: envelope,
    );
  }

  Future<RecoveryKeyEnvelope> createEnvelope({
    required String databaseKey,
    required String passphrase,
  }) async {
    final envelope = await _recoveryKeyService.wrap(
      databaseKey: databaseKey,
      passphrase: passphrase,
    );
    await _envelopeStore.write(envelope);
    return envelope;
  }

  Future<String> restore(
    RecoveryKeyEnvelope envelope,
    String passphrase,
  ) async {
    return _recoveryKeyService.unwrap(
      envelope: envelope,
      passphrase: passphrase,
    );
  }

  /// Call only after SQLCipher has successfully opened the recovered database.
  Future<void> persistRecoveredKey(String databaseKey) async {
    await _keyStore.writeKey(databaseKey);
  }
}
