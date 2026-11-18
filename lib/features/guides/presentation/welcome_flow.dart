import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_surface.dart';
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
      preview: _ExpensesPreview(),
    ),
    _Slide(
      icon: Icons.pie_chart_outline,
      title: 'Summary',
      body:
          'See where your money went by category and payment method, and '
          'follow your budgets.',
      preview: _SummaryPreview(),
    ),
    _Slide(
      icon: Icons.settings_outlined,
      title: 'Settings',
      body:
          'Customize categories and payment methods, back up your data, and '
          'choose your privacy options.',
      preview: _SettingsPreview(),
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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _index ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
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
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.preview,
  });

  final IconData icon;
  final String title;
  final String body;

  /// A small sketch of the real screen, so the slide matches what the user
  /// will see.
  final Widget preview;
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
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                Icons.waving_hand_outlined,
                size: 28,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Welcome to iSpend', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Your private expense tracker.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReassuranceChip(
                icon: Icons.phone_android_outlined,
                label: 'Stays on this phone',
              ),
              _ReassuranceChip(
                icon: Icons.no_accounts_outlined,
                label: 'No account',
              ),
            ],
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ExcludeSemantics(child: slide.preview),
          const SizedBox(height: 24),
          Text(slide.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            slide.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReassuranceChip extends StatelessWidget {
  const _ReassuranceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: AppRadii.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// The small sketches below are plain, fixed shapes that echo the real tabs.
/// They hold sample text only to show the layout; no real data is read.
class _ExpensesPreview extends StatelessWidget {
  const _ExpensesPreview();

  @override
  Widget build(BuildContext context) => AppSurface(
    child: Column(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: AppRadii.rowBorder,
          ),
          child: const SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent in November',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'RM 1,284.50',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _PreviewRow(
          color: Color(0xFFF6D2CC),
          title: 'Hokkien mee',
          subtitle: 'Food · Cash',
          amount: '8.20',
        ),
        const _PreviewRow(
          color: Color(0xFFCADDF2),
          title: 'Grab',
          subtitle: 'Transport',
          amount: '15.80',
        ),
      ],
    ),
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final Color color;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const SizedBox(width: 30, height: 30),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(amount, style: text.titleSmall),
        ],
      ),
    );
  }
}

class _SummaryPreview extends StatelessWidget {
  const _SummaryPreview();

  @override
  Widget build(BuildContext context) => const AppSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewBar(label: 'Food', percent: 40, color: Color(0xFFE5806F)),
        SizedBox(height: 12),
        _PreviewBar(label: 'Shopping', percent: 27, color: Color(0xFFD4789F)),
        SizedBox(height: 12),
        _PreviewBar(label: 'Transport', percent: 18, color: Color(0xFF5B93D0)),
      ],
    ),
  );
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          Text('$percent%', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: AppRadii.pillBorder,
        child: LinearProgressIndicator(
          value: percent / 100,
          minHeight: 6,
          color: color,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
        ),
      ),
    ],
  );
}

class _SettingsPreview extends StatelessWidget {
  const _SettingsPreview();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget row(String label, String? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.titleSmall)),
          if (value != null)
            Text(value, style: text.bodySmall?.copyWith(color: muted)),
          Icon(Icons.chevron_right, size: 18, color: muted),
        ],
      ),
    );
    return AppSurface(
      child: Column(
        children: [
          row('Categories', '8'),
          const Divider(height: 1),
          row('Budget limits', '3 set'),
          const Divider(height: 1),
          row('App lock', 'Off'),
          const Divider(height: 1),
          row('Backup & Restore', null),
        ],
      ),
    );
  }
}
