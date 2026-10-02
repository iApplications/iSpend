import 'paid_amount_ocr.dart';
import 'shopping_order_candidate.dart';
import 'shopping_order_parser.dart';

/// Suggestions extracted from a single receipt or payment screenshot.
/// Missing or conflicting fields deliberately remain empty for review.
class ReceiptSuggestion {
  const ReceiptSuggestion({
    required this.rawText,
    this.amountCents,
    this.foreignAmountReference,
    this.merchant,
    this.occurredAt,
    this.amountNeedsReview = false,
    this.dateNeedsReview = false,
  });

  final String rawText;
  final int? amountCents;
  final String? foreignAmountReference;
  final String? merchant;
  final DateTime? occurredAt;
  final bool amountNeedsReview;
  final bool dateNeedsReview;
}

class ReceiptParser {
  const ReceiptParser();

  ReceiptSuggestion parse({
    required List<RecognizedOcrLine> input,
    required String currencyCode,
    required String currencySymbol,
  }) {
    final lines = input.where((line) => line.text.trim().isNotEmpty).toList()
      ..sort((a, b) {
        final byTop = a.top.compareTo(b.top);
        return byTop == 0 ? a.left.compareTo(b.left) : byTop;
      });
    final rawText = lines.map((line) => line.text.trim()).join('\n');
    ShoppingOrderCandidate? detailOrder;
    final looksLikeTaobaoDetail =
        RegExp(r'实付款|實付款').hasMatch(rawText) &&
        RegExp(r'付款时间|支付时间').hasMatch(rawText) &&
        RegExp(r'淘宝|淘寶|价格明细|價格明細').hasMatch(rawText);
    // The receipt picker also accepts payment screenshots. A shopping order
    // detail has its item and total far below the page title, so the normal
    // receipt heuristic (first plausible line) would pick OCR-corrupted title
    // text instead. Reuse the order-detail extraction for this layout.
    if (looksLikeTaobaoDetail ||
        (RegExp(r'\border\s+total\b', caseSensitive: false).hasMatch(rawText) &&
            RegExp(
              r'\bmall\b|\bofficial\s+store\b',
              caseSensitive: false,
            ).hasMatch(rawText))) {
      final orders = const ShoppingOrderParser().parseImage(
        imagePath: 'receipt-order-detail',
        lines: lines,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
      );
      if (orders.length == 1 && orders.single.merchant != null) {
        detailOrder = orders.single;
      }
    }
    final amounts = <({int cents, int score})>[];
    String? foreignAmount;
    for (var index = 0; index < lines.length; index++) {
      final label = lines[index].text.toLowerCase();
      if (_nonFinalLabel.hasMatch(label)) continue;
      final score = _labelScore(label);
      if (score == 0) continue;
      foreignAmount ??= foreignPaidAmountReference(
        lines[index].text,
        currencyCode,
        currencySymbol,
      );
      final inline = _amounts(
        normalizePaidAmountOcr(lines[index].text),
        currencyCode,
        currencySymbol,
      );
      if (inline.isNotEmpty) {
        amounts.add((cents: inline.last, score: score));
      } else if (index + 1 < lines.length &&
          !_nonFinalLabel.hasMatch(lines[index + 1].text)) {
        foreignAmount ??= foreignPaidAmountReference(
          lines[index + 1].text,
          currencyCode,
          currencySymbol,
        );
        final nearby = _amounts(
          normalizePaidAmountOcr(lines[index + 1].text),
          currencyCode,
          currencySymbol,
        );
        if (nearby.length == 1) {
          amounts.add((cents: nearby.single, score: score - 10));
        }
      }
    }
    amounts.sort((a, b) => b.score.compareTo(a.score));
    final topScore = amounts.isEmpty ? null : amounts.first.score;
    final strongest = amounts
        .where((amount) => amount.score == topScore)
        .map((amount) => amount.cents)
        .toSet();
    final amount = strongest.length == 1 ? strongest.single : null;

    final dates = <DateTime>{};
    for (final line in lines) {
      if (_nonPurchaseDate.hasMatch(line.text)) continue;
      final parsed = _parseDate(line.text);
      if (parsed != null) dates.add(parsed);
    }

    final resolvedAmount = detailOrder?.amountCents ?? amount;
    final resolvedDate = detailOrder == null
        ? (dates.length == 1 ? dates.single : null)
        : detailOrder.occurredAt;
    return ReceiptSuggestion(
      rawText: rawText,
      amountCents: resolvedAmount,
      foreignAmountReference:
          detailOrder?.foreignAmountReference ?? foreignAmount,
      merchant:
          detailOrder?.merchant ??
          (looksLikeTaobaoDetail ? null : _merchant(lines)),
      occurredAt: resolvedDate,
      amountNeedsReview: resolvedAmount == null,
      dateNeedsReview: resolvedDate == null,
    );
  }

