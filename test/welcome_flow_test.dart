import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/app_settings_repository.dart';
import 'package:ispend/features/guides/presentation/welcome_flow.dart';

void main() {
  testWidgets('welcome guide walks the name page and the three tab slides', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(
            InMemoryAppSettingsRepository(),
          ),
        ],
        child: const MaterialApp(home: WelcomeFlowPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to iSpend'), findsOneWidget);
    expect(find.text('Stays on this phone'), findsOneWidget);
    expect(find.text('No account'), findsOneWidget);

    for (final title in const ['Expenses', 'Summary', 'Settings']) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
    }
    expect(find.text('Start using iSpend'), findsOneWidget);
    // The slides sketch the real screens with fixed sample shapes.
    expect(find.text('Backup & Restore'), findsOneWidget);
  });
}
