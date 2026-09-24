import '../../expenses/data/expense_model.dart';
import '../../../core/utils/amount_parser.dart';

enum QuickEntryCategorySource { explicit, history, keyword, defaultCategory }

class SmartQuickEntryResult {
  const SmartQuickEntryResult({
    required this.amountCents,
    required this.merchantOrNote,
    required this.category,
    required this.categorySource,
    this.paymentMethod,
  });

  final int? amountCents;
  final String? merchantOrNote;
  final String category;
  final QuickEntryCategorySource categorySource;
  final String? paymentMethod;
}

/// Deterministically interprets local text. All suggestions remain editable;
/// this intentionally has no network or machine-learning dependency.
class SmartQuickEntryParser {
  const SmartQuickEntryParser();

  SmartQuickEntryResult parse({
    required String input,
    required List<String> categories,
    required List<String> paymentMethods,
    required List<Expense> history,
  }) {
    final defaultCategory = categories.contains('Food')
        ? 'Food'
        : categories.first;
    var remainder = input.trim();
    int? amountCents;
    final amountMatch = RegExp(
      r'(?<![\w.])(?:rm\s*)?(\d+(?:\.\d+)?)(?![\w.])',
      caseSensitive: false,
    ).firstMatch(remainder);
    if (amountMatch != null) {
      amountCents = parseAmountToCents(amountMatch.group(1)!);
      remainder = _removeMatch(remainder, amountMatch);
    }

    final explicitCategory = _matchExplicitCategory(remainder, categories);
    if (explicitCategory != null) {
      remainder = _removePhrase(remainder, explicitCategory.matchedText);
    }
    final explicitPayment = _matchPaymentMethod(remainder, paymentMethods);
    if (explicitPayment != null) {
      remainder = _removePhrase(remainder, explicitPayment.matchedText);
    }
    final merchant = _clean(remainder);

    final historyMatch = explicitCategory == null
        ? _historyCategory(merchant, history)
        : null;
    final keywordCategory = explicitCategory == null && historyMatch == null
        ? _keywordCategory(merchant, categories)
        : null;
    final category =
        explicitCategory?.value ??
        historyMatch ??
        keywordCategory ??
        defaultCategory;
    final source = explicitCategory != null
        ? QuickEntryCategorySource.explicit
        : historyMatch != null
        ? QuickEntryCategorySource.history
        : keywordCategory != null
        ? QuickEntryCategorySource.keyword
        : QuickEntryCategorySource.defaultCategory;

    return SmartQuickEntryResult(
      amountCents: amountCents,
      merchantOrNote: merchant.isEmpty ? null : merchant,
      category: category,
      categorySource: source,
      paymentMethod:
          explicitPayment?.value ?? _historyPayment(merchant, history),
    );
  }

  _PhraseMatch? _matchExplicitCategory(String text, List<String> categories) {
    for (final category in categories) {
      if (_containsPhrase(text, category)) {
        return _PhraseMatch(category, category);
      }
    }
    return null;
  }

  String? _keywordCategory(String merchant, List<String> categories) {
    if (merchant.isEmpty) return null;
    const aliases = {
      'food': ['mee', 'nasi', 'kopi', 'coffee', 'restaurant'],
      'transport': ['petrol', 'parking', 'toll'],
      'shopping': ['uniqlo'],
    };
    for (final entry in aliases.entries) {
      final category = categories.where(
        (item) => item.toLowerCase() == entry.key,
      );
      if (category.isEmpty) continue;
      for (final alias in entry.value) {
        if (_containsPhrase(merchant, alias)) {
          return category.first;
        }
      }
    }
    return null;
  }

  _PhraseMatch? _matchPaymentMethod(String text, List<String> methods) {
    for (final method in methods) {
      if (_containsPhrase(text, method)) return _PhraseMatch(method, method);
    }
    final cash = methods.where((method) => method.toLowerCase() == 'cash');
    if (cash.isNotEmpty && _containsPhrase(text, 'cash')) {
      return _PhraseMatch(cash.first, 'cash');
    }
    final tng = methods.where(
      (method) =>
          method.toLowerCase().contains('tng') ||
          method.toLowerCase().contains('touch n go'),
    );
    if (tng.isNotEmpty && _containsPhrase(text, 'tng')) {
      return _PhraseMatch(tng.first, 'tng');
    }
    return null;
  }

  String? _historyCategory(String merchant, List<Expense> history) {
    if (merchant.isEmpty) return null;
    for (final expense in history) {
      if (_normalized(expense.merchantOrNote) == _normalized(merchant)) {
        return expense.category;
      }
    }
    return null;
  }

  String? _historyPayment(String merchant, List<Expense> history) {
    if (merchant.isEmpty) return null;
    for (final expense in history) {
      if (_normalized(expense.merchantOrNote) == _normalized(merchant) &&
          expense.paymentMethod != null) {
        return expense.paymentMethod;
      }
    }
    return null;
  }

  bool _containsPhrase(String value, String phrase) => RegExp(
    '(^|\\s)${RegExp.escape(phrase)}(?=\\s|\$)',
    caseSensitive: false,
  ).hasMatch(value);

  String _removePhrase(String value, String phrase) => value.replaceFirst(
    RegExp('(^|\\s)${RegExp.escape(phrase)}(?=\\s|\$)', caseSensitive: false),
    ' ',
  );

  String _removeMatch(String value, Match match) =>
      '${value.substring(0, match.start)} ${value.substring(match.end)}';

  String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
  String _normalized(String? value) => _clean(value ?? '').toLowerCase();
}

class _PhraseMatch {
  const _PhraseMatch(this.value, this.matchedText);
  final String value;
  final String matchedText;
}
