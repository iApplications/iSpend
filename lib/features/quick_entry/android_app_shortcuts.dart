import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';

import 'data/quick_entry_template.dart';

/// Owns Android's long-press app-icon actions for quick entry.
///
/// The native side reports the launcher-specific limit. We reserve one slot
/// for Add Expense, then use the remaining slots for favourite templates.
abstract final class AndroidAppShortcuts {
  static const addExpenseAction = 'quick_entry_add';
  static const templateActionPrefix = 'quick_entry_template_';
  static const _channel = MethodChannel('com.apps.ispend/shortcuts');
  static const _quickActions = QuickActions();

  static Future<void> initialize(Future<void> Function(String) onAction) {
    if (!Platform.isAndroid) return Future.value();
    return _quickActions.initialize(onAction);
  }

  static Future<void> refresh(List<QuickEntryTemplate> templates) async {
    if (!Platform.isAndroid) return;
    final maximum =
        await _channel.invokeMethod<int>('getMaxShortcutCount') ?? 0;
    await _quickActions.setShortcutItems(buildItems(templates, maximum));
  }

  static List<ShortcutItem> buildItems(
    List<QuickEntryTemplate> templates,
    int maximum,
  ) {
    final templateSlots = maximum > 0 ? maximum - 1 : 0;
    final favourites = templates
        .where((template) => template.isFavorite)
        .take(templateSlots)
        .toList();
    return [
      const ShortcutItem(
        type: addExpenseAction,
        localizedTitle: 'Add Expense',
        icon: 'ic_shortcut_add',
      ),
      for (final template in favourites)
        ShortcutItem(
          type: '$templateActionPrefix${template.id}',
          localizedTitle: template.name,
          icon: 'ic_shortcut_template',
        ),
    ];
  }

  static String? templateIdFromAction(String action) =>
      action.startsWith(templateActionPrefix)
      ? action.substring(templateActionPrefix.length)
      : null;
}
