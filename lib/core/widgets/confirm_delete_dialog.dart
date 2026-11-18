import 'package:flutter/material.dart';

/// A confirmation for a destructive action. The red button and the icon are
/// extra cues; the action is always named in words ("Delete", "Remove"...).
/// Pops `true` when confirmed and `false` on Cancel.
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({
    required this.title,
    this.message,
    this.confirmLabel = 'Delete',
    this.icon = Icons.delete_outline,
    super.key,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF4A2326) : const Color(0xFFFCE8E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: scheme.error),
            ),
          ),
          const SizedBox(height: 12),
          Text(title),
        ],
      ),
      content: message == null ? null : Text(message!),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: dark ? const Color(0xFF2A0A0A) : scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
