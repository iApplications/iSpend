import '../../expenses/data/expense_model.dart';

const maxTagLength = 24;
const maxTagsPerExpense = 8;

/// Cleans one tag the way the user would expect: no leading `#`, single
/// spaces, and a length that fits on a chip. Returns null for an empty tag.
String? normalizeTag(String raw) {
  var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceFirst(RegExp(r'^#+\s*'), '').trim();
  if (text.isEmpty) return null;
  if (text.length > maxTagLength) {
    text = text.substring(0, maxTagLength).trim();
  }
  return text;
}

/// Normalizes [raw] tags, drops repeats that differ only by case, and keeps
/// the first [maxTagsPerExpense]. When [known] holds a tag with the same
/// letters in another case, that spelling wins so "trip" and "Trip" stay one tag.
List<String> normalizeTags(
  Iterable<String> raw, {
  Iterable<String> known = const [],
}) {
  final spelling = <String, String>{};
  for (final tag in known) {
    spelling.putIfAbsent(tag.toLowerCase(), () => tag);
  }
  final seen = <String>{};
  final result = <String>[];
  for (final item in raw) {
    final tag = normalizeTag(item);
    if (tag == null) continue;
    final key = tag.toLowerCase();
    if (!seen.add(key)) continue;
    result.add(spelling[key] ?? tag);
    if (result.length == maxTagsPerExpense) break;
  }
  return result;
}

/// How often each tag is used, most used first, ties broken alphabetically.
List<MapEntry<String, int>> tagUsage(Iterable<Expense> expenses) {
  final counts = <String, int>{};
  final spelling = <String, String>{};
  for (final expense in expenses) {
    for (final tag in expense.tags) {
      final key = tag.toLowerCase();
      spelling.putIfAbsent(key, () => tag);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  return [
    for (final entry in counts.entries)
      MapEntry(spelling[entry.key]!, entry.value),
  ]..sort((a, b) {
    final byCount = b.value.compareTo(a.value);
    return byCount != 0
        ? byCount
        : a.key.toLowerCase().compareTo(b.key.toLowerCase());
  });
}

/// Suggests tags from the user's own history, entirely on-device: tags used
/// before with the same merchant first, then the most used tags overall.
List<String> suggestTags({
  required Iterable<Expense> history,
  required String merchant,
  Iterable<String> selected = const [],
  int limit = 6,
}) {
  final taken = {for (final tag in selected) tag.toLowerCase()};
  final merchantKey = merchant.trim().toLowerCase();
  final suggestions = <String>[];

  void add(String tag) {
    if (suggestions.length < limit && taken.add(tag.toLowerCase())) {
      suggestions.add(tag);
    }
  }

  if (merchantKey.isNotEmpty) {
    final sameMerchant = history.where(
      (expense) =>
          (expense.merchantOrNote ?? '').trim().toLowerCase() == merchantKey,
    );
    for (final entry in tagUsage(sameMerchant)) {
      add(entry.key);
    }
  }
  for (final entry in tagUsage(history)) {
    add(entry.key);
  }
  return suggestions;
}
