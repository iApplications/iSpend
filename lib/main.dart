import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_settings_repository.dart';
import 'core/database/database.dart';
import 'features/expenses/data/expense_repository.dart';
import 'features/expenses/expense_providers.dart';
import 'features/settings/time_format_preference.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final encryptedDatabase = await ISpendDatabase.open();
  runApp(
    ProviderScope(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(
          SqlCipherExpenseRepository(encryptedDatabase.database),
        ),
        appSettingsRepositoryProvider.overrideWithValue(
          SqlCipherAppSettingsRepository(encryptedDatabase.database),
        ),
      ],
      child: const ISpendApp(),
    ),
  );
}
