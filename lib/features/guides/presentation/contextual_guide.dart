import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/guide_catalog.dart';
import '../guide_providers.dart';

/// A small card that explains a feature the first time its screen is opened.
/// It never blocks the screen: "Got it" dismisses it for good, and the same
/// text stays available under Settings > Help & Guide.
class ContextualGuide extends ConsumerWidget {
  const ContextualGuide({required this.guideId, super.key});

  final String guideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = guideTopicFor(guideId);
    final state = ref.watch(tutorialProvider);
    if (topic == null || !state.loaded || state.hasSeen(topic)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    topic.icon,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      topic.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                topic.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              for (final step in topic.steps)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•  ',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      ref.read(tutorialProvider.notifier).markSeen(topic),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A screen body with the one-time [ContextualGuide] above it. The card is
/// height-limited and scrolls on its own, so it can never push the screen's
/// own content out of reach on a small phone.
class GuidedBody extends StatelessWidget {
  const GuidedBody({required this.guideId, required this.child, super.key});

  final String guideId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ContextualGuide(guideId: guideId),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
