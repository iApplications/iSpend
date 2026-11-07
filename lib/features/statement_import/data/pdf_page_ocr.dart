import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../ocr_import/data/shopping_order_candidate.dart';

class _RawPage {
  const _RawPage(this.width, this.height, this.bgra);

  final int width;
  final int height;
  final Uint8List bgra;
}

Uint8List _encodePng(_RawPage page) => img.encodePng(
  img.Image.fromBytes(
    width: page.width,
    height: page.height,
    bytes: page.bgra.buffer,
    order: img.ChannelOrder.bgra,
  ),
);

/// Renders the pages of a scanned (image-only) PDF and recognizes their text
/// on-device. Page images are written to the app cache only for the recognizer
/// and are deleted straight afterwards.
class PdfPageOcr {
  const PdfPageOcr();

  static const _renderWidth = 1600;
  static const maxPages = 12;
  static const _filePrefix = 'ispend_pdf_page_';

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
    final cache = await getTemporaryDirectory();
    final pages = <List<RecognizedOcrLine>>[];
    try {
      if (document.pages.length > maxPages) {
        throw FormatException(
          'This PDF has ${document.pages.length} pages. Scanned statements '
          'of up to $maxPages pages are supported.',
        );
      }
      await _sweepStaleImages(cache);
      final stamp = DateTime.now().microsecondsSinceEpoch;
      for (final page in document.pages) {
        final rendered = await page.render(
          fullWidth: _renderWidth.toDouble(),
          fullHeight: _renderWidth * page.height / page.width,
        );
        if (rendered == null) {
          throw FormatException('Page ${page.pageNumber} could not be read.');
        }
        final Uint8List png;
        try {
          png = await compute(
            _encodePng,
            _RawPage(
              rendered.width,
              rendered.height,
              Uint8List.fromList(rendered.pixels),
            ),
          );
        } finally {
          rendered.dispose();
        }
        final file = File(
          paths.join(cache.path, '$_filePrefix${stamp}_${page.pageNumber}.png'),
        );
        try {
          await file.writeAsBytes(png, flush: true);
          final result = await recognizer.processImage(
            InputImage.fromFilePath(file.path),
          );
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
        } finally {
          if (await file.exists()) await file.delete();
        }
      }
    } finally {
      await recognizer.close();
      await document.dispose();
    }
    return pages;
  }

  /// A crash or kill mid-scan can leave page images (financial data) behind.
  Future<void> _sweepStaleImages(Directory cache) async {
    try {
      await for (final entity in cache.list()) {
        if (entity is File &&
            paths.basename(entity.path).startsWith(_filePrefix)) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Cleanup must not block the import.
    }
  }
}
