import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:ispend/features/expenses/data/expense_model.dart';
import 'package:ispend/features/expenses/data/expense_repository.dart';

void main() {
  test(
    'one retained screenshot remains until its last expense link is removed',
    () async {
      final repository = InMemoryExpenseRepository();
      final jpeg = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 2, height: 2)),
      );
      final first = _expense('first');
      final second = _expense('second');

      await repository.saveAll(
        [first, second],
        attachments: [
          ExpenseImageAttachment(bytes: jpeg, expenseIds: {'first', 'second'}),
        ],
      );
      expect(await repository.imageStorageBytes(), jpeg.length);
      expect(await repository.expenseIdsWithImages(), {'first', 'second'});

      await repository.removeImageForExpense('first');
      expect(await repository.imageForExpense('second'), jpeg);
      expect(await repository.imageStorageBytes(), jpeg.length);

      await repository.delete('second');
      expect(await repository.imageStorageBytes(), 0);
      expect(await repository.expenseIdsWithImages(), isEmpty);
      expect((await repository.getAll()).map((expense) => expense.id), [
        'first',
      ]);
    },
  );

  test('invalid image batch leaves expenses untouched', () async {
    final repository = InMemoryExpenseRepository();
    await expectLater(
      repository.saveAll(
        [_expense('first')],
        attachments: [
          ExpenseImageAttachment(
            bytes: Uint8List.fromList([1, 2, 3]),
            expenseIds: {'first'},
          ),
        ],
      ),
      throwsFormatException,
    );
    expect(await repository.getAll(), isEmpty);
  });

  test('duplicate expense IDs do not partially save an image batch', () async {
    final repository = InMemoryExpenseRepository();
    final jpeg = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 2, height: 2)),
    );
    await repository.save(_expense('existing'));
    await expectLater(
      repository.saveAll(
        [_expense('new'), _expense('existing')],
        attachments: [
          ExpenseImageAttachment(bytes: jpeg, expenseIds: {'new'}),
        ],
      ),
      throwsStateError,
    );
    expect((await repository.getAll()).map((expense) => expense.id), [
      'existing',
    ]);
    expect(await repository.imageStorageBytes(), 0);
  });
}

Expense _expense(String id) => Expense(
  id: id,
  amountCents: 820,
  category: 'Food',
  occurredAt: DateTime(2026, 9, 24),
  createdAt: DateTime(2026, 9, 24),
);
