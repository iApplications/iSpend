import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/widgets/grouped_list_card.dart';

void main() {
  test('usageLabel words the count', () {
    expect(usageLabel(0), 'Not used yet');
    expect(usageLabel(1), '1 expense');
    expect(usageLabel(12), '12 expenses');
  });

  testWidgets('GroupedListCard puts dividers between rows only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GroupedListCard(children: [Text('a'), Text('b'), Text('c')]),
        ),
      ),
    );
    expect(find.byType(Divider), findsNWidgets(2));
  });
}
