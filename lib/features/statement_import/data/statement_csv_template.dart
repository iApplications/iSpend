import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Blank signed-amount CSV. No example rows are included, so importing an
/// untouched template cannot create sample expenses.
class StatementCsvTemplate {
  static const fileName = 'ispend-expense-template.csv';
  static const content = 'Date,Description,Amount\r\n';

  static Uint8List get bytes => Uint8List.fromList(utf8.encode(content));
}

abstract interface class StatementTemplateFileAccess {
  Future<bool> save({required String fileName, required Uint8List bytes});
}

class FilePickerStatementTemplateFileAccess
    implements StatementTemplateFileAccess {
  const FilePickerStatementTemplateFileAccess();

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final location = await FilePicker.saveFile(
      dialogTitle: 'Save iSpend CSV template',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    return location != null;
  }
}

final statementTemplateFileAccessProvider =
    Provider<StatementTemplateFileAccess>(
      (_) => const FilePickerStatementTemplateFileAccess(),
    );
