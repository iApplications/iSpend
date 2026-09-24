import 'dart:io' show Platform;

import 'package:flutter/services.dart';

enum QuickSettingsTileAddResult { added, alreadyAdded, notAdded, manualSetup }

/// Android-only bridge for the optional Quick Settings fast-entry tile.
///
/// The tile never creates an expense itself. It always opens the shared
/// minimal Quick Entry flow, so normal validation, app-lock behaviour, and
/// expense saving remain in Flutter.
abstract final class AndroidQuickSettingsTile {
  static const _channel = MethodChannel('com.apps.ispend/quick_settings_tile');

  static Future<void> initialize({
    required Future<void> Function() onTap,
    required Future<void> Function(Uri uri) onWidgetTap,
  }) async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'quickEntryTileTapped') await onTap();
      if (call.method == 'quickEntryWidgetTapped') {
        final uri = Uri.tryParse(call.arguments as String? ?? '');
        if (uri != null) await onWidgetTap(uri);
      }
    });
    final launchedFromTile =
        await _channel.invokeMethod<bool>('consumeInitialQuickEntryTileTap') ??
        false;
    if (launchedFromTile) await onTap();
  }

  /// Requests placement through Android 13+'s system UI. Earlier Android
  /// versions expose the declared tile through the standard Quick Settings
  /// edit screen instead.
  static Future<QuickSettingsTileAddResult> requestAdd() async {
    if (!Platform.isAndroid) return QuickSettingsTileAddResult.manualSetup;
    final result = await _channel.invokeMethod<String>(
      'requestAddQuickSettingsTile',
    );
    return switch (result) {
      'added' => QuickSettingsTileAddResult.added,
      'already_added' => QuickSettingsTileAddResult.alreadyAdded,
      'not_added' => QuickSettingsTileAddResult.notAdded,
      _ => QuickSettingsTileAddResult.manualSetup,
    };
  }
}
