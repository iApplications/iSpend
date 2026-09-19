import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/theme/app_theme.dart';
import 'features/expenses/presentation/expense_list_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/settings/appearance_preference.dart';
import 'features/security/app_lock.dart';
import 'features/summary/presentation/summary_page.dart';
import 'features/categories/category_providers.dart';
import 'features/expenses/expense_providers.dart';
import 'features/quick_entry/presentation/quick_entry_sheet.dart';
import 'features/quick_entry/quick_entry_template_providers.dart';
import 'features/payment_methods/payment_method_providers.dart';
import 'features/settings/currency_preference.dart';
import 'core/widgets/app_toast.dart';

class ISpendApp extends StatelessWidget {
  const ISpendApp({
    super.key,
    this.home = const AppShell(),
    this.themeMode = ThemeMode.system,
  });

  final Widget home;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'iSpend',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: themeMode,
    home: home,
  );
}

class ISpendThemedApp extends ConsumerWidget {
  const ISpendThemedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearancePreferenceProvider);
    return ISpendApp(
      themeMode: appearance.themeMode,
      home: const AppLockGate(child: AppShell()),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  StreamSubscription<Uri?>? _widgetClicks;

  static const _pages = <Widget>[
    ExpenseListPage(),
    SummaryPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _widgetClicks = HomeWidget.widgetClicked.listen((uri) {
      if (uri?.host == 'quick-entry') {
        _openQuickEntry(uri);
      }
    });
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (mounted && uri?.host == 'quick-entry') _openQuickEntry(uri);
    });
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    super.dispose();
  }

  Future<void> _openQuickEntry([Uri? uri]) async {
    final categories = ref.read(categoriesProvider);
    final methods = ref.read(paymentMethodsProvider);
    final templateId = uri?.queryParameters['template_id'];
    final templateName = uri?.queryParameters['template_name'];
    final templates = await ref.read(quickEntryTemplateRepositoryProvider).getAll();
    final template = templateId == null
        ? null
        : templates.where((item) => item.id == templateId).firstOrNull ??
              templates.where((item) => item.name == templateName).firstOrNull;
    final references = await ref.read(
      quickEntryTemplateReferencesProvider.future,
    );
    if (!mounted) return;
    final expense = await showQuickEntrySheet(
      context,
      categories: categories,
      paymentMethods: methods,
      history: ref.read(expensesProvider),
      currency: ref.read(appCurrencyProvider),
      template: template,
      categoryNamesById: references.categoryNamesById,
      paymentMethodNamesById: references.paymentMethodNamesById,
    );
    if (expense == null || !mounted) return;
    await ref.read(expensesProvider.notifier).add(expense);
    if (mounted) {
      AppToast.showUndo(
        context,
        message: 'Expense saved',
        onUndo: () => ref.read(expensesProvider.notifier).delete(expense.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Summary',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
