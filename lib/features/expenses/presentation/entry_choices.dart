import 'package:flutter/material.dart';

import '../../../core/widgets/icon_registry.dart';
import '../data/expense_model.dart';

/// The payment methods to offer as chips: the most recently used ones from
/// [history], with the current [selected] one always included, falling back
/// to the first few configured methods for someone with no history yet.
List<String> recentPaymentMethods({
  required List<Expense> history,
  required List<String> available,
  String? selected,
  int limit = 3,
}) {
  final recent = <String>[];
  final ordered = [...history]
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  for (final expense in ordered) {
    final method = expense.paymentMethod;
    if (method != null && available.contains(method)) {
      if (!recent.contains(method)) recent.add(method);
      if (recent.length == limit) break;
    }
  }
  if (selected != null &&
      available.contains(selected) &&
      !recent.contains(selected)) {
    recent.insert(0, selected);
  }
  if (recent.isEmpty) recent.addAll(available.take(limit));
  return recent.take(limit).toList();
}

/// Category chips for the common categories, plus **More** for the rest.
/// Shared by the add/edit sheet and the quick-entry sheet so both look and
/// behave the same.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  static const _common = ['Food', 'Transport', 'Shopping', 'Bills'];

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final name in _common)
        if (categories.contains(name)) name,
    ];
    if (!shown.contains(selected) && categories.contains(selected)) {
      shown.add(selected);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in shown)
          _CategoryChoice(
            category: category,
            selected: category == selected,
            onTap: () => onChanged(category),
          ),
        if (categories.length > shown.length)
          ActionChip(
            avatar: const Icon(Icons.more_horiz, size: 18),
            label: const Text('More categories'),
            onPressed: () => _chooseMore(context),
          ),
      ],
    );
  }

  Future<void> _chooseMore(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final category in categories)
              ListTile(
                leading: Icon(
                  categoryIconStyle(category).icon,
                  color: categoryIconStyle(category).color,
                ),
                title: Text(category),
                trailing: category == selected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, category),
              ),
          ],
        ),
      ),
    );
    if (choice != null) onChanged(choice);
  }
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = categoryIconStyle(category);
    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      scale: selected ? 1.02 : 1,
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(style.icon, size: 18, color: selected ? style.color : null),
        label: Text(category),
        showCheckmark: selected,
      ),
    );
  }
}

/// The few most-used payment methods as chips, plus **More…** for the full
/// list and a way to choose none. The label always shows as text.
class PaymentMethodChips extends StatelessWidget {
  const PaymentMethodChips({
    required this.methods,
    required this.history,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> methods;
  final List<Expense> history;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final method in recentPaymentMethods(
        history: history,
        available: methods,
        selected: selected,
      ))
        ChoiceChip(
          label: Text(method),
          selected: selected == method,
          onSelected: (_) => onChanged(method),
        ),
      ActionChip(
        avatar: const Icon(Icons.more_horiz, size: 18),
        label: const Text('More…'),
        onPressed: () => _chooseMore(context),
      ),
    ],
  );

  Future<void> _chooseMore(BuildContext context) async {
    var picked = false;
    String? choice;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Payment method')),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('None'),
              trailing: selected == null ? const Icon(Icons.check) : null,
              onTap: () {
                picked = true;
                Navigator.pop(context);
              },
            ),
            for (final method in methods)
              ListTile(
                title: Text(method),
                trailing: selected == method ? const Icon(Icons.check) : null,
                onTap: () {
                  picked = true;
                  choice = method;
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
    if (picked && choice != selected) onChanged(choice);
  }
}
