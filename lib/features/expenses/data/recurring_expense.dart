import 'expense_model.dart';

class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.amountCents,
    required this.category,
    required this.nextOccurrence,
    required this.createdAt,
    this.merchantOrNote,
    this.paymentMethod,
    this.isActive = true,
  });

  final String id;
  final int amountCents;
  final String category;
  final String? merchantOrNote;
  final String? paymentMethod;
  final DateTime nextOccurrence;
  final DateTime createdAt;
  final bool isActive;

  Expense draftExpense() => Expense(
    id: id,
    amountCents: amountCents,
    category: category,
    merchantOrNote: merchantOrNote,
    paymentMethod: paymentMethod,
    occurredAt: nextOccurrence,
    createdAt: createdAt,
    recurringRuleId: id,
    recurringOccurrence: nextOccurrence,
  );

  RecurringExpense copyWith({
    int? amountCents,
    String? category,
    String? merchantOrNote,
    String? paymentMethod,
    DateTime? nextOccurrence,
    bool? isActive,
  }) => RecurringExpense(
    id: id,
    amountCents: amountCents ?? this.amountCents,
    category: category ?? this.category,
    merchantOrNote: merchantOrNote ?? this.merchantOrNote,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    nextOccurrence: nextOccurrence ?? this.nextOccurrence,
    createdAt: createdAt,
    isActive: isActive ?? this.isActive,
  );
}
