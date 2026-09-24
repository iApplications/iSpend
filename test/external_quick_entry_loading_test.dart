import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ispend/app.dart';
import 'package:ispend/features/payment_methods/data/payment_method_repository.dart';
import 'package:ispend/features/payment_methods/payment_method_providers.dart';

void main() {
  testWidgets(
    'widget Add Expense loads configured payment methods before Quick Entry',
    (tester) async {
      final methods = InMemoryPaymentMethodRepository();
      await methods.rename('Cash', 'TNG eWallet');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentMethodRepositoryProvider.overrideWithValue(methods),
          ],
          child: ISpendApp(
            home: AppShell(
              handleExternalEntries: false,
              externalQuickEntryUri: Uri.parse('ispend://quick-entry'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TNG eWallet'), findsOneWidget);
      expect(find.text('Cash'), findsNothing);
    },
  );
}
