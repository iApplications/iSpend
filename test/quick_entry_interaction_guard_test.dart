import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/features/quick_entry/quick_entry_interaction_guard.dart';

void main() {
  test('ignores duplicate launches only while an interaction is active', () {
    final guard = QuickEntryInteractionGuard();

    expect(guard.tryStart(), isTrue);
    expect(guard.tryStart(), isFalse);

    guard.finish();

    expect(guard.tryStart(), isTrue);
  });
}
