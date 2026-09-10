import 'dart:async';

import 'package:flutter/material.dart';

abstract final class AppToast {
  static void show(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void _show(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastMessage(message: message, isError: isError),
    );
    overlay.insert(entry);
    unawaited(Future<void>.delayed(const Duration(seconds: 2), entry.remove));
  }
}

class _ToastMessage extends StatelessWidget {
  const _ToastMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SafeArea(
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
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
