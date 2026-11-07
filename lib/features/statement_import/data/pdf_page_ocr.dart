import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../ocr_import/data/shopping_order_candidate.dart';

/// Renders the pages of a scanned (image-only) PDF and recognizes their text
/// on-device. Page images are written to the app cache only for the recognizer
/// and are deleted straight afterwards.
class PdfPageOcr {
  const PdfPageOcr();

  static const _renderWidth = 1600;

  Future<List<List<RecognizedOcrLine>>> recognize(
    Uint8List bytes, {
    String? password,
  }) async {
    final document = await PdfDocument.openData(
      bytes,
      passwordProvider: () => password,
      firstAttemptByEmptyPassword: true,
    );
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final cache = await getTemporaryDirectory();
    final pages = <List<RecognizedOcrLine>>[];
    try {
      for (final page in document.pages) {
        final rendered = await page.render(
          fullWidth: _renderWidth.toDouble(),
          fullHeight: _renderWidth * page.height / page.width,
        );
        if (rendered == null) continue;
        final image = img.Image.fromBytes(
          width: rendered.width,
          height: rendered.height,
          bytes: rendered.pixels.buffer,
          order: img.ChannelOrder.bgra,
        );
        final file = File(
          paths.join(cache.path, 'ispend_pdf_page_${page.pageNumber}.png'),
        );
        try {
          final png = img.encodePng(image);
          rendered.dispose();
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
}
