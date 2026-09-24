/// Keeps one Quick Entry interaction active at a time.
///
/// Android can re-deliver a widget, shortcut, or tile action while the first
/// interaction is still resolving. This guard is deliberately scoped to that
/// open interaction: it does not reject a later, intentional expense entry
/// just because its details happen to match an earlier expense.
class QuickEntryInteractionGuard {
  var _active = false;

  bool tryStart() {
    if (_active) return false;
    _active = true;
    return true;
  }

  void finish() => _active = false;
}
