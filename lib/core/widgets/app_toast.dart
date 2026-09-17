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
              child: Material(
                color: isError
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 18,
                        color: isError
                            ? Theme.of(context).colorScheme.onErrorContainer
                            : Theme.of(context).colorScheme.inversePrimary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: isError
                                ? Theme.of(context).colorScheme.onErrorContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (actionLabel != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return actionLabel == null ? IgnorePointer(child: toast) : toast;
  }
}
