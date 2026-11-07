import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/app_lock.dart';

abstract interface class ExportFileAccess {
  /// Returns false when the user cancels the save dialog.
  Future<bool> save({required String fileName, required Uint8List bytes});
}

class FilePickerExportFileAccess implements ExportFileAccess {
  const FilePickerExportFileAccess();

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final location = await AppLockPause.during(
      () => FilePicker.saveFile(
        dialogTitle: 'Save expense export',
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      ),
    );
    return location != null;
  }
}

final exportFileAccessProvider = Provider<ExportFileAccess>(
  (_) => const FilePickerExportFileAccess(),
);
