import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/expense_providers.dart';
import '../guide_providers.dart';

/// Shows the welcome guide once, on a fresh install, after the mandatory
/// passphrase setup and any app-lock prompt. Someone who already has expenses
/// (for example after an update) is never walked through it.
class WelcomeGate extends ConsumerStatefulWidget {
  const WelcomeGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends ConsumerState<WelcomeGate> {
  bool _checked = false;

  Future<void> _decide() async {
    if (_checked) return;
    _checked = true;
    final tutorial = ref.read(tutorialProvider.notifier);
    try {
      final existing = await ref.read(expenseRepositoryProvider).getAll();
      if (!mounted) return;
      if (existing.isNotEmpty) {
        await tutorial.completeWelcome();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const WelcomeFlowPage(),
        ),
      );
    } catch (_) {
      // The welcome guide is optional; never block the app on it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorialProvider);
    if (state.loaded && !state.welcomeDone && !_checked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _decide();
      });
    }
    return widget.child;
  }
}

/// A short, skippable introduction: an optional name, then the three tabs.
/// Advanced features are explained later, where they are first opened.
class WelcomeFlowPage extends ConsumerStatefulWidget {
  const WelcomeFlowPage({super.key});

  @override
  ConsumerState<WelcomeFlowPage> createState() => _WelcomeFlowPageState();
}

class _WelcomeFlowPageState extends ConsumerState<WelcomeFlowPage> {
  late final _nameController = TextEditingController(
    text: ref.read(displayNameProvider) ?? '',
  );
  final _pages = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    _Slide(
      icon: Icons.receipt_long_outlined,
      title: 'Expenses',
      body:
          'Add spending in seconds and review what you have logged. Tap Add '
          'and type something like "hokkien mee 8.20".',
    ),
    _Slide(
      icon: Icons.pie_chart_outline,
      title: 'Summary',
      body:
          'See where your money went by category and payment method, and '
          'follow your budgets.',
    ),
    _Slide(
      icon: Icons.settings_outlined,
      title: 'Settings',
      body:
          'Customize categories and payment methods, back up your data, and '
          'choose your privacy options.',
    ),
  ];

  // Page 0 is the name; the slides follow.
  int get _pageCount => _slides.length + 1;
  bool get _isLast => _index == _pageCount - 1;

  @override
  void dispose() {
    _nameController.dispose();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool saveName}) async {
    final navigator = Navigator.of(context);
    if (saveName) {
      try {
        await ref.read(displayNameProvider.notifier).set(_nameController.text);
      } catch (_) {
        // The name is optional; carry on without it.
      }
    }
    await ref.read(tutorialProvider.notifier).completeWelcome();
    if (navigator.mounted) navigator.pop();
  }

  void _next() {
    if (_isLast) {
      _finish(saveName: true);
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(saveName: false);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _finish(saveName: true),
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (value) => setState(() => _index = value),
                    children: [
                      _NamePage(controller: _nameController, onDone: _next),
                      for (final slide in _slides) _SlidePage(slide: slide),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pageCount; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(_isLast ? 'Start using iSpend' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

class _NamePage extends StatelessWidget {
  const _NamePage({required this.controller, required this.onDone});

  final TextEditingController controller;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.waving_hand_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('Welcome to iSpend', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Your private expense tracker. Everything stays on this phone.',
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            maxLength: maxDisplayNameLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'What should iSpend call you? (optional)',
              helperText:
                  'Only used for a greeting. It is stored on this phone and '
                  'never sent anywhere. You can skip this.',
              helperMaxLines: 3,
            ),
            onSubmitted: (_) => onDone(),
          ),
        ],
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(slide.icon, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text(slide.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(slide.body, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
