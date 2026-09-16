import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/onboarding/presentation/recovery_passphrase_page.dart';

void main() {
  testWidgets('recovery passphrase setup cannot be skipped', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryPassphrasePage(
          isRestore: false,
          onSubmit: (value) async {
            submitted = value;
            return null;
          },
        ),
      ),
    );

    expect(find.text('Skip'), findsNothing);
    expect(find.textContaining('There is no reset or bypass'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Recovery passphrase'),
      'correct horse battery staple',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm recovery passphrase'),
      'different value',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('The passphrases do not match.'), findsOneWidget);
    expect(submitted, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm recovery passphrase'),
      'correct horse battery staple',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(submitted, 'correct horse battery staple');
  });

  testWidgets('restore displays a wrong-passphrase error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryPassphrasePage(
          isRestore: true,
          onSubmit: (_) async => 'That passphrase did not open this backup.',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'wrong passphrase');
    await tester.tap(find.text('Restore data'));
    await tester.pumpAndSettle();

    expect(
      find.text('That passphrase did not open this backup.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'setup requires a recovery passphrase of at least 10 characters',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryPassphrasePage(
            isRestore: false,
            onSubmit: (_) async => null,
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Recovery passphrase'),
        'short',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm recovery passphrase'),
        'short',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.textContaining('Use at least 10 characters'), findsWidgets);
    },
  );

  testWidgets('restore offers a confirmed start-fresh escape path', (
    tester,
  ) async {
    var startedFresh = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryPassphrasePage(
          isRestore: true,
          onSubmit: (_) async => 'That passphrase did not open this backup.',
          onStartFresh: () async {
            startedFresh = true;
            return null;
          },
        ),
      ),
    );

    expect(find.text('Use another backup'), findsOneWidget);
    expect(find.text('Start fresh instead'), findsOneWidget);
    await tester.tap(find.text('Start fresh instead'));
    await tester.pumpAndSettle();
    expect(find.text('Start fresh instead?'), findsOneWidget);
    expect(find.textContaining('will not be deleted'), findsOneWidget);

    await tester.tap(find.text('Start fresh'));
    await tester.pumpAndSettle();
    expect(startedFresh, isTrue);
  });
}
