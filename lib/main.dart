import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_settings_repository.dart';
import 'core/database/database.dart';
import 'core/database/database_key_store.dart';
import 'core/database/recovery_envelope_store.dart';
import 'core/database/recovery_bootstrap.dart';
import 'core/database/recovery_key.dart';
import 'core/utils/amount_formatter.dart';
import 'features/categories/category_providers.dart';
import 'features/categories/data/category_repository.dart';
import 'features/expenses/data/expense_repository.dart';
import 'features/expenses/expense_providers.dart';
import 'features/onboarding/presentation/recovery_passphrase_page.dart';
import 'features/payment_methods/data/payment_method_repository.dart';
import 'features/payment_methods/payment_method_providers.dart';
import 'features/settings/currency_preference.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ISpendBootstrap());
}

class _ISpendBootstrap extends StatefulWidget {
  const _ISpendBootstrap();

  @override
  State<_ISpendBootstrap> createState() => _ISpendBootstrapState();
}

class _ISpendBootstrapState extends State<_ISpendBootstrap> {
  final _keyStore = DatabaseKeyStore();
  final _envelopeStore = RecoveryEnvelopeStore();
  final _recoveryKeyService = const RecoveryKeyService();
  late final _recoveryBootstrap = RecoveryBootstrap(
    keyStore: _keyStore,
    envelopeStore: _envelopeStore,
    recoveryKeyService: _recoveryKeyService,
  );

  ISpendDatabase? _database;
  String? _databaseKey;
  RecoveryKeyEnvelope? _envelope;
  AppCurrency? _lockedCurrency;
  bool _restoring = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    try {
      final recoveryState = await _recoveryBootstrap.initialise();
      if (recoveryState.path == RecoveryBootstrapPath.restore) {
        setState(() {
          _envelope = recoveryState.envelope;
          _restoring = true;
        });
        return;
      }
      final databaseKey = recoveryState.databaseKey!;
      final database = await ISpendDatabase.open(databaseKey: databaseKey);
      final settingsRepository = SqlCipherAppSettingsRepository(
        database.database,
      );
      final lockedCurrency = await loadLockedAppCurrency(settingsRepository);
      if (!mounted) return;
      setState(() {
        _databaseKey = databaseKey;
        _database = database;
        _envelope = recoveryState.envelope;
        _lockedCurrency = lockedCurrency;
      });
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    }
  }

  Future<String?> _createEnvelope(String passphrase) async {
    try {
      final envelope = await _recoveryBootstrap.createEnvelope(
        databaseKey: _databaseKey!,
        passphrase: passphrase,
      );
      if (mounted) setState(() => _envelope = envelope);
      return null;
    } catch (_) {
      return 'The recovery passphrase could not be saved. Please try again.';
    }
  }

  Future<String?> _restore(String passphrase) async {
    try {
      final databaseKey = await _recoveryBootstrap.restore(
        _envelope!,
        passphrase,
      );
      final database = await ISpendDatabase.open(databaseKey: databaseKey);
      await _recoveryBootstrap.persistRecoveredKey(databaseKey);
      final settingsRepository = SqlCipherAppSettingsRepository(
        database.database,
      );
      final lockedCurrency = await loadLockedAppCurrency(settingsRepository);
      if (!mounted) return null;
      setState(() {
        _databaseKey = databaseKey;
        _database = database;
        _restoring = false;
        _lockedCurrency = lockedCurrency;
      });
      return null;
    } catch (_) {
      return 'That passphrase did not open this backup. Check it and try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return const ISpendApp(
        home: Scaffold(
          body: Center(child: Text('iSpend could not open its local data.')),
        ),
      );
    }
    if (_restoring) {
      return ISpendApp(
        home: RecoveryPassphrasePage(isRestore: true, onSubmit: _restore),
      );
    }
    if (_database == null) {
      return const ISpendApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (_envelope == null) {
      return ISpendApp(
        home: RecoveryPassphrasePage(
          isRestore: false,
          onSubmit: _createEnvelope,
        ),
      );
    }

    final database = _database!.database;
    return ProviderScope(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(
          SqlCipherExpenseRepository(database),
        ),
        categoryRepositoryProvider.overrideWithValue(
          SqlCipherCategoryRepository(database),
        ),
        paymentMethodRepositoryProvider.overrideWithValue(
          SqlCipherPaymentMethodRepository(database),
        ),
        appSettingsRepositoryProvider.overrideWithValue(
          SqlCipherAppSettingsRepository(database),
        ),
        startupAppCurrencyProvider.overrideWithValue(_lockedCurrency),
      ],
      child: const ISpendThemedApp(),
    );
  }
}
