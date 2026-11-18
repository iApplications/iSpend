import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/widgets/review_row_card.dart';

Widget _host({required bool ready, required bool expanded}) => MaterialApp(
  home: Scaffold(
    body: ReviewRowCard(
      title: 'Village Grocer',
      subtitle: 'Row 3',
      amount: 'RM 23.50',
      selected: true,
      onSelectedChanged: (_) {},
      ready: ready,
      initiallyExpanded: expanded,
      summary: const ['Food', 'Maybank'],
      fields: const [
        TextField(decoration: InputDecoration(labelText: 'Amount')),
      ],
    ),
  ),
);

void main() {
  testWidgets('a ready row is collapsed until Edit details is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ready: true, expanded: false));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Food · Maybank'), findsOneWidget);
    expect(find.text('Amount'), findsNothing);

    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(find.text('Amount'), findsOneWidget);
  });

  testWidgets('a row needing review says so in words and starts expanded', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ready: false, expanded: true));
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
  });
}
