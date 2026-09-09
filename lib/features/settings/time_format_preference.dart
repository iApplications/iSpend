import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_settings_repository.dart';

enum TimeFormatPreference {
  device,
  twelveHour,
  twentyFourHour;

  bool resolve({required bool deviceUses24Hour}) {
    return switch (this) {
      TimeFormatPreference.device => deviceUses24Hour,
      TimeFormatPreference.twelveHour => false,
      TimeFormatPreference.twentyFourHour => true,
    };
  }

  String get label {
    return switch (this) {
      TimeFormatPreference.device => 'Follow device setting',
      TimeFormatPreference.twelveHour => '12-hour time',
      TimeFormatPreference.twentyFourHour => '24-hour time',
    };
  }
}

final timeFormatPreferenceProvider =
    NotifierProvider<TimeFormatPreferenceNotifier, TimeFormatPreference>(
      TimeFormatPreferenceNotifier.new,
    );

class TimeFormatPreferenceNotifier extends Notifier<TimeFormatPreference> {
  static const _settingKey = 'time_format_preference';

  late final AppSettingsRepository _repository;

  @override
  TimeFormatPreference build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
    Future<void>.microtask(_load);
    return TimeFormatPreference.device;
  }

  Future<void> _load() async {
    final stored = await _repository.read(_settingKey);
    state = switch (stored) {
      'twelveHour' => TimeFormatPreference.twelveHour,
      'twentyFourHour' => TimeFormatPreference.twentyFourHour,
      _ => TimeFormatPreference.device,
    };
  }

  Future<void> setPreference(TimeFormatPreference preference) async {
    state = preference;
    await _repository.write(_settingKey, preference.name);
  }
}
