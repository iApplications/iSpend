import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_settings_repository.dart';
import '../../core/utils/amount_formatter.dart';

final appCurrencyProvider = NotifierProvider<AppCurrencyNotifier, AppCurrency>(
  AppCurrencyNotifier.new,
);

class AppCurrencyNotifier extends Notifier<AppCurrency> {
  static const _settingKey = 'locked_currency_code';
  late final AppSettingsRepository _repository;

  @override
  AppCurrency build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
    final detected = AppCurrency.fromLocale(PlatformDispatcher.instance.locale);
    Future<void>.microtask(() async {
      final storedCode = await _repository.read(_settingKey);
      if (storedCode == null) {
        await _repository.write(_settingKey, detected.code);
      } else {
        state = AppCurrency.fromCode(storedCode);
      }
    });
    return detected;
  }
}