  static final _nonFinalLabel = RegExp(
    r'subtotal|sub total|tax|sst|service charge|shipping|delivery|voucher|discount|cash tendered|change|balance|original price|buy again|运费|优惠|折扣|原价|找零',
    caseSensitive: false,
  );
  static final _nonPurchaseDate = RegExp(
    r'delivery|delivered|shipped|shipment|screenshot|captured|expiry|valid until|送达|发货|截图|有效期',
    caseSensitive: false,
  );

  int _labelScore(String text) {
    if (RegExp(
      r'grand\s*total|total\s*payment|amount\s*paid|paid\s*amount|实付款|實付款|实付|實付',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 100;
    }
    if (RegExp(
      r'amount\s*due|order\s*total|total\s*due|(?:^|\b)total(?:\b|$)|应付|應付|合计|合計',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 80;
    }
    return 0;
  }

  List<int> _amounts(String text, String code, String symbol) {
    // A stated foreign currency must never be silently treated as the app's
    // currency. An unmarked receipt amount can still be suggested for review.
    final currency = RegExp(
      r'(?<![A-Za-z])(?:MYR|RM|SGD|USD|GBP|JPY|EUR|CNY|RMB)(?=\s*\d)|[£$¥€]',
      caseSensitive: false,
    );
    final markers = currency.allMatches(text).map((m) => m.group(0)!).toList();
    if (markers.any((marker) => !_isSelectedCurrency(marker, code, symbol))) {
      return const [];
    }
    final matches = RegExp(
      r'(?<![\d/:-])\d{1,6}(?:,\d{3})*(?:\.\d{1,2})?(?![\d/:-])',
    ).allMatches(text);
    final result = <int>[];
    for (final match in matches) {
      final raw = match.group(0)!.replaceAll(',', '');
      final parts = raw.split('.');
      final whole = int.tryParse(parts.first);
      if (whole == null) continue;
      final cents =
          whole * 100 +
          (parts.length == 2 ? int.parse(parts.last.padRight(2, '0')) : 0);
      if (cents > 0) result.add(cents);
    }
    return result;
  }

  bool _isSelectedCurrency(String marker, String code, String symbol) {
    final value = marker.toUpperCase();
    if (value == code.toUpperCase()) return true;
    if (code.toUpperCase() == 'MYR' && value == 'RM') return true;
    return marker == symbol;
  }

  String? _merchant(List<RecognizedOcrLine> lines) {
    for (final line in lines.take(8)) {
      final text = line.text.trim();
      if (text.length < 2 || !RegExp(r'[a-zA-Z\u3400-\u9fff]').hasMatch(text)) {
        continue;
      }
      if (RegExp(
        r'receipt|invoice|order|date|time|payment|amount|total|tax|sst|change|balance|phone|tel|www\.|http|收据|发票|订单|日期|时间|支付|付款|合计',
        caseSensitive: false,
      ).hasMatch(text)) {
        continue;
      }
      return text;
    }
    return null;
  }

  DateTime? _parseDate(String text) {
    final yearFirst = RegExp(
      r'(?<!\d)(20\d{2})[-/.年](\d{1,2})[-/.月](\d{1,2})(?:日)?(?:\s+(\d{1,2}):(\d{2}))?',
    ).firstMatch(text);
    if (yearFirst != null) {
      return _validDate(
        int.parse(yearFirst.group(1)!),
        int.parse(yearFirst.group(2)!),
        int.parse(yearFirst.group(3)!),
        yearFirst.group(4),
        yearFirst.group(5),
      );
    }
    final dayFirst = RegExp(
      r'(?<!\d)(\d{1,2})[/.](\d{1,2})[/.](20\d{2})(?:\s+(\d{1,2}):(\d{2}))?',
    ).firstMatch(text);
    if (dayFirst == null) return null;
    return _validDate(
      int.parse(dayFirst.group(3)!),
      int.parse(dayFirst.group(2)!),
      int.parse(dayFirst.group(1)!),
      dayFirst.group(4),
      dayFirst.group(5),
    );
  }

  DateTime? _validDate(
    int year,
    int month,
    int day,
    String? hour,
    String? minute,
  ) {
    if (month < 1 || month > 12) return null;
    final h = hour == null ? 12 : int.parse(hour);
    final m = minute == null ? 0 : int.parse(minute);
    if (h > 23 || m > 59) return null;
    final date = DateTime(year, month, day, h, m);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
