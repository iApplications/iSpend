import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/app.dart';

void main() {
  testWidgets('switches between the three primary tabs', (tester) async {
    await tester.pumpWidget(const ISpendApp());

    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('No expenses yet'), findsOneWidget);

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
}
