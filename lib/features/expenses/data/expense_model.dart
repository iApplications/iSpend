class Expense {
  const Expense({
    required this.id,
    required this.amountCents,
    required this.category,
    required this.occurredAt,
    required this.createdAt,
    this.merchantOrNote,
    this.paymentMethod,
  });

  final String id;
  final int amountCents;
  final String category;
  final DateTime occurredAt;
  final DateTime createdAt;
  final String? merchantOrNote;
  final String? paymentMethod;

  Expense copyWith({
    int? amountCents,
    String? category,
    DateTime? occurredAt,
    String? merchantOrNote,
    String? paymentMethod,
  }) => Expense(
    id: id,
    amountCents: amountCents ?? this.amountCents,
    category: category ?? this.category,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt,
    merchantOrNote: merchantOrNote,
    paymentMethod: paymentMethod,
  );
}
