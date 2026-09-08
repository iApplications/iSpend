import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  TimeFormatPreference build() => TimeFormatPreference.device;

  void setPreference(TimeFormatPreference preference) {
    state = preference;
  }
}
