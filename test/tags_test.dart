import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';
import 'package:ispend/features/tags/data/tag_rules.dart';
import 'package:ispend/features/tags/presentation/tag_editor.dart';

Expense _e(String id, {String? merchant, List<String> tags = const []}) =>
    Expense(
      id: id,
      amountCents: 100,
      category: 'Food',
      occurredAt: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
      merchantOrNote: merchant,
      tags: tags,
    );

void main() {
  group('normalizeTags', () {
    test('trims, strips #, collapses spaces and drops empty tags', () {
      expect(normalizeTags(['  #Trip  to   KL ', '', '##', 'work']), [
        'Trip to KL',
        'work',
      ]);
    });

    test('keeps one tag per spelling regardless of case', () {
      expect(normalizeTags(['trip', 'TRIP', 'Trip']), ['trip']);
      expect(normalizeTags(['trip'], known: ['Trip']), ['Trip']);
    });

    test('limits the length and the number of tags', () {
      expect(normalizeTag('a' * 40)!.length, maxTagLength);
      final many = normalizeTags([for (var i = 0; i < 20; i++) 'tag$i']);
      expect(many, hasLength(maxTagsPerExpense));
    });
  });

  group('suggestTags', () {
    final history = [
      _e('1', merchant: 'Grab', tags: ['commute', 'work']),
      _e('2', merchant: 'Grab', tags: ['commute']),
      _e('3', merchant: 'Uniqlo', tags: ['clothes']),
      _e('4', merchant: 'Cafe', tags: ['clothes', 'treat']),
    ];

    test('puts tags used with the same merchant first', () {
      final result = suggestTags(history: history, merchant: 'grab');
      expect(result.take(2), ['commute', 'work']);
      expect(result, contains('clothes'));
    });

    test('skips tags already chosen and respects the limit', () {
      final result = suggestTags(
        history: history,
        merchant: 'Grab',
        selected: ['Commute'],
        limit: 2,
      );
      expect(result, ['work', 'clothes']);
    });

    test('with no merchant it offers the most used tags', () {
      expect(suggestTags(history: history, merchant: '').first, 'clothes');
    });
  });

  group('in-memory repository', () {
    test('renaming a tag merges it into an existing one', () async {
      final repo = InMemoryExpenseRepository();
      await repo.save(_e('1', tags: ['trip', 'work']));
      await repo.save(_e('2', tags: ['holiday']));
      await repo.renameTag('trip', 'work');
      final all = await repo.getAll();
      expect(all.firstWhere((e) => e.id == '1').tags, ['work']);
      expect(all.firstWhere((e) => e.id == '2').tags, ['holiday']);
    });

    test('removing a tag keeps the expense', () async {
      final repo = InMemoryExpenseRepository();
      await repo.save(_e('1', tags: ['trip', 'work']));
      await repo.deleteTag('TRIP');
      expect((await repo.getAll()).single.tags, ['work']);
    });

    test('renaming a category keeps tags', () async {
      final repo = InMemoryExpenseRepository();
      await repo.save(_e('1', tags: ['trip']));
      await repo.renameCategory('Food', 'Dining');
      expect((await repo.getAll()).single.tags, ['trip']);
    });
  });

  testWidgets('adds a typed tag and a suggestion, and removes one', (
    tester,
  ) async {
    var tags = <String>[];
    final controller = TextEditingController();
    final history = [
      _e('1', merchant: 'Grab', tags: ['commute']),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TagEditor(
              tags: tags,
              controller: controller,
              history: history,
              merchant: 'Grab',
              onChanged: (next) => setState(() => tags = next),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ActionChip, 'commute'));
    await tester.pump();
    expect(tags, ['commute']);

    await tester.enterText(find.byType(TextField), '#Lunch, team');
    await tester.tap(find.byTooltip('Add tag'));
    await tester.pump();
    expect(tags, ['commute', 'Lunch', 'team']);
    expect(controller.text, isEmpty);

    await tester.tap(find.byTooltip('Remove team'));
    await tester.pump();
    expect(tags, ['commute', 'Lunch']);
  });
}
