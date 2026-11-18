import 'dart:async';

import 'package:flutter/material.dart';

abstract final class AppToast {
  static void show(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void showUndo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
  }) => _show(
    context,
    message,
    isError: false,
    actionLabel: 'Undo',
    onAction: onUndo,
    duration: const Duration(seconds: 4),
  );

  static void _show(
    BuildContext context,
    String message, {
    required bool isError,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    var removed = false;
    void removeOnce() {
      if (removed) return;
      removed = true;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _ToastMessage(
        message: message,
        isError: isError,
        actionLabel: actionLabel,
        onAction: () {
          removeOnce();
          onAction?.call();
        },
      ),
    );
    overlay.insert(entry);
    unawaited(Future<void>.delayed(duration, removeOnce));
  }
}

class _ToastMessage extends StatelessWidget {
  const _ToastMessage({
    required this.message,
    required this.isError,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final toast = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Semantics(
            liveRegion: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final scheme = theme.colorScheme;
                  final dark = theme.brightness == Brightness.dark;
                  final badge = isError
                      ? (dark
                            ? const Color(0xFF4A2326)
                            : const Color(0xFFFCE8E6))
                      : (dark
                            ? const Color(0xFF1E4642)
                            : const Color(0xFFDDF0EE));
                  final badgeIcon = isError
                      ? scheme.error
                      : (dark
                            ? const Color(0xFF9BE7E2)
                            : const Color(0xFF0B5F5B));
                  return Material(
                    color: dark ? const Color(0xFF18263A) : Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0x330F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: dark
                            ? const Color(0xFF2E4360)
                            : const Color(0xFFD3DDE3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: badge,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: Icon(
                                isError ? Icons.error_outline : Icons.check,
                                size: 16,
                                color: badgeIcon,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (actionLabel != null)
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: onAction,
                              child: Text(actionLabel!),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    return actionLabel == null ? IgnorePointer(child: toast) : toast;
  }
}
