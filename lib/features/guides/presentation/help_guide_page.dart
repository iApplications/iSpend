import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../data/guide_catalog.dart';
import '../guide_providers.dart';
import 'welcome_flow.dart';

/// Every guide in one place, so anything that was dismissed can be read again.
class HelpGuidePage extends ConsumerWidget {
  const HelpGuidePage({super.key});

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset tutorials?'),
        content: const Text(
          'The tips will appear again the next time you open each feature. '
          'Your expenses, settings and name are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(tutorialProvider.notifier).reset();
    if (context.mounted) AppToast.show(context, 'Tutorials reset');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Guide')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Short explanations of what iSpend can do. Each one also appears '
            'once, the first time you open that feature.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Replay the welcome guide'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => const WelcomeFlowPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final topic in guideTopics)
            Card(
              child: ExpansionTile(
                leading: Icon(topic.icon),
                title: Text(topic.title),
                subtitle: Text(topic.summary),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final step in topic.steps)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(
                            child: Text(
                              step,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _reset(context, ref),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset tutorials'),
          ),
        ],
      ),
    );
  }
}
