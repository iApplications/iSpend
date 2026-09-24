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
import 'features/expenses/data/expense_model.dart';
import 'features/quick_entry/presentation/quick_entry_sheet.dart';
import 'features/quick_entry/android_app_shortcuts.dart';
import 'features/quick_entry/android_home_widget.dart';
import 'features/quick_entry/quick_entry_interaction_guard.dart';
import 'features/quick_entry/presentation/quick_entry_templates_page.dart';
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
    final quickLoggingWithoutUnlock = ref.watch(
      quickLoggingWithoutUnlockProvider,
    );
    return ISpendApp(
      themeMode: appearance.themeMode,
      home: AppLockGate(
        child: const AppShell(handleExternalEntries: false),
        externalChildBuilder: (uri, onComplete, requestId) => AppShell(
          handleExternalEntries: false,
          externalOnly: quickLoggingWithoutUnlock == true,
          externalQuickEntryUri: uri,
          onExternalEntryComplete: onComplete,
          externalRequestId: requestId,
        ),
      ),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    this.externalQuickEntryUri,
    this.externalOnly = false,
    this.handleExternalEntries = true,
    this.onExternalEntryComplete,
    this.externalRequestId,
  });

  final Uri? externalQuickEntryUri;
  final bool externalOnly;
  final bool handleExternalEntries;
  final VoidCallback? onExternalEntryComplete;
  final int? externalRequestId;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  StreamSubscription<Uri?>? _widgetClicks;
  ProviderSubscription<List<Expense>>? _expenseWidgetRefresh;
  String? _externalEntryStatus;
  final _quickEntryInteraction = QuickEntryInteractionGuard();

  static const _pages = <Widget>[
    ExpenseListPage(),
    SummaryPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.externalQuickEntryUri != null) {
      _launchExternalEntry(widget.externalQuickEntryUri!);
    } else if (widget.handleExternalEntries) {
      _widgetClicks = HomeWidget.widgetClicked.listen((uri) {
        if (uri?.host == 'quick-entry') {
          uri?.queryParameters['more'] == 'true'
              ? _openQuickEntryTemplates()
              : _openQuickEntry(uri);
        }
      });
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (mounted && uri?.host == 'quick-entry') {
          uri?.queryParameters['more'] == 'true'
              ? _openQuickEntryTemplates()
              : _openQuickEntry(uri);
        }
      });
    }
    unawaited(_refreshAppShortcuts());
    _expenseWidgetRefresh = ref.listenManual(expensesProvider, (_, expenses) {
      unawaited(_refreshHomeWidget(expenses));
    }, fireImmediately: true);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final uri = widget.externalQuickEntryUri;
    if (uri == null ||
        widget.externalRequestId == oldWidget.externalRequestId) {
      return;
    }
    _externalEntryStatus = null;
    _launchExternalEntry(uri);
  }

  void _launchExternalEntry(Uri uri) {
    final requestId = widget.externalRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.externalQuickEntryUri != uri ||
          widget.externalRequestId != requestId) {
        return;
      }
      if (uri.queryParameters['more'] == 'true') {
        unawaited(
          _openQuickEntryTemplates().whenComplete(
            widget.onExternalEntryComplete ?? () {},
          ),
        );
      } else {
        unawaited(_openQuickEntry(uri));
      }
    });
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    _expenseWidgetRefresh?.close();
    super.dispose();
  }

  Future<void> _openQuickEntry([Uri? uri]) async {
    if (!_quickEntryInteraction.tryStart()) return;
    try {
      // A widget can cold-launch the app before the asynchronous UI providers
      // have loaded their stored values. Read the repositories here so Quick
      // Entry never briefly falls back to the built-in category or payment
      // method defaults.
      final categories = await ref.read(categoryRepositoryProvider).getAll();
      final methods = await ref.read(paymentMethodRepositoryProvider).getAll();
      final templateId = uri?.queryParameters['template_id'];
      final templateName = uri?.queryParameters['template_name'];
      final templates = await ref
          .read(quickEntryTemplateRepositoryProvider)
          .getAll();
      final template = templateId == null
          ? null
          : templates.where((item) => item.id == templateId).firstOrNull ??
                templates
                    .where((item) => item.name == templateName)
                    .firstOrNull;
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
      if (expense == null || !mounted) {
        if (widget.externalOnly && mounted) {
          setState(() => _externalEntryStatus = 'Quick entry cancelled');
        } else {
          widget.onExternalEntryComplete?.call();
        }
        return;
      }
      await ref.read(expensesProvider.notifier).add(expense);
      if (mounted) {
        AppToast.showUndo(
          context,
          message: 'Expense saved',
          onUndo: () => ref.read(expensesProvider.notifier).delete(expense.id),
        );
        // A successful restricted quick entry moves into the normal protected
        // app. AppLockGate immediately asks for device authentication there.
        widget.onExternalEntryComplete?.call();
      }
    } finally {
      _quickEntryInteraction.finish();
    }
  }

  Future<void> _openQuickEntryTemplates() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const QuickEntryTemplatesPage()));

  Future<void> _refreshAppShortcuts() async {
    final templates = await ref
        .read(quickEntryTemplateRepositoryProvider)
        .getAll();
    if (mounted) await AndroidAppShortcuts.refresh(templates);
  }

  Future<void> _refreshHomeWidget(List<Expense> expenses) async {
    final templates = await ref
        .read(quickEntryTemplateRepositoryProvider)
        .getAll();
    if (!mounted) return;
    await AndroidHomeWidget.refresh(
      templates,
      expenses: expenses,
      currency: ref.read(appCurrencyProvider),
      hideFinancialDetails: ref.read(appLockEnabledProvider) ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.externalOnly) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: _externalEntryStatus == null
                ? const CircularProgressIndicator()
                : Text(_externalEntryStatus!),
          ),
        ),
      );
    }
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
