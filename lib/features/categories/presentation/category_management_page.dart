import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../category_providers.dart';

class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNameDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(category),
              trailing: PopupMenuButton<_CategoryAction>(
                tooltip: 'Category options',
                onSelected: (action) {
                  switch (action) {
                    case _CategoryAction.rename:
                      _showNameDialog(context, ref, existingName: category);
                    case _CategoryAction.delete:
                      _confirmDelete(context, ref, category);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _CategoryAction.rename,
                    child: Text('Rename'),
                  ),
                  PopupMenuItem(
                    value: _CategoryAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showNameDialog(
    BuildContext context,
    WidgetRef ref, {
    String? existingName,
  }) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryNameDialog(
        existingName: existingName,
        categories: ref.read(categoriesProvider),
      ),
    );
    if (name == null) return;
    if (existingName == null) {
      await ref.read(categoriesProvider.notifier).add(name);
    } else {
      await ref.read(categoriesProvider.notifier).rename(existingName, name);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String category,
  ) async {
    final affectedExpenseCount = await ref
        .read(categoriesProvider.notifier)
        .expenseCount(category);
    if (!context.mounted) return;
    if (affectedExpenseCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Category in use'),
          content: Text(
            '$affectedExpenseCount ${affectedExpenseCount == 1 ? 'expense uses' : 'expenses use'} this category. Reassign them before deleting it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('"$category" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await ref.read(categoriesProvider.notifier).delete(category);
  }
}

enum _CategoryAction { rename, delete }

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.existingName,
    required this.categories,
  });

  final String? existingName;
  final List<String> categories;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    final isDuplicate = widget.categories.any(
      (category) =>
          category.toLowerCase() == name.toLowerCase() &&
          category != widget.existingName,
    );
    if (name.isEmpty) {
      setState(() => _error = 'Enter a category name.');
      return;
    }
    if (isDuplicate) {
      setState(() => _error = 'This category already exists.');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final isAdding = widget.existingName == null;
    return AlertDialog(
      title: Text(isAdding ? 'Add category' : 'Rename category'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Category name',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: Text(isAdding ? 'Add' : 'Save')),
      ],
    );
  }
}
