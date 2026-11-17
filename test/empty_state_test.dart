import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/widgets/empty_state.dart';
import 'package:ispend/features/expenses/presentation/recurring_expenses_page.dart';
import 'package:ispend/features/tags/presentation/tags_page.dart';

void main() {
  testWidgets('EmptyState shows its text and runs its action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Add your first expense',
            message: 'Type something and iSpend fills in the rest.',
            actionLabel: 'Add expense',
            onAction: () => tapped++,
            previewRows: 2,
            previewLabel: 'Your expenses will look like this',
          ),
        ),
      ),
    );
    expect(find.text('Add your first expense'), findsOneWidget);
    expect(find.text('Your expenses will look like this'), findsOneWidget);
    await tester.tap(find.text('Add expense'));
    expect(tapped, 1);
  });

  testWidgets('EmptyState omits the button when there is no action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.sell_outlined,
            title: 'Label spending your way',
            message: 'Add tags when you add an expense.',
          ),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Label spending your way'), findsOneWidget);
  });

  testWidgets('Tags and Recurring pages show an invitation when empty', (
    tester,
  ) async {
    for (final entry in {
      const TagsPage(): 'Label spending your way',
      const RecurringExpensesPage(): 'Track bills that repeat',
    }.entries) {
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: entry.key)),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }
  });
}
