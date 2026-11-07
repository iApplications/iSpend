import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/widgets/app_toast.dart';
import '../data/pdf_text_extractor.dart';
import '../data/tng_statement_parser.dart';
import 'statement_csv_import_page.dart';

/// Picks a PDF statement, reads it on-device, and opens the shared review page.
Future<void> startPdfStatementImport(BuildContext context) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (files.isEmpty || !context.mounted) return;
  final file = files.first;
  try {
    final bytes = await file.xFile.readAsBytes();
    String text;
    try {
      text = await const PdfTextExtractor().extract(bytes);
    } on PdfPasswordException {
      if (!context.mounted) return;
      final password = await _askPassword(context);
      if (password == null || !context.mounted) return;
      text = await const PdfTextExtractor().extract(bytes, password: password);
    }
    if (!context.mounted) return;
    if (!TngStatementParser.canParse(text)) {
      AppToast.showError(
        context,
        'This PDF is not a supported statement yet. Touch \'n Go card statements are supported.',
      );
      return;
    }
    final rows = const TngStatementParser().parse(text);
    if (rows.isEmpty) {
      AppToast.showError(context, 'No transactions were found in this PDF.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatementCsvImportPage(
          parsedRows: rows,
          sourceLabel: 'Touch \'n Go',
          initialFileName: file.name,
        ),
      ),
    );
  } on PdfPasswordException {
    if (context.mounted) {
      AppToast.showError(context, 'That password did not open the PDF.');
    }
  } catch (_) {
    if (context.mounted) {
      AppToast.showError(context, 'Could not read this PDF.');
    }
  }
}

Future<String?> _askPassword(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('PDF password'),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Password',
          helperText: 'Used only to open this file. It is not stored.',
        ),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Open'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
