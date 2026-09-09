import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/app_settings_repository.dart';
import 'package:ispend/features/settings/appearance_preference.dart';

void main() {
  test('appearance preference is persisted and restored', () async {
    final repository = InMemoryAppSettingsRepository();
    final firstContainer = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(firstContainer.dispose);

    await firstContainer
        .read(appearancePreferenceProvider.notifier)
        .setPreference(AppearancePreference.dark);
    expect(await repository.read('appearance_preference'), 'dark');

    final restoredContainer = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(restoredContainer.dispose);
    restoredContainer.read(appearancePreferenceProvider);
    await Future<void>.delayed(Duration.zero);

    expect(
      restoredContainer.read(appearancePreferenceProvider),
      AppearancePreference.dark,
    );
  });
}
