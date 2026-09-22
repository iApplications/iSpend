import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../categories/presentation/category_management_page.dart';
import '../../backup/presentation/backup_restore_page.dart';
import '../../budgets/presentation/budget_limits_page.dart';
import '../../expenses/presentation/recurring_expenses_page.dart';
import '../../payment_methods/presentation/payment_method_management_page.dart';
import '../../quick_entry/presentation/quick_entry_templates_page.dart';
import '../../quick_entry/android_quick_settings_tile.dart';
import '../appearance_preference.dart';
import '../currency_preference.dart';
import '../time_format_preference.dart';
import '../../security/app_lock.dart';
import 'about_page.dart';
import 'recovery_passphrase_settings_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = ref.watch(timeFormatPreferenceProvider);
    final currency = ref.watch(appCurrencyProvider);
    final appearance = ref.watch(appearancePreferenceProvider);
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final quickLoggingWithoutUnlock = ref.watch(
      quickLoggingWithoutUnlockProvider,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        const _SettingsSectionLabel('GENERAL'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Export or restore your encrypted data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BackupRestorePage(),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_exchange_outlined),
            title: const Text('Currency'),
            subtitle: Text(
              '${currency.code} (${currency.symbol}) — locked at first launch',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Appearance'),
            subtitle: Text(appearance.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAppearancePicker(context, ref),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Time format'),
            subtitle: Text(timeFormat.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTimeFormatPicker(context, ref),
          ),
        ),
        const SizedBox(height: 16),
        const _SettingsSectionLabel('ORGANISATION'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Budget limits'),
            subtitle: const Text('Set monthly targets by category'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BudgetLimitsPage()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.repeat_outlined),
            title: const Text('Recurring expenses'),
            subtitle: const Text('Review monthly expense templates'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecurringExpensesPage(),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categories'),
            subtitle: const Text('Manage your expense categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CategoryManagementPage(),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Payment methods'),
            subtitle: const Text('Manage local payment labels'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PaymentMethodManagementPage(),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Quick Entry'),
            subtitle: const Text('Manage reusable expense templates'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const QuickEntryTemplatesPage(),
              ),
            ),
          ),
        ),
        if (Platform.isAndroid)
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Quick Settings tile'),
              subtitle: const Text('Add a fast Add Expense tile to Android'),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () => _addQuickSettingsTile(context),
            ),
          ),
        const SizedBox(height: 16),
        const _SettingsSectionLabel('PRIVACY & DATA'),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('App lock'),
            subtitle: const Text(
              'Require device authentication when opening iSpend',
            ),
            value: appLockEnabled ?? false,
            onChanged: appLockEnabled == null
                ? null
                : (enabled) => _setAppLock(context, ref, enabled),
          ),
        ),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.bolt_outlined),
            title: const Text('Allow quick logging without app unlock'),
            subtitle: const Text(
              'Widget and shortcut entry can open only the quick-entry form.',
            ),
            value: quickLoggingWithoutUnlock ?? false,
            onChanged:
                appLockEnabled != true || quickLoggingWithoutUnlock == null
                ? null
                : (enabled) => ref
                      .read(quickLoggingWithoutUnlockProvider.notifier)
                      .setEnabled(enabled),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Recovery passphrase'),
            subtitle: const Text('Change the passphrase for future backups'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecoveryPassphraseSettingsPage(),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About iSpend'),
            subtitle: const Text('Version, privacy, and provider attribution'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AboutPage())),
          ),
        ),
      ],
    );
  }

  Future<void> _setAppLock(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final authenticated = await ref
          .read(appLockAuthenticatorProvider)
          .authenticate();
      if (!authenticated) {
        if (context.mounted) {
          AppToast.showError(
            context,
            'Device authentication is unavailable or was cancelled.',
          );
        }
        return;
      }
    }
    await ref.read(appLockEnabledProvider.notifier).setEnabled(enabled);
  }

  Future<void> _addQuickSettingsTile(BuildContext context) async {
    final result = await AndroidQuickSettingsTile.requestAdd();
    if (!context.mounted) return;
    switch (result) {
      case QuickSettingsTileAddResult.added:
        AppToast.show(context, 'Quick Settings tile added');
      case QuickSettingsTileAddResult.alreadyAdded:
        AppToast.show(context, 'Quick Settings tile is already added');
      case QuickSettingsTileAddResult.notAdded:
        AppToast.show(context, 'Quick Settings tile was not added');
      case QuickSettingsTileAddResult.manualSetup:
        AppToast.show(
          context,
          'Open Android Quick Settings, then Edit tiles to add iSpend.',
        );
    }
  }

  void _showTimeFormatPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final selected = ref.watch(timeFormatPreferenceProvider);
          return SafeArea(
            child: RadioGroup<TimeFormatPreference>(
              groupValue: selected,
              onChanged: (value) async {
                if (value == null) return;
                await ref
                    .read(timeFormatPreferenceProvider.notifier)
                    .setPreference(value);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: TimeFormatPreference.values
                    .map(
                      (preference) => RadioListTile<TimeFormatPreference>(
                        title: Text(preference.label),
                        value: preference,
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAppearancePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final selected = ref.watch(appearancePreferenceProvider);
          return SafeArea(
            child: RadioGroup<AppearancePreference>(
              groupValue: selected,
              onChanged: (value) async {
                if (value == null) return;
                await ref
                    .read(appearancePreferenceProvider.notifier)
                    .setPreference(value);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: AppearancePreference.values
                    .map(
                      (preference) => RadioListTile<AppearancePreference>(
                        title: Text(preference.label),
                        value: preference,
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );
}
