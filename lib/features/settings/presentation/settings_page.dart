import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/presentation/category_management_page.dart';
import '../../payment_methods/presentation/payment_method_management_page.dart';
import '../appearance_preference.dart';
import '../currency_preference.dart';
import '../time_format_preference.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = ref.watch(timeFormatPreferenceProvider);
    final currency = ref.watch(appCurrencyProvider);
    final appearance = ref.watch(appearancePreferenceProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        const _SettingsSectionLabel('GENERAL'),
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
      ],
    );
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
