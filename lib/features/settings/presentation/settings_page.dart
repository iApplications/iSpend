import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../backup/presentation/backup_restore_page.dart';
import '../../budgets/presentation/budget_limits_page.dart';
import '../../categories/presentation/category_management_page.dart';
import '../../expenses/presentation/recurring_expenses_page.dart';
import '../../payment_methods/presentation/payment_method_management_page.dart';
import '../../quick_entry/android_quick_settings_tile.dart';
import '../../quick_entry/presentation/quick_entry_templates_page.dart';
import '../../security/app_lock.dart';
import '../appearance_preference.dart';
import '../currency_preference.dart';
import '../time_format_preference.dart';
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
        _SettingsGroup(
          label: 'GENERAL',
          children: [
            ListTile(
              leading: const Icon(Icons.currency_exchange_outlined),
              title: const Text('Currency'),
              subtitle: Text(
                '${currency.code} (${currency.symbol}) — locked at first launch',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Appearance'),
              subtitle: Text(appearance.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAppearancePicker(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Time format'),
              subtitle: Text(timeFormat.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTimeFormatPicker(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'SPENDING SETUP',
          children: [
            _navigationTile(
              context,
              icon: Icons.category_outlined,
              title: 'Categories',
              subtitle: 'Manage your expense categories',
              page: const CategoryManagementPage(),
            ),
            _navigationTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payment methods',
              subtitle: 'Manage local payment labels',
              page: const PaymentMethodManagementPage(),
            ),
            _navigationTile(
              context,
              icon: Icons.savings_outlined,
              title: 'Budget limits',
              subtitle: 'Set monthly targets by category',
              page: const BudgetLimitsPage(),
            ),
            _navigationTile(
              context,
              icon: Icons.repeat_outlined,
              title: 'Recurring expenses',
              subtitle: 'Review monthly expense templates',
              page: const RecurringExpensesPage(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'QUICK ACCESS',
          children: [
            _navigationTile(
              context,
              icon: Icons.bolt_outlined,
              title: 'Quick Entry',
              subtitle: 'Manage reusable expense templates',
              page: const QuickEntryTemplatesPage(),
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Quick Settings tile'),
                subtitle: const Text('Add a fast Add Expense tile to Android'),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => _addQuickSettingsTile(context),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'PRIVACY & DATA',
          children: [
            _navigationTile(
              context,
              icon: Icons.backup_outlined,
              title: 'Backup & Restore',
              subtitle: 'Export or restore your encrypted data',
              page: const BackupRestorePage(),
            ),
            SwitchListTile(
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
            SwitchListTile(
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
            _navigationTile(
              context,
              icon: Icons.key_outlined,
              title: 'Recovery passphrase',
              subtitle: 'Change the passphrase for future backups',
              page: const RecoveryPassphraseSettingsPage(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'ABOUT',
          children: [
            _navigationTile(
              context,
              icon: Icons.info_outline,
              title: 'About iSpend',
              subtitle: 'Version, privacy, and provider attribution',
              page: const AboutPage(),
            ),
          ],
        ),
      ],
    );
  }

  ListTile _navigationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page)),
  );

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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SettingsSectionLabel(label),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1)
                const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          ],
        ),
      ),
    ],
  );
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
