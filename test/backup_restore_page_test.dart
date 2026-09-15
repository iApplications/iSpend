import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/recovery_envelope_store.dart';
import 'package:ispend/core/database/recovery_key.dart';
import 'package:ispend/features/backup/backup_providers.dart';
import 'package:ispend/features/backup/data/manual_backup_service.dart';
import 'package:ispend/features/backup/presentation/backup_restore_page.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

void main() {
  testWidgets('Backup & Restore shows a success toast after exporting', (
    tester,
  ) async {
    final files = _FakeBackupFiles();
    await tester.pumpWidget(
      _page(
        files: files,
        service: _FakeManualBackupService(),
        keys: _FakeRecoveryKeys(),
      ),
    );

    await tester.tap(find.text('Create backup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct passphrase');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Backup saved'), findsOneWidget);
    expect(files.saved, isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Backup & Restore shows a clear invalid-file error toast', (
    tester,
  ) async {
    final files = _FakeBackupFiles(picked: Uint8List.fromList([1, 2, 3]));
    await tester.pumpWidget(
      _page(
        files: files,
        service: _FakeManualBackupService(
          restoreError: const FormatException(),
        ),
        keys: _FakeRecoveryKeys(),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Restore backup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct passphrase');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pump();

    expect(find.text('This is not a supported iSpend backup.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}

Widget _page({
  required BackupFileAccess files,
  required ManualBackupOperations service,
  required RecoveryKeyOperations keys,
}) {
  return ProviderScope(
    overrides: [
      backupDatabaseProvider.overrideWithValue(_FakeDatabase()),
      backupDatabaseKeyProvider.overrideWithValue('test-database-key'),
      backupFileAccessProvider.overrideWithValue(files),
      manualBackupServiceProvider.overrideWithValue(service),
      recoveryKeyOperationsProvider.overrideWithValue(keys),
      recoveryEnvelopeAccessProvider.overrideWithValue(_FakeEnvelopeStore()),
    ],
    child: const MaterialApp(home: BackupRestorePage()),
  );
}

class _FakeDatabase extends Fake implements Database {}

class _FakeBackupFiles implements BackupFileAccess {
  _FakeBackupFiles({this.picked});

  final Uint8List? picked;
  bool saved = false;

  @override
  Future<Uint8List?> pick() async => picked;

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    saved = true;
    return true;
  }
}

class _FakeManualBackupService implements ManualBackupOperations {
  _FakeManualBackupService({this.restoreError});

  final Object? restoreError;

  @override
  Future<String> export({
    required Database database,
    required String passphrase,
  }) async => '{}';

  @override
  Future<void> restore({
    required Database database,
    required String document,
    required String passphrase,
  }) async {
    if (restoreError != null) throw restoreError!;
  }
}

class _FakeRecoveryKeys implements RecoveryKeyOperations {
  final envelope = RecoveryKeyEnvelope(
    salt: Uint8List(16),
    nonce: Uint8List(12),
    ciphertext: Uint8List.fromList([1]),
  );

  @override
  Future<RecoveryKeyEnvelope> wrap({
    required String databaseKey,
    required String passphrase,
  }) async => envelope;

  @override
  Future<String> unwrap({
    required RecoveryKeyEnvelope envelope,
    required String passphrase,
  }) async => 'test-database-key';
}

class _FakeEnvelopeStore implements RecoveryEnvelopeAccess {
  RecoveryKeyEnvelope? envelope = RecoveryKeyEnvelope(
    salt: Uint8List(16),
    nonce: Uint8List(12),
    ciphertext: Uint8List.fromList([1]),
  );

  @override
  Future<RecoveryKeyEnvelope?> read() async => envelope;

  @override
  Future<void> write(RecoveryKeyEnvelope value) async {
    envelope = value;
  }
}
