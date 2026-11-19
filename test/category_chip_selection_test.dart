import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/presentation/entry_choices.dart';

void main() {
  testWidgets('the selected category shows a check instead of its icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChips(
            categories: const ['Food', 'Transport', 'Shopping', 'Bills'],
            selected: 'Food',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final food = find.widgetWithText(ChoiceChip, 'Food');
    expect(tester.widget<ChoiceChip>(food).showCheckmark, isFalse);
    expect(
      find.descendant(of: food, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    // Other chips keep their own category icon and show no check.
    final transport = find.widgetWithText(ChoiceChip, 'Transport');
    expect(
      find.descendant(of: transport, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });
}
