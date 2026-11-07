class Expense {
  const Expense({
    required this.id,
    required this.amountCents,
    required this.category,
    required this.occurredAt,
    required this.createdAt,
    this.merchantOrNote,
    this.paymentMethod,
    this.recurringRuleId,
    this.recurringOccurrence,
    this.isTaxDeductible = false,
    this.tags = const [],
    this.originalAmountCents,
    this.originalCurrency,
    this.exchangeRate,
  });

  final String id;
  final int amountCents;
  final String category;
  final DateTime occurredAt;
  final DateTime createdAt;
  final String? merchantOrNote;
  final String? paymentMethod;
  final String? recurringRuleId;
  final DateTime? recurringOccurrence;
  final bool isTaxDeductible;

  /// Freeform labels the user added, in addition to the category.
  final List<String> tags;

  /// For an expense paid in another currency: the amount and currency on the
  /// receipt, and the rate the user confirmed (app-currency units per one
  /// original unit). [amountCents] is always in the app currency, converted
  /// once when the expense was entered, so totals never shift with rates.
  final int? originalAmountCents;
  final String? originalCurrency;
  final double? exchangeRate;

  bool get isForeign => originalCurrency != null && originalAmountCents != null;

  Expense copyWith({
    int? amountCents,
    String? category,
    DateTime? occurredAt,
    String? merchantOrNote,
    String? paymentMethod,
    String? recurringRuleId,
    DateTime? recurringOccurrence,
    bool? isTaxDeductible,
    List<String>? tags,
    int? originalAmountCents,
    String? originalCurrency,
    double? exchangeRate,
  }) => Expense(
    id: id,
    amountCents: amountCents ?? this.amountCents,
    category: category ?? this.category,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt,
    merchantOrNote: merchantOrNote ?? this.merchantOrNote,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    recurringRuleId: recurringRuleId ?? this.recurringRuleId,
    recurringOccurrence: recurringOccurrence ?? this.recurringOccurrence,
    isTaxDeductible: isTaxDeductible ?? this.isTaxDeductible,
    tags: tags ?? this.tags,
    originalAmountCents: originalAmountCents ?? this.originalAmountCents,
    originalCurrency: originalCurrency ?? this.originalCurrency,
    exchangeRate: exchangeRate ?? this.exchangeRate,
  );
}
