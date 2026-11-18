import 'package:flutter/material.dart';

/// A warm, bordered note for something to read before acting. The meaning is
/// always in the words and icon, never in the colour alone.
class Callout extends StatelessWidget {
  const Callout({required this.icon, required this.child, super.key});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF3A2E14) : const Color(0xFFFBF0D9);
    final border = dark ? const Color(0xFF8A6A22) : const Color(0xFFE2C27B);
    final foreground = dark ? const Color(0xFFF6DFA8) : const Color(0xFF5C3B06);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foreground),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
