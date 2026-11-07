/// The yen sign ¥ is shared by the Japanese yen and the Chinese yuan (RMB), so
/// the symbol alone cannot say which currency a receipt uses.
enum YenKind { jpy, cny, unknown }

final _yenMarker = RegExp(r'[¥￥]');
final _cnyHints = RegExp(
  r'CNY|RMB|人民币|人民幣|元|实付|實付|付款|订单|訂單|优惠|優惠|运费|運費|合计|合計|淘宝|淘寶|天猫|天貓|京东|京東|拼多多',
  caseSensitive: false,
);
// Kana only occur in Japanese text; 円 and 税込 are Japanese price words.
final _jpyHints = RegExp(r'JPY|円|税込|税抜|領収書|[぀-ヿ]', caseSensitive: false);

/// Whether [marker] is a bare yen sign (not already a currency code).
bool isYenSign(String marker) => _yenMarker.hasMatch(marker);

/// Decides what a yen sign means from the text around it. Japanese hints win
/// over Chinese ones because Japanese text also uses kanji that look Chinese.
YenKind yenKindOf(String text) {
  if (_jpyHints.hasMatch(text)) return YenKind.jpy;
  if (_cnyHints.hasMatch(text)) return YenKind.cny;
  return YenKind.unknown;
}

/// True when a bare yen sign in [context] is in the app currency [code].
/// An unclear context keeps the app's own yen currency, as before.
bool yenMatchesCurrency(String context, String code) {
  final kind = yenKindOf(context);
  return switch (code.toUpperCase()) {
    'JPY' => kind != YenKind.cny,
    'CNY' => kind != YenKind.jpy,
    _ => false,
  };
}
