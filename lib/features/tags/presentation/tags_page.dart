import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/app_toast.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_providers.dart';
import '../../settings/currency_preference.dart';
import '../data/tag_rules.dart';

/// Every tag in use, with how often and how much. Tapping one lists its
/// expenses; tags can be renamed (merging into an existing tag) or removed.
/// Removing a tag never deletes the expenses that carry it.
class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final currency = ref.watch(appCurrencyProvider);
    final usage = tagUsage(expenses);
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: usage.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No tags yet. Add tags when you add or edit an expense.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final entry in usage)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sell_outlined),
                      title: Text(entry.key),
                      subtitle: Text(
                        '${entry.value} ${entry.value == 1 ? 'expense' : 'expenses'} · '
                        '${formatCurrencyCents(_total(expenses, entry.key), currency)}',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TagExpensesPage(tag: entry.key),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Tag options',
                        onSelected: (action) => action == 'rename'
                            ? _rename(context, ref, entry.key)
                            : _delete(context, ref, entry.key, entry.value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Remove tag'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  int _total(List<Expense> expenses, String tag) => expenses
      .where((e) => e.tags.any((t) => t.toLowerCase() == tag.toLowerCase()))
      .fold<int>(0, (sum, e) => sum + e.amountCents);

  Future<void> _rename(BuildContext context, WidgetRef ref, String tag) async {
    final controller = TextEditingController(text: tag);
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxTagLength,
          decoration: const InputDecoration(
            helperText: 'Using a name that already exists merges the two tags.',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered == null || !context.mounted) return;
    final known = tagUsage(ref.read(expensesProvider)).map((e) => e.key);
    final next = normalizeTag(entered);
    if (next == null) {
      AppToast.showError(context, 'Enter a tag name.');
      return;
    }
    // An existing tag keeps its own spelling when the names differ only by case
    // and the user is merging into it.
    final spelling = known.firstWhere(
      (k) => k.toLowerCase() == next.toLowerCase() && k != tag,
      orElse: () => next,
    );
    if (spelling == tag) return;
    try {
      await ref.read(expensesProvider.notifier).renameTag(tag, spelling);
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(context, 'Could not rename the tag.');
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String tag,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove "$tag"?'),
        content: Text(
          'It will be taken off $count ${count == 1 ? 'expense' : 'expenses'}. '
          'The expenses themselves stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(expensesProvider.notifier).deleteTag(tag);
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(context, 'Could not remove the tag.');
      }
    }
  }
}

class TagExpensesPage extends ConsumerWidget {
  const TagExpensesPage({required this.tag, super.key});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(appCurrencyProvider);
    final key = tag.toLowerCase();
    final expenses = ref
        .watch(expensesProvider)
        .where((e) => e.tags.any((t) => t.toLowerCase() == key))
        .toList();
    final total = expenses.fold<int>(0, (sum, e) => sum + e.amountCents);
    return Scaffold(
      appBar: AppBar(title: Text('#$tag')),
      body: expenses.isEmpty
          ? const Center(child: Text('No expenses have this tag.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${formatCurrencyCents(total, currency)} · ${expenses.length} '
                  '${expenses.length == 1 ? 'expense' : 'expenses'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                for (final e in expenses)
                  Card(
                    child: ListTile(
                      title: Text(
                        e.merchantOrNote ?? e.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${e.category} · ${e.occurredAt.year}-'
                        '${e.occurredAt.month.toString().padLeft(2, '0')}-'
                        '${e.occurredAt.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: Text(
                        formatCurrencyCents(e.amountCents, currency),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
