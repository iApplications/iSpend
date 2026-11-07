import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Reads the text layer of a PDF on the device. Nothing is uploaded, and a
/// password supplied for an encrypted PDF is used only to open it.
class PdfTextExtractor {
  const PdfTextExtractor();

  static const maxBytes = 10 * 1024 * 1024;

  /// Throws [PdfPasswordException] when [password] is missing or wrong.
  Future<String> extract(Uint8List bytes, {String? password}) async {
    if (bytes.length > maxBytes) {
      throw const FormatException('PDF is larger than 10 MB.');
    }
    final document = await PdfDocument.openData(
      bytes,
      passwordProvider: createSimplePasswordProvider(password),
      firstAttemptByEmptyPassword: true,
    );
    try {
      final buffer = StringBuffer();
      for (final page in document.pages) {
        final text = await page.loadText();
        if (text != null) buffer.writeln(text.fullText);
      }
      return buffer.toString();
    } finally {
      await document.dispose();
    }
  }
}
