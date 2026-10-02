import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../../expenses/data/expense_repository.dart';

/// Compression runs away from Flutter's UI isolate. The selected source file
/// remains temporary; only the returned, size-limited JPEG may be retained.
Future<Uint8List> compressImageForStorage(String path) =>
    Isolate.run(() => _compress(path));

Uint8List _compress(String path) {
  final source = image.decodeImage(File(path).readAsBytesSync());
  if (source == null) {
    throw const FormatException('The selected image could not be decoded.');
  }
  final oriented = image.bakeOrientation(source);
  for (final maxDimension in [2000, 1600, 1200, 900, 700]) {
    final longest = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longest > maxDimension
        ? oriented.width >= oriented.height
              ? image.copyResize(oriented, width: maxDimension)
              : image.copyResize(oriented, height: maxDimension)
        : oriented;
    for (final quality in [85, 70, 55, 40]) {
      final jpeg = image.encodeJpg(resized, quality: quality);
      if (jpeg.length <= maxExpenseImageBytes) {
        return Uint8List.fromList(jpeg);
      }
    }
  }
  throw const FormatException('The image cannot fit within the 1 MB limit.');
}
