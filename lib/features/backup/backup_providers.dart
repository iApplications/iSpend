import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/recovery_envelope_store.dart';
import '../../core/database/recovery_key.dart';
import 'data/manual_backup_service.dart';

final backupDatabaseProvider = Provider<Database>(
  (_) => throw UnimplementedError('The encrypted database was not provided.'),
);

final backupDatabaseKeyProvider = Provider<String>(
  (_) =>
      throw UnimplementedError('The encrypted database key was not provided.'),
);

final manualBackupServiceProvider = Provider<ManualBackupOperations>(
  (_) => const ManualBackupService(),
);

abstract interface class BackupFileAccess {
  Future<bool> save({required String fileName, required Uint8List bytes});
  Future<Uint8List?> pick();
}

class FilePickerBackupFileAccess implements BackupFileAccess {
  const FilePickerBackupFileAccess();

  @override
  Future<Uint8List?> pick() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ispendbackup'],
    );
    return selected?.readAsBytes();
  }

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final location = await FilePicker.saveFile(
      dialogTitle: 'Save encrypted iSpend backup',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/octet-stream',
      type: FileType.custom,
      allowedExtensions: ['ispendbackup'],
    );
    return location != null;
  }
}

final backupFileAccessProvider = Provider<BackupFileAccess>(
  (_) => const FilePickerBackupFileAccess(),
);

final recoveryEnvelopeAccessProvider = Provider<RecoveryEnvelopeAccess>(
  (_) => RecoveryEnvelopeStore(),
);

final recoveryKeyOperationsProvider = Provider<RecoveryKeyOperations>(
  (_) => const RecoveryKeyService(),
);
