import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/quick_entry/data/quick_entry_template_repository.dart';

void main() {
  test(
    'templates retain stable references, favourite state, and order',
    () async {
      final repository = InMemoryQuickEntryTemplateRepository();
      final groceries = newQuickEntryTemplate(
        name: 'Groceries',
        categoryId: 'category-food',
        paymentMethodId: 'payment-card',
        sortOrder: 1,
      );
      final parking = newQuickEntryTemplate(
        name: 'Parking',
        categoryId: 'category-transport',
        sortOrder: 0,
      );

      await repository.save(groceries);
      await repository.save(parking.copyWith(isFavorite: true));

      final favoritesFirst = await repository.getAll();
      expect(favoritesFirst.map((item) => item.name), ['Parking', 'Groceries']);
      expect(await repository.countByCategoryId('category-food'), 1);
      expect(await repository.countByPaymentMethodId('payment-card'), 1);

      await repository.reorder([groceries.id, parking.id]);
      await repository.save(parking.copyWith(isFavorite: false));
      final reordered = await repository.getAll();
      expect(reordered.map((item) => item.id), [groceries.id, parking.id]);
    },
  );
}
