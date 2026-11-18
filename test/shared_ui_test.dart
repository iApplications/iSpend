import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/theme/app_theme.dart';
import 'package:ispend/core/widgets/app_toast.dart';
import 'package:ispend/core/widgets/confirm_delete_dialog.dart';

Widget _app(Widget body, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.dark() : AppTheme.light(),
  home: Scaffold(body: body),
);

void main() {
  for (final dark in [false, true]) {
    testWidgets('delete dialog names the action and returns the choice '
        '(dark: $dark)', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showDialog<bool>(
                context: context,
                builder: (_) => const ConfirmDeleteDialog(
                  title: 'Delete expense?',
                  message: 'This expense will be permanently removed.',
                ),
              ),
              child: const Text('open'),
            ),
          ),
          dark: dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete expense?'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  }

  testWidgets('delete dialog Cancel returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<bool>(
              context: context,
              builder: (_) => const ConfirmDeleteDialog(title: 'Delete?'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('toasts keep their words and an Undo action', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => AppToast.showError(context, 'Could not save'),
                child: const Text('err'),
              ),
              TextButton(
                onPressed: () => AppToast.showUndo(
                  context,
                  message: 'Expense deleted',
                  onUndo: () {},
                ),
                child: const Text('undo'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('err'));
    await tester.pump();
    expect(find.text('Could not save'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('undo'));
    await tester.pump();
    expect(find.text('Expense deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
