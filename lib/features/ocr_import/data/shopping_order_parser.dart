import 'paid_amount_ocr.dart';
import 'shopping_order_candidate.dart';

/// A receipt picker should hand a recognized multi-order Taobao list to the
/// batch reviewer, rather than reducing it to one receipt suggestion.
bool hasMultipleTaobaoOrderCards(Iterable<ShoppingOrderCandidate> candidates) =>
    candidates
        .where(
          (candidate) =>
              candidate.platform == ShoppingPlatform.taobao &&
              candidate.merchant != null &&
              RegExp(r'实付款|實付款|交易成功').hasMatch(candidate.rawText),
        )
        .take(2)
        .length ==
    2;

/// Deterministic, on-device interpretation of order-list OCR text.
///
/// The parser is intentionally conservative: only explicit final-payment
/// labels produce an amount, and only explicitly labeled order/payment dates
/// produce an occurrence date. Delivery, completion, and capture dates are
/// never substituted for a purchase date.
class ShoppingOrderParser {
  const ShoppingOrderParser();

  List<ShoppingOrderCandidate> parseImage({
    required String imagePath,
    required List<RecognizedOcrLine> lines,
    required String currencyCode,
    required String currencySymbol,
  }) {
    final orderedLines =
        lines.where((line) => line.text.trim().isNotEmpty).toList()
          ..sort((a, b) {
            final vertical = a.top.compareTo(b.top);
            return vertical == 0 ? a.left.compareTo(b.left) : vertical;
          });
    final isSingleDetail =
        _isOrderDetail(orderedLines) ||
        _isTaobaoDetail(orderedLines) ||
        _hasSingleDetailItem(orderedLines);
    final taobaoCards = isSingleDetail
        ? <List<RecognizedOcrLine>>[]
        : _groupTaobaoOrderList(orderedLines);
    final shopeeCards = isSingleDetail || taobaoCards.isNotEmpty
        ? <List<RecognizedOcrLine>>[]
        : _groupShopeeOrderList(orderedLines);
    final groups = isSingleDetail
        ? <List<RecognizedOcrLine>>[orderedLines]
        : taobaoCards.isNotEmpty
        ? taobaoCards
        : shopeeCards.isNotEmpty
        ? shopeeCards
        : _groupLines(orderedLines);
    final allText = lines.map((line) => line.text).join(' ').toLowerCase();
    final platform = shopeeCards.isNotEmpty || allText.contains('shopee')
        ? ShoppingPlatform.shopee
        : allText.contains('lazada')
        ? ShoppingPlatform.lazada
        : allText.contains('taobao') || RegExp(r'淘宝|淘寶|天猫|天貓').hasMatch(allText)
        ? ShoppingPlatform.taobao
        : ShoppingPlatform.unknown;
    final candidates = <ShoppingOrderCandidate>[];
    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      final text = group.map((line) => line.text.trim()).join('\n');
      if (text.trim().isEmpty) continue;
      if (group.length == 1 &&
          RegExp(
            r'^(?:shopee|lazada|taobao|淘宝|my orders|orders)$',
            caseSensitive: false,
          ).hasMatch(text.trim())) {
        continue;
      }
      if (shopeeCards.isNotEmpty &&
          !group.any(
            (line) => RegExp(
              r'\btotal\s+\d+\s+items?\b|\border\s+total\b|\btotal\s+payment\b',
              caseSensitive: false,
            ).hasMatch(line.text),
          )) {
        // A screenshot may cut off at the next shop header. Without any
        // final-total line, that partial card is not an importable order.
        continue;
      }
      final isDetail =
          _isOrderDetail(group) ||
          _isTaobaoDetail(group) ||
          _hasSingleDetailItem(group);
      candidates.add(
        _candidate(
          imagePath: imagePath,
          index: index,
          lines: group,
          currencyCode: currencyCode,
          currencySymbol: currencySymbol,
          platform: platform,
          isDetail: isDetail,
        ),
      );
    }
    return candidates;
  }

  /// Deduplicates only order rows with a matching recognized order reference,
  /// or identical normalized row text from different selected screenshots.
  /// Similar merchant/amount/date values alone are not enough to discard a row.
  List<ShoppingOrderCandidate> deduplicateOverlappingScreenshots(
    Iterable<ShoppingOrderCandidate> candidates,
  ) {
    final unique = <ShoppingOrderCandidate>[];
    final seen = <String, String>{};
    for (final candidate in candidates) {
      final reference = _normalize(candidate.orderReference ?? '');
      final key = reference.isNotEmpty
          ? 'ref:$reference'
          : 'row:${_normalize(candidate.rawText)}';
      final previousImage = seen[key];
      if (previousImage == null ||
          (reference.isEmpty && previousImage == candidate.sourceImagePath)) {
        unique.add(candidate);
        seen.putIfAbsent(key, () => candidate.sourceImagePath);
      }
    }
    return unique;
  }

  ShoppingOrderCandidate _candidate({
    required String imagePath,
    required int index,
    required List<RecognizedOcrLine> lines,
    required String currencyCode,
    required String currencySymbol,
    required ShoppingPlatform platform,
    required bool isDetail,
  }) {
    final rawText = lines.map((line) => line.text.trim()).join('\n');
    final amount = _findFinalAmount(lines, currencyCode, currencySymbol);
    final date = _findOrderDate(lines);
    final orderReference = _findOrderReference(lines);
    final status = _findStatus(
      isDetail
          ? lines
                .where(
                  (line) => !RegExp(
                    r'request\s+for\s+(?:return|refund)|contact seller|help center|buy again',
                    caseSensitive: false,
                  ).hasMatch(line.text),
                )
                .map((line) => line.text)
                .join('\n')
          : rawText,
    );
    return ShoppingOrderCandidate(
      id: '$imagePath#$index',
      sourceImagePath: imagePath,
      rawText: rawText,
      status: status,
      orderReference: orderReference,
      platform: platform,
      foreignAmountReference: amount == null
          ? _foreignAmountReference(lines, currencyCode, currencySymbol)
          : null,
      merchant:
          platform == ShoppingPlatform.shopee &&
              (_isShopeeShopHeader(lines, 0) ||
                  (lines.length > 1 && _isShopeeShopHeader(lines, 1)))
          ? _findShopeeListItem(lines)
          : _isTaobaoOrderCard(lines)
          ? _findTaobaoListItem(lines)
          : _isTaobaoDetail(lines)
          ? _findTaobaoItem(lines)
          : isDetail
          ? _findDetailItem(lines)
          : _findMerchant(lines),
      amountCents: amount,
      occurredAt: date,
    );
  }

  bool _isOrderDetail(List<RecognizedOcrLine> lines) {
    final text = lines.map((line) => line.text).join('\n');
    if (RegExp(r'\border details\b', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    // OCR may misspell the title. The total plus a separate support or
    // delivery section identifies a detail page without relying on it.
    return RegExp(r'\border\s+total\b', caseSensitive: false).hasMatch(text) &&
        RegExp(
          r'support\s+center|shipping\s+information|delivery\s+information',
          caseSensitive: false,
        ).hasMatch(text);
  }

  bool _hasSingleDetailItem(List<RecognizedOcrLine> lines) {
    final totals = lines.where(
      (line) => RegExp(
        r'\border\s+total\b',
        caseSensitive: false,
      ).hasMatch(line.text),
    );
    return totals.length == 1 && _findDetailItem(lines) != null;
  }

  bool _isTaobaoDetail(List<RecognizedOcrLine> lines) {
    final text = lines.map((line) => line.text).join('\n');
    return RegExp(r'实付款|實付款').allMatches(text).length == 1 &&
        RegExp(r'付款时间|支付时间').hasMatch(text) &&
        RegExp(r'淘宝|淘寶|价格明细|價格明細').hasMatch(text);
  }

  List<List<RecognizedOcrLine>> _groupTaobaoOrderList(
    List<RecognizedOcrLine> lines,
  ) {
    final headers = <int>[];
    for (var index = 0; index < lines.length; index++) {
      if (_taobaoShopHeader.hasMatch(lines[index].text.trim())) {
        headers.add(index);
      }
    }
    if (headers.isEmpty ||
        !lines.any((line) => RegExp(r'实付款|實付款|交易成功').hasMatch(line.text))) {
      return const [];
    }
    final starts = [
      for (final headerIndex in headers)
        headerIndex > 0 &&
                (lines[headerIndex].top - lines[headerIndex - 1].top).abs() <=
                    lines[headerIndex].height &&
                RegExp(
                  r'交易成功|待付款|待发货|待收货|退款|售后',
                ).hasMatch(lines[headerIndex - 1].text)
            ? headerIndex - 1
            : headerIndex,
    ];
    // Card gutters can be much larger than text line spacing. Repeated shop
    // headers are more reliable boundaries, and also exclude navigation text.
    return [
      for (var index = 0; index < starts.length; index++)
        lines.sublist(
          starts[index],
          index + 1 < starts.length ? starts[index + 1] : lines.length,
        ),
    ];
  }

  List<List<RecognizedOcrLine>> _groupShopeeOrderList(
    List<RecognizedOcrLine> lines,
  ) {
    final allText = lines.map((line) => line.text).join('\n');
    if (!RegExp(r'\bmy purchases\b', caseSensitive: false).hasMatch(allText)) {
      return const [];
    }
    final starts = [
      for (var index = 0; index < lines.length; index++)
        if (_isShopeeShopHeader(lines, index))
          index > 0 && _isShopeeStatusBeside(lines[index - 1], lines[index])
              ? index - 1
              : index,
    ];
    if (starts.isEmpty) return const [];
    // OCR line spacing can join adjacent Shopee cards, so shop headers are
    // safer boundaries than blank-space thresholds. Ignore page navigation.
    return [
      for (var index = 0; index < starts.length; index++)
        lines.sublist(
          starts[index],
          index + 1 < starts.length ? starts[index + 1] : lines.length,
        ),
    ];
  }

  bool _isShopeeShopHeader(List<RecognizedOcrLine> lines, int index) {
    final text = lines[index].text.trim();
    if (RegExp(r'^mall\s+\S', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    if (text.length < 3 ||
        !RegExp(r'[a-zA-Z]').hasMatch(text) ||
        RegExp(
          r'my purchases|to ship|to receive|completed|return/refund|buy again|total|\bRM\s*\d',
          caseSensitive: false,
        ).hasMatch(text)) {
      return false;
    }
    return (index + 1 < lines.length &&
            _isShopeeStatusBeside(lines[index + 1], lines[index])) ||
        (index > 0 && _isShopeeStatusBeside(lines[index - 1], lines[index]));
  }

  bool _isShopeeStatusBeside(
    RecognizedOcrLine status,
    RecognizedOcrLine shop,
  ) =>
      RegExp(
        r'^completed$',
        caseSensitive: false,
      ).hasMatch(status.text.trim()) &&
      (status.top - shop.top).abs() <= shop.height * 1.5;

  String? _findShopeeListItem(List<RecognizedOcrLine> lines) {
    final shopIndex =
        lines.length > 1 &&
            RegExp(
              r'^completed$',
              caseSensitive: false,
            ).hasMatch(lines.first.text.trim())
        ? 1
        : 0;
    final shop = lines[shopIndex].text.trim().replaceFirst(
      RegExp(r'^mall\s+', caseSensitive: false),
      '',
    );
    for (final line in lines.skip(shopIndex + 1)) {
      final text = line.text.trim();
      if (RegExp(
        r'\btotal\s+\d+\s+items?\b',
        caseSensitive: false,
      ).hasMatch(text)) {
        break;
      }
      if (text.length < 7 ||
          !RegExp(r'[a-zA-Z]').hasMatch(text) ||
          RegExp(
            r'^completed$|^paid$|^x\s*\d+$|^RM\s*\d|buy again|^mall\b',
            caseSensitive: false,
          ).hasMatch(text)) {
        continue;
      }
      return text;
    }
    return shop.isEmpty ? null : shop;
  }

  static final _taobaoShopHeader = RegExp(
    r'^(?:(?:淘宝|淘寶|天猫|天貓)(?!订单|訂單)|.{2,14}(?:旗舰店|旗艦店)\s*[>›]?$)',
  );

  bool _isTaobaoOrderCard(List<RecognizedOcrLine> lines) =>
      lines.take(2).any((line) => _taobaoShopHeader.hasMatch(line.text.trim()));

  String? _findTaobaoListItem(List<RecognizedOcrLine> lines) {
    if (lines.isEmpty) return null;
    final headerIndex = lines.indexWhere(
      (line) => _taobaoShopHeader.hasMatch(line.text.trim()),
    );
    if (headerIndex < 0) return null;
    final paidIndex = lines.indexWhere(
      (line) => RegExp(r'实付款|實付款').hasMatch(line.text),
    );
    final end = paidIndex < 0 ? lines.length : paidIndex;
    final header = lines[headerIndex];
    for (var index = headerIndex + 1; index < end; index++) {
      final line = lines[index];
      // A separately recognized shop name or status can share the header row.
      if (line.top < header.top + header.height * 1.25) continue;
      final item = _taobaoItemTitle(line.text);
      if (item == null) continue;
      // OCR can truncate a promotional heading before the actual product
      // name. Prefer the last plausible line before the quantity marker.
      if (item.startsWith('【') && !item.contains('】')) {
        String? productName;
        for (
          var nextIndex = index + 1;
          nextIndex < end && nextIndex <= index + 6;
          nextIndex++
        ) {
          final nextText = lines[nextIndex].text.trim();
          if (RegExp(r'^[xX×]\s*\d+').hasMatch(nextText)) break;
          productName = _taobaoItemTitle(nextText) ?? productName;
        }
        if (productName != null) return productName;
      }
      return item;
    }
    return null;
  }

  String? _taobaoItemTitle(String raw) {
    final text = raw
        .replaceFirst(RegExp(r'\s*[¥￥]\s*\d[\d,]*(?:\.\d{1,2})?\s*$'), '')
        .trim();
    if (text.length < 5 ||
        !RegExp(r'[a-zA-Z\u3400-\u9fff]').hasMatch(text) ||
        RegExp(
          r'^(?:[¥￥]|CNY|RMB|MYR|RM)\s*\d|^x\d+$',
          caseSensitive: false,
        ).hasMatch(text) ||
        RegExp(
          r'交易成功|待付款|待发货|待收货|退款|售后|赠品|贈品|更多|申请开票|加入购物车|再买一单|价格明细|实付款|實付款|无理由退|無理由退|官方直邮',
        ).hasMatch(text)) {
      return null;
    }
    return text;
  }

  String? _findTaobaoItem(List<RecognizedOcrLine> lines) {
    final paidIndex = lines.indexWhere(
      (line) => RegExp(r'实付款|實付款').hasMatch(line.text),
    );
    if (paidIndex < 0) return null;
    var shopIndex = -1;
    for (var index = 0; index < paidIndex; index++) {
      if (RegExp(r'淘宝|淘寶').hasMatch(lines[index].text)) {
        shopIndex = index;
      }
    }
    if (shopIndex < 0) return null;
    for (var index = shopIndex + 1; index < paidIndex; index++) {
      // OCR often joins the item title and its CNY list price on one line.
      // Keep the title, but never include that price in the expense note.
      final item = _taobaoItemTitle(lines[index].text);
      if (item != null) return item;
    }
    return null;
  }

  String? _findDetailItem(List<RecognizedOcrLine> lines) {
    final totalIndex = lines.indexWhere(
      (line) => RegExp(
        r'\border\s+total\b',
        caseSensitive: false,
      ).hasMatch(line.text),
    );
    if (totalIndex < 0) return null;
    // Order-detail pages put the product below a store/Mall heading and above
    // the order total. Never infer a merchant from the delivery/address block.
    var storeIndex = -1;
    for (var index = 0; index < totalIndex; index++) {
      if (RegExp(
        r'\b(?:mall|official\s+store|store|shop)\b',
        caseSensitive: false,
      ).hasMatch(lines[index].text)) {
        storeIndex = index;
      }
    }
    if (storeIndex < 0) return null;
    for (var index = storeIndex + 1; index < totalIndex; index++) {
      final text = lines[index].text.trim();
      if (text.length < 9 || !RegExp(r'[a-zA-Z\u4e00-\u9fff]').hasMatch(text)) {
        continue;
      }
      if (RegExp(
        r'^(?:x\d+|[A-Z0-9-]{2,12})$|^(?:RM|MYR)\s*\d',
        caseSensitive: false,
      ).hasMatch(text)) {
        continue;
      }
      return text;
    }
    final store = lines[storeIndex].text.trim();
    return store.length > 4 &&
            !RegExp(r'^mall$', caseSensitive: false).hasMatch(store)
        ? store
        : null;
  }

  List<List<RecognizedOcrLine>> _groupLines(List<RecognizedOcrLine> input) {
    final lines = input.where((line) => line.text.trim().isNotEmpty).toList()
      ..sort((a, b) {
        final vertical = a.top.compareTo(b.top);
        return vertical == 0 ? a.left.compareTo(b.left) : vertical;
      });
    if (lines.isEmpty) return const [];

    final groups = <List<RecognizedOcrLine>>[];
    var current = <RecognizedOcrLine>[lines.first];
    var currentBottom = lines.first.top + lines.first.height;
    for (final line in lines.skip(1)) {
      final gap = line.top - currentBottom;
      final threshold = _lineGapThreshold(current, line);
      if (gap > threshold) {
        groups.add(current);
        current = <RecognizedOcrLine>[];
      }
      current.add(line);
      currentBottom = line.top + line.height;
    }
    groups.add(current);
    return groups;
  }

  double _lineGapThreshold(
    List<RecognizedOcrLine> group,
    RecognizedOcrLine next,
  ) {
    final heights = [...group.map((line) => line.height), next.height]..sort();
    final typicalHeight = heights[heights.length ~/ 2];
    // Order cards commonly contain closely spaced lines, then a larger blank
    // gutter. Keeping this ratio relative to text size works across densities.
    return typicalHeight * 3.5;
  }

  int? _findFinalAmount(
    List<RecognizedOcrLine> lines,
    String currencyCode,
    String currencySymbol,
  ) {
    final currency =
        '(?:${RegExp.escape(currencyCode)}|${RegExp.escape(currencySymbol)})';
    for (var index = 0; index < lines.length; index++) {
      final text = lines[index].text;
      if (!_hasFinalAmountLabel(text)) continue;
      final inline = _amounts(normalizePaidAmountOcr(text), currency);
      if (inline.isNotEmpty) return inline.last;
      if (index + 1 < lines.length) {
        final next = lines[index + 1].text.trim();
        if (_isStandaloneAmount(next, currency)) {
          return _amounts(next, currency).single;
        }
      }
    }
    return null;
  }

  String? _foreignAmountReference(
    List<RecognizedOcrLine> lines,
    String currencyCode,
    String currencySymbol,
  ) {
    for (var index = 0; index < lines.length; index++) {
      if (!_hasFinalAmountLabel(lines[index].text)) continue;
      for (final text in [
        lines[index].text,
        if (index + 1 < lines.length) lines[index + 1].text,
      ]) {
        final reference = foreignPaidAmountReference(
          text,
          currencyCode,
          currencySymbol,
        );
        if (reference != null) return reference;
      }
    }
    return null;
  }

  bool _hasFinalAmountLabel(String text) {
    final lower = text.toLowerCase();
    final excluded = RegExp(
      r'subtotal|original price|shipping|voucher|discount|cash tendered|change|balance|buy again|运费|优惠|折扣|原价|找零',
    );
    if (excluded.hasMatch(lower)) return false;
    return RegExp(
      r'grand\s*total|order\s*total|total\s*payment|amount\s*paid|paid\s*amount|amount\s*due|(?:^|\b)total(?:\b|$)|(?:^|\b)paid(?:\b|$)|实付款|實付款|实付|實付',
      caseSensitive: false,
    ).hasMatch(text);
  }

  List<int> _amounts(String text, String currency) {
    final matches = RegExp(
      '(?:$currency\\s*)?([0-9][0-9,]*(?:\\.[0-9]{1,2})?)\\s*(?:$currency)?',
      caseSensitive: false,
    ).allMatches(text);
    final amounts = <int>[];
    for (final match in matches) {
      final tokenStart = match.start;
      final tokenEnd = match.end;
      final token = text.substring(tokenStart, tokenEnd);
      if (!RegExp(currency, caseSensitive: false).hasMatch(token)) continue;
      final raw = match.group(1)!.replaceAll(',', '');
      final parts = raw.split('.');
      final whole = int.tryParse(parts.first);
      if (whole == null) continue;
      final fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
      final cents = whole * 100 + int.parse(fraction.substring(0, 2));
      if (cents > 0) amounts.add(cents);
    }
    return amounts;
  }

  bool _isStandaloneAmount(String text, String currency) =>
      RegExp(
        '^\\s*(?:$currency\\s*)?[0-9][0-9,]*(?:\\.[0-9]{1,2})?\\s*(?:$currency)?\\s*\$',
        caseSensitive: false,
      ).hasMatch(text) &&
      RegExp(currency, caseSensitive: false).hasMatch(text);

  DateTime? _findOrderDate(List<RecognizedOcrLine> lines) {
    final label = RegExp(
      r'order\s*(?:date|time)|payment\s*(?:date|time)|transaction\s*(?:date|time)|date\s*paid|ordered\s*on|下单时间|订单时间|订单日期|付款时间|支付时间|交易时间',
      caseSensitive: false,
    );
    for (var index = 0; index < lines.length; index++) {
      final text = lines[index].text;
      if (!label.hasMatch(text)) continue;
      final inline = _parseDate(text);
      if (inline != null) return inline;
      if (index + 1 < lines.length) {
        final next = lines[index + 1].text;
        if (!RegExp(
          r'ship|deliver|complete|capture|截图|送达|完成',
          caseSensitive: false,
        ).hasMatch(next)) {
          final adjacent = _parseDate(next);
          if (adjacent != null) return adjacent;
        }
      }
    }
    return null;
  }

  DateTime? _parseDate(String text) {
    final match = RegExp(
      r'(?<!\d)(20\d{2})[-/.年](\d{1,2})[-/.月](\d{1,2})(?:日)?(?:\s+(\d{1,2}):(\d{2}))?',
    ).firstMatch(text);
    if (match != null) {
      return _validDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        match.group(4),
        match.group(5),
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
    if (year < 2000 || year > 2100 || month < 1 || month > 12) return null;
    final date = DateTime(
      year,
      month,
      day,
      hour == null ? 0 : int.parse(hour),
      minute == null ? 0 : int.parse(minute),
    );
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String? _findOrderReference(List<RecognizedOcrLine> lines) {
    final labeled = RegExp(
      r'(?:order|transaction|reference)\s*(?:id|no\.?|number)\s*[:#-]?\s*([a-z0-9-]{5,})',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = labeled.firstMatch(line.text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _findMerchant(List<RecognizedOcrLine> lines) {
    final ignored = RegExp(
      r'order\s*(?:date|time|total|details)|payment|transaction|total|paid|status|completed|cancelled|canceled|refunded|refund|unpaid|shipping|delivery|delivered|buy again|subtotal|voucher|discount|订单|付款|支付|交易|实付|實付|已完成|已取消|退款|待付款|运费|优惠|折扣|原价|[0-9][0-9,]*(?:\.[0-9]+)?\s*(?:RM|MYR)?',
      caseSensitive: false,
    );
    for (final line in lines) {
      final candidate = line.text.trim();
      if (candidate.length < 2 || ignored.hasMatch(candidate)) continue;
      if (RegExp(
        r'^order\s*(?:id|no\.?|number)',
        caseSensitive: false,
      ).hasMatch(candidate)) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  ShoppingOrderStatus _findStatus(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'refunded|已退款|退款成功').hasMatch(lower)) {
      return ShoppingOrderStatus.refunded;
    }
    if (RegExp(r'refund\s*(?:pending|processing)|退款中|待退款').hasMatch(lower)) {
      return ShoppingOrderStatus.needsReview;
    }
    if (RegExp(r'cancelled|canceled|已取消').hasMatch(lower)) {
      return ShoppingOrderStatus.cancelled;
    }
    if (RegExp(r'unpaid|待付款|未付款').hasMatch(lower)) {
      return ShoppingOrderStatus.unpaid;
    }
    if (RegExp(r'paid|completed|complete|已完成|交易成功|付款成功').hasMatch(lower)) {
      return ShoppingOrderStatus.paid;
    }
    return ShoppingOrderStatus.needsReview;
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');
}
