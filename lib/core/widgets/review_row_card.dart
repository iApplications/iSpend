import 'package:flutter/material.dart';

import 'app_surface.dart';

/// One imported transaction or order to review. A compact summary (tick box,
/// title, amount, a status written in words) sits above an "Edit details"
/// section that holds the editable fields. Rows that need attention start
/// expanded; ready rows start collapsed so a long list stays easy to scan.
class ReviewRowCard extends StatelessWidget {
  const ReviewRowCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.selected,
    required this.onSelectedChanged,
    required this.ready,
    required this.summary,
    required this.fields,
    this.notes = const [],
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  /// Ready rows show "Ready"; others show "Review" with a warning icon.
  final bool ready;

  /// Short facts under the header, such as the category and payment method.
  final List<String> summary;

  /// Callouts or plain notes shown between the header and the summary.
  final List<Widget> notes;
  final List<Widget> fields;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: onSelectedChanged == null
                    ? null
                    : (v) => onSelectedChanged!(v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amount, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    _StatusPill(ready: ready),
                  ],
                ),
              ),
            ],
          ),
          for (final note in notes)
            Padding(padding: const EdgeInsets.only(top: 8), child: note),
          if (summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                summary.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.only(left: 4),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              initiallyExpanded: initiallyExpanded,
              maintainState: true,
              title: const Text('Edit details'),
              children: fields,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = ready
        ? scheme.primaryContainer
        : (dark ? const Color(0xFF3A2E14) : const Color(0xFFFBF0D9));
    final foreground = ready
        ? scheme.onPrimaryContainer
        : (dark ? const Color(0xFFF6DFA8) : const Color(0xFF5C3B06));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!ready) ...[
              Icon(Icons.warning_amber_rounded, size: 12, color: foreground),
              const SizedBox(width: 3),
            ],
            Text(
              ready ? 'Ready' : 'Review',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fixed bar under a review list: what is selected, and the action.
class ReviewBottomBar extends StatelessWidget {
  const ReviewBottomBar({
    required this.summary,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String summary;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
