import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_settings_repository.dart';
import '../../core/utils/amount_formatter.dart';

final appCurrencyProvider = NotifierProvider<AppCurrencyNotifier, AppCurrency>(
  AppCurrencyNotifier.new,
);

/// Supplied during app startup so a previously locked currency is available
/// before the first main-app frame is painted.
final startupAppCurrencyProvider = Provider<AppCurrency?>((_) => null);

Future<AppCurrency> loadLockedAppCurrency(
  AppSettingsRepository repository, {
  Locale? deviceLocale,
}) async {
  final storedCode = await repository.read(AppCurrencyNotifier.settingKey);
  if (storedCode != null) return AppCurrency.fromCode(storedCode);

  final detected = AppCurrency.fromLocale(
    deviceLocale ?? PlatformDispatcher.instance.locale,
  );
  await repository.write(AppCurrencyNotifier.settingKey, detected.code);
  return detected;
}

class AppCurrencyNotifier extends Notifier<AppCurrency> {
  static const settingKey = 'locked_currency_code';
  late final AppSettingsRepository _repository;

  @override
  AppCurrency build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
    final startupCurrency = ref.watch(startupAppCurrencyProvider);
    if (startupCurrency != null) return startupCurrency;
    final detected = AppCurrency.fromLocale(PlatformDispatcher.instance.locale);
    Future<void>.microtask(() async {
      state = await loadLockedAppCurrency(_repository);
    });
    return detected;
  }
}
