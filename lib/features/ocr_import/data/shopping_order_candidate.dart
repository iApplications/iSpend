enum ShoppingOrderStatus { paid, needsReview, cancelled, refunded, unpaid }

enum ShoppingPlatform { shopee, lazada, taobao, unknown }

/// A reviewable expense candidate found in a user-selected order-list image.
class ShoppingOrderCandidate {
  const ShoppingOrderCandidate({
    required this.id,
    required this.sourceImagePath,
    required this.rawText,
    required this.status,
    this.orderReference,
    this.platform = ShoppingPlatform.unknown,
    this.foreignAmountReference,
    this.merchant,
    this.amountCents,
    this.occurredAt,
  });

  final String id;
  final String sourceImagePath;
  final String rawText;
  final ShoppingOrderStatus status;
  final String? orderReference;
  final ShoppingPlatform platform;
  final String? foreignAmountReference;
  final String? merchant;
  final int? amountCents;
  final DateTime? occurredAt;

  bool get canImportByDefault =>
      status == ShoppingOrderStatus.paid &&
      amountCents != null &&
      occurredAt != null;
}

/// OCR text plus its position, kept independent from the ML Kit plugin so the
/// order parser can be tested with deterministic fixtures.
class RecognizedOcrLine {
  const RecognizedOcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
}
