import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/statement_import/data/pdf_text_extractor.dart';
import 'package:pdfrx/pdfrx.dart';

/// A one-page PDF whose text layer is [text], with a valid cross-reference
/// table so the real PDF engine can open it.
Uint8List _pdfWithText(String text) {
  final content = 'BT /F1 18 Tf 20 100 Td ($text) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] '
        '/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(out.toString()));
}

void main() {
  setUpAll(pdfrxInitialize);

  const extractor = PdfTextExtractor();

  test('reads the text layer of a PDF', () async {
    final text = await extractor.extract(_pdfWithText('Hello iSpend'));
    expect(text, contains('Hello iSpend'));
  });

  test('rejects a PDF larger than the size limit before opening it', () {
    expect(
      extractor.extract(Uint8List(PdfTextExtractor.maxBytes + 1)),
      throwsFormatException,
    );
  });

  test('a file that is not a PDF fails instead of hanging', () {
    expect(
      extractor
          .extract(Uint8List.fromList(utf8.encode('not a pdf at all')))
          .timeout(const Duration(seconds: 20)),
      throwsA(isA<Object>()),
    );
  });
}
