import 'dart:async';

import 'package:flutter/material.dart';

abstract final class AppToast {
  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ToastMessage(message: message));
    overlay.insert(entry);
    unawaited(Future<void>.delayed(const Duration(seconds: 2), entry.remove));
  }
}

class _ToastMessage extends StatelessWidget {
  const _ToastMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: Theme.of(context).colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
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
  );
}
