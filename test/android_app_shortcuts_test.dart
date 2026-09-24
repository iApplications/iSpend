import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/quick_entry/android_app_shortcuts.dart';
import 'package:ispend/features/quick_entry/data/quick_entry_template.dart';

void main() {
  QuickEntryTemplate template(String id, {required bool favourite}) =>
      QuickEntryTemplate(
        id: id,
        name: 'Template $id',
        categoryId: 'food',
        sortOrder: 0,
        isFavorite: favourite,
        createdAt: DateTime(2026),
      );

  test('reserves one device shortcut slot for Add Expense', () {
    final items = AndroidAppShortcuts.buildItems([
      template('one', favourite: true),
      template('two', favourite: true),
      template('three', favourite: true),
    ], 3);

    expect(items.map((item) => item.type), [
      AndroidAppShortcuts.addExpenseAction,
      'quick_entry_template_one',
      'quick_entry_template_two',
    ]);
  });

  test('does not add template shortcuts when the device reports one slot', () {
    final items = AndroidAppShortcuts.buildItems([
      template('one', favourite: true),
    ], 1);

    expect(items, hasLength(1));
    expect(items.single.type, AndroidAppShortcuts.addExpenseAction);
  });

  test('does not publish non-favourite templates as app shortcuts', () {
    final items = AndroidAppShortcuts.buildItems([
      template('regular', favourite: false),
      template('favourite', favourite: true),
    ], 4);

    expect(items.map((item) => item.type), [
      AndroidAppShortcuts.addExpenseAction,
      'quick_entry_template_favourite',
    ]);
  });

  test('extracts a template ID only from an iSpend template shortcut', () {
    expect(
      AndroidAppShortcuts.templateIdFromAction('quick_entry_template_abc'),
      'abc',
    );
    expect(AndroidAppShortcuts.templateIdFromAction('quick_entry_add'), isNull);
  });
}
