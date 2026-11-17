import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/app_settings_repository.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/expenses/expense_providers.dart';
import 'package:ispend/features/guides/data/guide_catalog.dart';
import 'package:ispend/features/guides/guide_providers.dart';
import 'package:ispend/features/guides/presentation/contextual_guide.dart';
import 'package:ispend/features/guides/presentation/help_guide_page.dart';
import 'package:ispend/features/guides/presentation/welcome_flow.dart';

ProviderContainer _container(InMemoryAppSettingsRepository settings) {
  final container = ProviderContainer(
    overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('display name', () {
    test('normalizes and clears', () {
      expect(normalizeDisplayName('   '), isNull);
      expect(normalizeDisplayName('  Sam   Lee \n'), 'Sam Lee');
      expect(normalizeDisplayName('x' * 80)!.length, maxDisplayNameLength);
      expect(greetingFor(null, now: DateTime(2026, 9, 10, 8)), 'Good morning');
      expect(
        greetingFor('Sam', now: DateTime(2026, 9, 10, 13)),
        'Good afternoon, Sam',
      );
      expect(greetingFor(null, now: DateTime(2026, 9, 10, 19)), 'Good evening');
      expect(greetingFor(null, now: DateTime(2026, 9, 10, 2)), 'Good evening');
      expect(greetingFor(null, now: DateTime(2026, 9, 10, 5)), 'Good morning');
      expect(
        greetingFor(null, now: DateTime(2026, 9, 10, 12)),
        'Good afternoon',
      );
      expect(greetingFor(null, now: DateTime(2026, 9, 10, 18)), 'Good evening');
    });

    test('saves, clears and reloads from settings', () async {
      final settings = InMemoryAppSettingsRepository();
      final container = _container(settings);
      final notifier = container.read(displayNameProvider.notifier);

      expect(await notifier.set(' Sam '), 'Sam');
      expect(await settings.read(DisplayNameNotifier.settingKey), 'Sam');

      await notifier.set('');
      expect(container.read(displayNameProvider), isNull);

      await settings.write(DisplayNameNotifier.settingKey, 'Alex');
      await notifier.refresh();
      expect(container.read(displayNameProvider), 'Alex');
    });
  });

  group('tutorial state', () {
    final topic = guideTopicFor(GuideIds.budgets)!;

    test('remembers a dismissed guide and survives a reload', () async {
      final settings = InMemoryAppSettingsRepository();
      final container = _container(settings);
      container.read(tutorialProvider);
      await _settle();
      expect(container.read(tutorialProvider).loaded, isTrue);
      expect(container.read(tutorialProvider).hasSeen(topic), isFalse);

      await container.read(tutorialProvider.notifier).markSeen(topic);

      final reloaded = _container(settings);
      reloaded.read(tutorialProvider);
      await _settle();
      expect(reloaded.read(tutorialProvider).hasSeen(topic), isTrue);
    });

    test('a newer guide version shows again', () {
      final state = TutorialState(loaded: true, seen: {topic.id: 0});
      expect(state.hasSeen(topic), isFalse);
      final current = TutorialState(
        loaded: true,
        seen: {topic.id: topic.version},
      );
      expect(current.hasSeen(topic), isTrue);
    });

    test('corrupt saved state falls back to unseen', () async {
      final settings = InMemoryAppSettingsRepository();
      await settings.write(TutorialNotifier.settingKey, '{not json');
      final container = _container(settings);
      container.read(tutorialProvider);
      await _settle();
      final state = container.read(tutorialProvider);
      expect(state.loaded, isTrue);
      expect(state.welcomeDone, isFalse);
      expect(state.seen, isEmpty);
    });

    test('reset clears tips but keeps the name and welcome', () async {
      final settings = InMemoryAppSettingsRepository();
      final container = _container(settings);
      await container.read(displayNameProvider.notifier).set('Sam');
      await container.read(tutorialProvider.notifier).completeWelcome();
      await container.read(tutorialProvider.notifier).markSeen(topic);

      await container.read(tutorialProvider.notifier).reset();

      final state = container.read(tutorialProvider);
      expect(state.seen, isEmpty);
      expect(state.welcomeDone, isTrue);
      expect(container.read(displayNameProvider), 'Sam');
    });
  });

  group('widgets', () {
    testWidgets('contextual guide dismisses with Got it', (tester) async {
      final settings = InMemoryAppSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsRepositoryProvider.overrideWithValue(settings),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GuidedBody(
                guideId: GuideIds.budgets,
                child: Text('page content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('page content'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Got it'), findsNothing);
      expect(find.text('page content'), findsOneWidget);
      expect(await settings.read(TutorialNotifier.settingKey), isNotNull);
    });

    testWidgets('help page resets tutorials but not the name', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 3000);
      addTearDown(tester.view.reset);
      final settings = InMemoryAppSettingsRepository();
      final topic = guideTopicFor(GuideIds.budgets)!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsRepositoryProvider.overrideWithValue(settings),
          ],
          child: const MaterialApp(home: HelpGuidePage()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HelpGuidePage)),
      );
      await container.read(displayNameProvider.notifier).set('Sam');
      await container.read(tutorialProvider.notifier).markSeen(topic);

      await tester.ensureVisible(find.text('Reset tutorials'));
      await tester.tap(find.text('Reset tutorials'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(container.read(tutorialProvider).hasSeen(topic), isFalse);
      expect(container.read(displayNameProvider), 'Sam');
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('welcome is skipped silently when expenses exist', (
      tester,
    ) async {
      final settings = InMemoryAppSettingsRepository();
      final expenses = InMemoryExpenseRepository();
      await expenses.save(
        Expense(
          id: 'e1',
          amountCents: 500,
          category: 'Food',
          occurredAt: DateTime(2026, 9, 10),
          createdAt: DateTime(2026, 9, 10),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsRepositoryProvider.overrideWithValue(settings),
            expenseRepositoryProvider.overrideWithValue(expenses),
          ],
          child: const MaterialApp(home: WelcomeGate(child: Text('home'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome to iSpend'), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(await settings.read(TutorialNotifier.settingKey), isNotNull);
    });

    testWidgets('welcome shows on a fresh install, saves the name, once', (
      tester,
    ) async {
      final settings = InMemoryAppSettingsRepository();
      Widget app() => ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(settings),
          expenseRepositoryProvider.overrideWithValue(
            InMemoryExpenseRepository(),
          ),
        ],
        child: const MaterialApp(home: WelcomeGate(child: Text('home'))),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Welcome to iSpend'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Sam');
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to iSpend'), findsNothing);
      expect(await settings.read(DisplayNameNotifier.settingKey), 'Sam');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Welcome to iSpend'), findsNothing);
    });
  });
}
