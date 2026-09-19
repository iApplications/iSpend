import 'package:home_widget/home_widget.dart';

import 'data/quick_entry_template.dart';

abstract final class AndroidHomeWidget {
  static const _favoriteKey = 'quick_entry_favorites';

  static Future<void> refresh(List<QuickEntryTemplate> templates) async {
    final favorites = templates
        .where((template) => template.isFavorite)
        .take(3)
        .toList();
    final names = favorites
        .where((template) => template.isFavorite)
        .take(3)
        .map((template) => '• ${template.name}')
        .join('\n');
    await HomeWidget.saveWidgetData<String>(
      _favoriteKey,
      names.isEmpty ? 'Add a favourite Quick Entry template in iSpend.' : names,
    );
    for (var index = 0; index < 3; index++) {
      await HomeWidget.saveWidgetData<String>(
        'quick_entry_favorite_${index + 1}',
        index < favorites.length ? favorites[index].name : '',
      );
      await HomeWidget.saveWidgetData<String>(
        'quick_entry_favorite_id_${index + 1}',
        index < favorites.length ? favorites[index].id : '',
      );
    }
    await HomeWidget.updateWidget(name: 'QuickEntryWidgetProvider');
  }
}
