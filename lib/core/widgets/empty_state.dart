import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_surface.dart';

/// The shared empty screen: an invitation card near the top (so the screen
/// never looks broken) with an optional action, and an optional faded sketch
/// of what will fill the space. The sketch is plain grey shapes with no text
/// or numbers, so it cannot be mistaken for real records.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.previewRows = 0,
    this.previewLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// How many faded placeholder rows to show below the card (0 for none).
  final int previewRows;
  final String? previewLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurface(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: AppRadii.rowBorder,
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(icon, color: scheme.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (previewRows > 0) ...[
          const SizedBox(height: AppSpacing.xl),
          ExcludeSemantics(
            child: Opacity(
              opacity: 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (previewLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        previewLabel!,
                        style: text.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (var i = 0; i < previewRows; i++)
                    _GhostRow(widthFactor: 0.5 + 0.12 * (i % 3)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GhostRow extends StatelessWidget {
  const _GhostRow({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double height, {double? width, double? factor}) => SizedBox(
      height: height,
      width: width,
      child: factor == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadii.pillBorder,
              ),
            )
          : FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadii.pillBorder,
                ),
              ),
            ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadii.rowBorder,
            ),
            child: const SizedBox(width: 36, height: 36),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(9, factor: widthFactor),
                const SizedBox(height: 6),
                bar(7, factor: widthFactor * 0.6),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          bar(9, width: 48),
        ],
      ),
    );
  }
}
