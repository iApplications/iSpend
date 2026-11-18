import 'package:flutter/material.dart';

/// One rounded card holding a list of rows separated by thin dividers.
class GroupedListCard extends StatelessWidget {
  const GroupedListCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          children[i],
        ],
      ],
    ),
  );
}

/// A rounded, tinted tile holding a row's icon.
class IconBadge extends StatelessWidget {
  const IconBadge({
    required this.icon,
    required this.color,
    this.background,
    super.key,
  });

  final IconData icon;
  final Color color;

  /// Defaults to a light tint of [color].
  final Color? background;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: color),
    ),
  );
}

/// "12 expenses", "1 expense" or "Not used yet".
String usageLabel(int count) => switch (count) {
  0 => 'Not used yet',
  1 => '1 expense',
  _ => '$count expenses',
};
