class QuickEntryTemplate {
  const QuickEntryTemplate({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.sortOrder,
    required this.createdAt,
    this.paymentMethodId,
    this.merchantOrNote,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String categoryId;
  final String? paymentMethodId;
  final String? merchantOrNote;
  final int sortOrder;
  final bool isFavorite;
  final DateTime createdAt;

  QuickEntryTemplate copyWith({
    String? name,
    String? categoryId,
    String? paymentMethodId,
    String? merchantOrNote,
    int? sortOrder,
    bool? isFavorite,
  }) => QuickEntryTemplate(
    id: id,
    name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    merchantOrNote: merchantOrNote ?? this.merchantOrNote,
    sortOrder: sortOrder ?? this.sortOrder,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt,
  );
}
