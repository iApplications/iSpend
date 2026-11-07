/// One transaction read from a statement, before the user reviews it.
class StatementRow {
  const StatementRow({
    required this.line,
    required this.description,
    required this.date,
    required this.amountCents,
    required this.reason,
    required this.selected,
    this.hasTime = false,
  });

  final int line;
  final String description;
  final DateTime? date;
  final int? amountCents;
  final String? reason;

  /// Whether [date] carries a time read from the statement. Otherwise the
  /// time is a placeholder (noon).
  final bool hasTime;
  final bool selected;
}
