import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/widgets/app_toast.dart';
import '../data/pdf_page_ocr.dart';
import '../data/pdf_text_extractor.dart';
import '../data/card_statement_ocr_parser.dart';
import '../data/statement_csv_parser.dart';
import '../data/tng_statement_parser.dart';
import 'statement_csv_import_page.dart';

const _unsupported =
    "This PDF is not a supported statement yet. Touch 'n Go, Public Bank and HSBC card statements are supported.";

class _Cancelled implements Exception {
  const _Cancelled();
}

var _importing = false;

/// Picks a PDF statement, reads it on-device, and opens the shared review page.
Future<void> startPdfStatementImport(BuildContext context) async {
  if (_importing) return;
  _importing = true;
  try {
    await _runImport(context);
  } finally {
    _importing = false;
  }
}

Future<void> _runImport(BuildContext context) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (files.isEmpty || !context.mounted) return;
  final file = files.first;
  try {
    if (await file.length() > PdfTextExtractor.maxBytes) {
      throw const FormatException('This PDF is larger than 10 MB.');
    }
    final bytes = await file.xFile.readAsBytes();
    String? password;
    Future<T> withPassword<T>(Future<T> Function(String?) read) async {
      try {
        return await read(password);
      } on PdfPasswordException {
        if (!context.mounted) rethrow;
        password = await _askPassword(context);
        if (password == null) throw const _Cancelled();
        return read(password);
      }
    }

    final text = await withPassword(
      (pw) => const PdfTextExtractor().extract(bytes, password: pw),
    );
    if (!context.mounted) return;
    List<StatementRow> rows;
    String label;
    String? notice;
    if (TngStatementParser.canParse(text)) {
      rows = const TngStatementParser().parse(text);
      label = "Touch 'n Go";
    } else if (text.trim().length < 40) {
      // No text layer: the PDF is a scan, so read it with on-device OCR.
      AppToast.show(context, 'Scanned PDF — reading it on this device…');
      final pages = await withPassword(
        (pw) => const PdfPageOcr().recognize(bytes, password: pw),
      );
      if (!context.mounted) return;
      final layout = CardStatementLayout.detectFrom([
        for (final page in pages) page.map((line) => line.text).join('\n'),
      ]);
      if (layout == null) {
        AppToast.showError(context, _unsupported);
        return;
      }
      final result = CardStatementOcrParser(layout).parse(pages);
      rows = result.rows;
      notice = result.notice;
      label = layout.bank;
    } else {
      AppToast.showError(context, _unsupported);
      return;
    }
    if (rows.isEmpty) {
      AppToast.showError(context, 'No transactions were found in this PDF.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatementCsvImportPage(
          parsedRows: rows,
          sourceLabel: label,
          initialFileName: file.name,
          notice: notice,
        ),
      ),
    );
  } on _Cancelled {
    return;
  } on PdfPasswordException {
    if (context.mounted) {
      AppToast.showError(context, 'That password did not open the PDF.');
    }
  } on FormatException catch (error) {
    if (context.mounted) AppToast.showError(context, error.message);
  } catch (_) {
    if (context.mounted) {
      AppToast.showError(context, 'Could not read this PDF.');
    }
  }
}

Future<String?> _askPassword(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _PasswordDialog(),
);

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('PDF password'),
    content: TextField(
      controller: _controller,
      obscureText: true,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Password',
        helperText: 'Used only to open this file. It is not stored.',
      ),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Open'),
      ),
    ],
  );
}
