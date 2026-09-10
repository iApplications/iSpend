import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_settings_repository.dart';

enum AppearancePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
    AppearancePreference.system => ThemeMode.system,
    AppearancePreference.light => ThemeMode.light,
    AppearancePreference.dark => ThemeMode.dark,
  };

  String get label => switch (this) {
    AppearancePreference.system => 'Follow system setting',
    AppearancePreference.light => 'Light mode',
    AppearancePreference.dark => 'Dark mode',
  };
}

final appearancePreferenceProvider =
    NotifierProvider<AppearancePreferenceNotifier, AppearancePreference>(
      AppearancePreferenceNotifier.new,
    );

class AppearancePreferenceNotifier extends Notifier<AppearancePreference> {
  static const _settingKey = 'appearance_preference';
  late final AppSettingsRepository _repository;

  @override
  AppearancePreference build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
    Future<void>.microtask(_load);
    return AppearancePreference.system;
  }

  Future<void> _load() async {
    final stored = await _repository.read(_settingKey);
    state = switch (stored) {
      'light' => AppearancePreference.light,
      'dark' => AppearancePreference.dark,
      _ => AppearancePreference.system,
    };
  }

  /// Reloads the saved preference after a backup restore.
  Future<void> refresh() => _load();

  Future<void> setPreference(AppearancePreference preference) async {
    state = preference;
    await _repository.write(_settingKey, preference.name);
  }
}
