import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../backup/presentation/backup_restore_page.dart';
import '../../budgets/budget_providers.dart';
import '../../budgets/presentation/budget_limits_page.dart';
import '../../categories/category_providers.dart';
import '../../categories/presentation/category_management_page.dart';
import '../../exchange_rates/exchange_rate_providers.dart';
import '../../exchange_rates/presentation/exchange_rates_page.dart';
import '../../guides/guide_providers.dart';
import '../../guides/presentation/help_guide_page.dart';
import '../../guides/presentation/personalization_page.dart';
import '../../expenses/presentation/recurring_expenses_page.dart';
import '../../export/presentation/export_data_page.dart';
import '../../expenses/expense_providers.dart';
import '../../payment_methods/payment_method_providers.dart';
import '../../payment_methods/presentation/payment_method_management_page.dart';
import '../../quick_entry/android_quick_settings_tile.dart';
import '../../quick_entry/presentation/quick_entry_templates_page.dart';
import '../../quick_entry/quick_entry_template_providers.dart';
import '../../security/app_lock.dart';
import '../../tags/data/tag_rules.dart';
import '../../tags/presentation/tags_page.dart';
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
    final imageBytes = ref.watch(imageStorageBytesProvider);
    final name = ref.watch(displayNameProvider);
    final categoryCount = ref.watch(categoriesProvider).length;
    final paymentCount = ref.watch(paymentMethodsProvider).length;
    final tagCount = tagUsage(ref.watch(expensesProvider)).length;
    final budgetCount = ref.watch(budgetLimitsProvider).length;
    final activeRecurring = ref
        .watch(recurringExpensesProvider)
        .maybeWhen(
          data: (items) => items.where((item) => item.isActive).length,
          orElse: () => null,
        );
    final ratesOn = ref.watch(
      exchangeRatesProvider.select((state) => state.suggestionsEnabled),
    );
    final templateCount = ref.watch(quickEntryTemplatesProvider).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        _ProfileCard(
          name: name,
          currencyLabel: '${currency.code} (${currency.symbol}), locked',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PersonalizationPage(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'LOOK AND FEEL',
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Appearance'),
              trailing: _ValueChevron(appearance.label),
              onTap: () => _showAppearancePicker(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Time format'),
              trailing: _ValueChevron(timeFormat.label),
              onTap: () => _showTimeFormatPicker(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'ORGANISE',
          children: [
            _navigationTile(
              context,
              icon: Icons.category_outlined,
              title: 'Categories',
              value: '$categoryCount',
              page: const CategoryManagementPage(),
            ),
            _navigationTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payment methods',
              value: '$paymentCount',
              page: const PaymentMethodManagementPage(),
            ),
            _navigationTile(
              context,
              icon: Icons.sell_outlined,
              title: 'Tags',
              value: '$tagCount',
              page: const TagsPage(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'MONEY',
          children: [
            _navigationTile(
              context,
              icon: Icons.savings_outlined,
              title: 'Budget limits',
              value: budgetCount == 0 ? 'None' : '$budgetCount set',
              page: const BudgetLimitsPage(),
            ),
            _navigationTile(
              context,
              icon: Icons.repeat_outlined,
              title: 'Recurring expenses',
              value: activeRecurring == null
                  ? ''
                  : activeRecurring == 0
                  ? 'None'
                  : '$activeRecurring active',
              page: const RecurringExpensesPage(),
            ),
            _navigationTile(
              context,
              icon: Icons.currency_exchange,
              title: 'Exchange rates',
              value: ratesOn ? 'On' : 'Off',
              page: const ExchangeRatesPage(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'FAST ENTRY',
          children: [
            _navigationTile(
              context,
              icon: Icons.bolt_outlined,
              title: 'Quick Entry',
              value: templateCount == 1
                  ? '1 template'
                  : '$templateCount templates',
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
          label: 'SECURITY',
          children: [
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
              subtitle: Text(
                appLockEnabled == true
                    ? 'Widget and shortcut entry can open only the quick-entry form.'
                    : 'Turn on App lock first.',
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
          label: 'YOUR DATA',
          children: [
            _navigationTile(
              context,
              icon: Icons.backup_outlined,
              title: 'Backup & Restore',
              subtitle: 'Export or restore your encrypted data',
              page: const BackupRestorePage(),
            ),
            _navigationTile(
              context,
              icon: Icons.table_chart_outlined,
              title: 'Export data',
              subtitle: 'Save expenses or tax-deductible items as CSV',
              page: const ExportDataPage(),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Saved image storage'),
              subtitle: Text(
                imageBytes.when(
                  data: (bytes) =>
                      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB of 100 MB used',
                  error: (_, _) => 'Unavailable',
                  loading: () => 'Checking storage…',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingsGroup(
          label: 'HELP',
          children: [
            _navigationTile(
              context,
              icon: Icons.help_outline,
              title: 'Help & Guide',
              subtitle: 'Tips for each feature, and reset tutorials',
              page: const HelpGuidePage(),
            ),
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
    required Widget page,
    String? subtitle,
    String? value,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: value == null
        ? const Icon(Icons.chevron_right)
        : _ValueChevron(value),
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

/// The name from Personalization with the locked currency under it. Opens
/// Personalization. Without a name it invites the user to add one.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.currencyLabel,
    required this.onTap,
  });

  final String? name;
  final String currencyLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: name == null
              ? const Icon(Icons.person_outline)
              : Text(name!.characters.first.toUpperCase()),
        ),
        title: Text(name ?? 'Add your name'),
        subtitle: Text('Currency $currencyLabel'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// A short current value shown before the chevron, so a row says what it is
/// set to without opening it.
class _ValueChevron extends StatelessWidget {
  const _ValueChevron(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (value.isNotEmpty)
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      const Icon(Icons.chevron_right),
    ],
  );
}
