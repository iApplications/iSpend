import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ispend/app.dart';

void main() {
  testWidgets('switches between the three primary tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.textContaining('('), findsOneWidget);

    await tester.tap(find.text('Summary').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Your spending summary will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Payment methods'), findsOneWidget);
  });

  testWidgets('saves a rounded expense with Food selected by default', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ISpendApp()));

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amountField')), '9.999');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.textContaining('10.00'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });
}
