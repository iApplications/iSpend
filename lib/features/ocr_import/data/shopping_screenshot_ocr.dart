import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'shopping_order_candidate.dart';

/// Runs both bundled script recognizers locally and returns positioned text
/// lines for deterministic order parsing.
class ShoppingScreenshotOcr {
  ShoppingScreenshotOcr()
    : _recognizers = [
        TextRecognizer(script: TextRecognitionScript.latin),
        TextRecognizer(script: TextRecognitionScript.chinese),
      ];

  final List<TextRecognizer> _recognizers;
  bool _closed = false;

  Future<List<RecognizedOcrLine>> recognize(String imagePath) async {
    if (_closed) throw StateError('OCR recognizers are already closed.');
    final inputImage = InputImage.fromFilePath(imagePath);
    final lines = <RecognizedOcrLine>[];
    for (final recognizer in _recognizers) {
      final result = await recognizer.processImage(inputImage);
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final rect = line.boundingBox;
          lines.add(
            RecognizedOcrLine(
              text: line.text,
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
            ),
          );
        }
      }
    }
    return _mergeOverlappingScriptLines(lines);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final recognizer in _recognizers) {
      await recognizer.close();
    }
  }

  List<RecognizedOcrLine> _mergeOverlappingScriptLines(
    List<RecognizedOcrLine> input,
  ) {
    final sorted = input.toList()
      ..sort((a, b) {
        final vertical = a.top.compareTo(b.top);
        return vertical == 0 ? a.left.compareTo(b.left) : vertical;
      });
    final merged = <RecognizedOcrLine>[];
    for (final candidate in sorted) {
      final overlappingIndex = merged.indexWhere(
        (line) => _overlapRatio(line, candidate) >= 0.6,
      );
      if (overlappingIndex < 0) {
        merged.add(candidate);
        continue;
      }
      final existing = merged[overlappingIndex];
      merged[overlappingIndex] = _prefer(candidate, existing);
    }
    return merged;
  }

  double _overlapRatio(RecognizedOcrLine first, RecognizedOcrLine second) {
    final left = first.left > second.left ? first.left : second.left;
    final top = first.top > second.top ? first.top : second.top;
    final rightA = first.left + first.width;
    final rightB = second.left + second.width;
    final bottomA = first.top + first.height;
    final bottomB = second.top + second.height;
    final right = rightA < rightB ? rightA : rightB;
    final bottom = bottomA < bottomB ? bottomA : bottomB;
    final width = (right - left).clamp(0, double.infinity);
    final height = (bottom - top).clamp(0, double.infinity);
    final intersection = width * height;
    final smallest = first.width * first.height < second.width * second.height
        ? first.width * first.height
        : second.width * second.height;
    return smallest <= 0 ? 0 : intersection / smallest;
  }

  RecognizedOcrLine _prefer(
    RecognizedOcrLine candidate,
    RecognizedOcrLine existing,
  ) {
    final candidateHasChinese = _hasChinese(candidate.text);
    final existingHasChinese = _hasChinese(existing.text);
    if (candidateHasChinese != existingHasChinese) {
      return candidateHasChinese ? candidate : existing;
    }
    if (candidate.text.trim().length > existing.text.trim().length) {
      return candidate;
    }
    return existing;
  }

  bool _hasChinese(String text) => RegExp(r'[\u3400-\u9fff]').hasMatch(text);
}
