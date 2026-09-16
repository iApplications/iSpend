import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/payment_methods/data/payment_method_repository.dart';

void main() {
  test(
    'payment-method colour is keyed by stable ID and survives rename',
    () async {
      final repository = InMemoryPaymentMethodRepository();
      final id = (await repository.getIdsByName())['Cash']!;

      await repository.setColourKey(id, 'teal');
      await repository.rename('Cash', 'Wallet cash');

      expect((await repository.getIdsByName())['Wallet cash'], id);
      expect((await repository.getColourKeysById())[id], 'teal');

      await repository.setColourKey(id, 'default');
      expect((await repository.getColourKeysById()).containsKey(id), isFalse);
    },
  );

  test('deleting a payment method removes its saved colour', () async {
    final repository = InMemoryPaymentMethodRepository();
    final id = (await repository.getIdsByName())['Cash']!;
    await repository.setColourKey(id, 'coral');

    await repository.delete('Cash');

    expect((await repository.getColourKeysById()).containsKey(id), isFalse);
  });
}
