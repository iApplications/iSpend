import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/app_settings_repository.dart';
import 'package:ispend/features/security/app_lock.dart';

void main() {
  test('app lock preference persists in encrypted app settings', () async {
    final settings = InMemoryAppSettingsRepository();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    await container.read(appLockEnabledProvider.notifier).setEnabled(true);

    expect(await settings.read('app_lock_enabled'), 'true');
    expect(container.read(appLockEnabledProvider), isTrue);
  });

  test(
    'quick logging bypass preference persists in encrypted app settings',
    () async {
      final settings = InMemoryAppSettingsRepository();
      final container = ProviderContainer(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
      );
      addTearDown(container.dispose);

      await container
          .read(quickLoggingWithoutUnlockProvider.notifier)
          .setEnabled(true);

      expect(await settings.read('quick_logging_without_unlock'), 'true');
      expect(container.read(quickLoggingWithoutUnlockProvider), isTrue);
    },
  );

  testWidgets('locked app only reveals content after device authentication', (
    tester,
  ) async {
    final settings = InMemoryAppSettingsRepository();
    await settings.write('app_lock_enabled', 'true');
    final authenticator = _FakeAuthenticator(false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(settings),
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('Protected expenses'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iSpend is locked'), findsOneWidget);
    expect(find.text('Protected expenses'), findsNothing);
    expect(find.text('Authentication was not completed.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    authenticator.result = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Protected expenses'), findsOneWidget);
  });

  testWidgets('defers authentication until iSpend returns from Recents', (
    tester,
  ) async {
    final settings = InMemoryAppSettingsRepository();
    await settings.write('app_lock_enabled', 'true');
    final authenticator = _FakeAuthenticator(true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(settings),
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('Protected expenses'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(authenticator.calls, 1);
    expect(find.text('Protected expenses'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    authenticator.calls = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(authenticator.calls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(authenticator.calls, 1);
    expect(find.text('Protected expenses'), findsOneWidget);
  });
}

class _FakeAuthenticator implements AppLockAuthenticator {
  _FakeAuthenticator(this.result);
  bool result;
  int calls = 0;

  @override
  Future<bool> authenticate() async {
    calls++;
    return result;
  }
}
