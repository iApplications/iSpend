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

  Expense copyWith({
    int? amountCents,
    String? category,
    DateTime? occurredAt,
    String? merchantOrNote,
    String? paymentMethod,
    String? recurringRuleId,
    DateTime? recurringOccurrence,
    bool? isTaxDeductible,
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
  );
}
