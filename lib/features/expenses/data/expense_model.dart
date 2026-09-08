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
}
