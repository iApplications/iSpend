import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'data/manual_backup_service.dart';

final backupDatabaseProvider = Provider<Database>(
  (_) => throw UnimplementedError('The encrypted database was not provided.'),
);

final backupDatabaseKeyProvider = Provider<String>(
  (_) =>
      throw UnimplementedError('The encrypted database key was not provided.'),
);

final manualBackupServiceProvider = Provider<ManualBackupService>(
  (_) => const ManualBackupService(),
);
