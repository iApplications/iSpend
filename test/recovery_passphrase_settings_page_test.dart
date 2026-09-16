import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/recovery_envelope_store.dart';
import 'package:ispend/core/database/recovery_key.dart';
import 'package:ispend/features/backup/backup_providers.dart';
import 'package:ispend/features/settings/presentation/recovery_passphrase_settings_page.dart';

void main() {
  testWidgets(
    'sets a new recovery passphrase from the device-held database key',
    (tester) async {
      final keys = _FakeRecoveryKeys();
      final envelopeStore = _FakeEnvelopeStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backupDatabaseKeyProvider.overrideWithValue('device-database-key'),
            recoveryKeyOperationsProvider.overrideWithValue(keys),
            recoveryEnvelopeAccessProvider.overrideWithValue(envelopeStore),
          ],
          child: const MaterialApp(home: RecoveryPassphraseSettingsPage()),
        ),
      );

      expect(find.text('Current recovery passphrase'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'New recovery passphrase'),
        'a new safe passphrase',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm new recovery passphrase'),
        'a new safe passphrase',
      );
      await tester.tap(find.text('Set new recovery passphrase'));
      await tester.pump();

      expect(keys.databaseKey, 'device-database-key');
      expect(keys.passphrase, 'a new safe passphrase');
      expect(envelopeStore.envelope, same(keys.envelope));
      expect(find.text('Recovery passphrase updated'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}

class _FakeRecoveryKeys implements RecoveryKeyOperations {
  final envelope = RecoveryKeyEnvelope(
    salt: Uint8List(16),
    nonce: Uint8List(12),
    ciphertext: Uint8List.fromList([1]),
  );
  String? databaseKey;
  String? passphrase;

  @override
  Future<RecoveryKeyEnvelope> wrap({
    required String databaseKey,
    required String passphrase,
  }) async {
    this.databaseKey = databaseKey;
    this.passphrase = passphrase;
    return envelope;
  }

  @override
  Future<String> unwrap({
    required RecoveryKeyEnvelope envelope,
    required String passphrase,
  }) => throw UnimplementedError();
}

class _FakeEnvelopeStore implements RecoveryEnvelopeAccess {
  RecoveryKeyEnvelope? envelope;

  @override
  Future<void> delete() async => envelope = null;

  @override
  Future<RecoveryKeyEnvelope?> read() async => envelope;

  @override
  Future<void> write(RecoveryKeyEnvelope value) async => envelope = value;
}
