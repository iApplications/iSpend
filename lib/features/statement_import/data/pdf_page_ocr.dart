import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../ocr_import/data/shopping_order_candidate.dart';

/// pdfrx renders BGRA; the ML Kit bitmap input reads R,G,B,A.
Uint8List _bgraToRgba(Uint8List bgra) {
  final rgba = Uint8List.fromList(bgra);
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final blue = rgba[i];
    rgba[i] = rgba[i + 2];
    rgba[i + 2] = blue;
  }
  return rgba;
}

/// Renders the pages of a scanned (image-only) PDF and recognizes their text
/// on-device. Page images stay in memory and are never written to disk.
class PdfPageOcr {
  const PdfPageOcr();

  static const _renderWidth = 1600;
  static const maxPages = 12;

  /// Throws [FormatException] for a PDF with too many pages or a page that
  /// cannot be rendered, so no transactions are silently left out.
  Future<List<List<RecognizedOcrLine>>> recognize(
    Uint8List bytes, {
    String? password,
  }) async {
    final document = await PdfDocument.openData(
      bytes,
      passwordProvider: createSimplePasswordProvider(password),
      firstAttemptByEmptyPassword: true,
    );
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final pages = <List<RecognizedOcrLine>>[];
    try {
      if (document.pages.length > maxPages) {
        throw FormatException(
          'This PDF has ${document.pages.length} pages. Scanned statements '
          'of up to $maxPages pages are supported.',
        );
      }
      for (final page in document.pages) {
        final rendered = await page.render(
          fullWidth: _renderWidth.toDouble(),
          fullHeight: _renderWidth * page.height / page.width,
        );
        if (rendered == null) {
          throw FormatException('Page ${page.pageNumber} could not be read.');
        }
        final Uint8List rgba;
        final int width = rendered.width;
        final int height = rendered.height;
        try {
          rgba = await compute(_bgraToRgba, rendered.pixels);
        } finally {
          rendered.dispose();
        }
        final RecognizedText result;
        try {
          result = await recognizer.processImage(
            InputImage.fromBitmap(bitmap: rgba, width: width, height: height),
          );
        } catch (error) {
          throw FormatException(
            'Text recognition failed on page ${page.pageNumber} '
            '(${error.runtimeType}).',
          );
        }
        pages.add([
          for (final block in result.blocks)
            for (final line in block.lines)
              RecognizedOcrLine(
                text: line.text,
                left: line.boundingBox.left,
                top: line.boundingBox.top,
                width: line.boundingBox.width,
                height: line.boundingBox.height,
              ),
        ]);
      }
    } finally {
      await recognizer.close();
      await document.dispose();
    }
    return pages;
  }
}
