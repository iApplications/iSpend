import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../categories/category_providers.dart';
import '../../expenses/expense_providers.dart';
import '../../payment_methods/payment_method_providers.dart';
import '../../settings/currency_preference.dart';
import '../data/quick_entry_template.dart';
import '../data/quick_entry_template_repository.dart';
import '../quick_entry_template_providers.dart';
import 'quick_entry_sheet.dart';

class QuickEntryTemplatesPage extends ConsumerWidget {
  const QuickEntryTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(quickEntryTemplatesProvider);
    final references = ref.watch(quickEntryTemplateReferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Entry')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: references.whenOrNull(
          data: (value) => value.categoryNamesById.isEmpty
              ? null
              : () => _editTemplate(context, ref, value),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add template'),
      ),
      body: references.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Quick Entry templates could not be loaded.'),
        ),
        data: (references) {
          if (templates.isEmpty) {
            return const _EmptyTemplates();
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: templates.length,
            onReorderItem: (oldIndex, newIndex) => ref
                .read(quickEntryTemplatesProvider.notifier)
                .reorder(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final template = templates[index];
              final category =
                  references.categoryNamesById[template.categoryId];
              final payment = template.paymentMethodId == null
                  ? null
                  : references.paymentMethodNamesById[template
                        .paymentMethodId!];
              return Card(
                key: ValueKey(template.id),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    template.isFavorite
                        ? Icons.star_rounded
                        : Icons.bolt_outlined,
                    color: template.isFavorite
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(template.name),
                  subtitle: Text(
                    [
                      category ?? 'Unavailable category',
                      if (payment != null) payment,
                      if (template.merchantOrNote != null)
                        template.merchantOrNote!,
                    ].join(' · '),
                  ),
                  trailing: PopupMenuButton<_TemplateAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _TemplateAction.use:
                          _useTemplate(context, ref, references, template);
                        case _TemplateAction.edit:
                          _editTemplate(context, ref, references, template);
                        case _TemplateAction.favorite:
                          ref
                              .read(quickEntryTemplatesProvider.notifier)
                              .save(
                                template.copyWith(
                                  isFavorite: !template.isFavorite,
                                ),
                              );
                        case _TemplateAction.delete:
                          _deleteTemplate(context, ref, template);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _TemplateAction.use,
                        child: Text('Use template'),
                      ),
                      const PopupMenuItem(
                        value: _TemplateAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: _TemplateAction.favorite,
                        child: Text(
                          template.isFavorite
                              ? 'Remove favourite'
                              : 'Mark favourite',
                        ),
                      ),
                      const PopupMenuItem(
                        value: _TemplateAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _useTemplate(
    BuildContext context,
    WidgetRef ref,
    QuickEntryTemplateReferences references,
    QuickEntryTemplate template,
  ) async {
    final expense = await showQuickEntrySheet(
      context,
      categories: ref.read(categoriesProvider),
      paymentMethods: ref.read(paymentMethodsProvider),
      history: ref.read(expensesProvider),
      currency: ref.read(appCurrencyProvider),
      template: template,
      categoryNamesById: references.categoryNamesById,
      paymentMethodNamesById: references.paymentMethodNamesById,
    );
    if (expense == null || !context.mounted) return;
    await ref.read(expensesProvider.notifier).add(expense);
    if (!context.mounted) return;
    _showUndo(context, ref, expense.id);
  }

  void _showUndo(BuildContext context, WidgetRef ref, String expenseId) {
    AppToast.showUndo(
      context,
      message: 'Expense saved',
      onUndo: () => ref.read(expensesProvider.notifier).delete(expenseId),
    );
  }

  Future<void> _editTemplate(
    BuildContext context,
    WidgetRef ref,
    QuickEntryTemplateReferences references, [
    QuickEntryTemplate? template,
  ]) async {
    final result = await showDialog<_TemplateDraft>(
      context: context,
      builder: (_) =>
          _TemplateDialog(template: template, references: references),
    );
    if (result == null || !context.mounted) return;
    final templates = ref.read(quickEntryTemplatesProvider);
    final updated = template == null
        ? newQuickEntryTemplate(
            name: result.name,
            categoryId: result.categoryId,
            paymentMethodId: result.paymentMethodId,
            merchantOrNote: result.merchantOrNote,
            sortOrder: templates.length,
          )
        : QuickEntryTemplate(
            id: template.id,
            name: result.name,
            categoryId: result.categoryId,
            paymentMethodId: result.paymentMethodId,
            merchantOrNote: result.merchantOrNote,
            sortOrder: template.sortOrder,
            isFavorite: template.isFavorite,
            createdAt: template.createdAt,
          );
    await ref.read(quickEntryTemplatesProvider.notifier).save(updated);
    ref.invalidate(quickEntryTemplateReferencesProvider);
    if (context.mounted) {
      AppToast.show(
        context,
        template == null
            ? 'Quick Entry template saved'
            : 'Quick Entry template updated',
      );
    }
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    QuickEntryTemplate template,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete “${template.name}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await ref.read(quickEntryTemplatesProvider.notifier).delete(template.id);
    if (context.mounted) AppToast.show(context, 'Quick Entry template deleted');
  }
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Quick Entry templates yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Save common categories and payment methods here. Amounts are entered when you log an expense.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({required this.references, this.template});

  final QuickEntryTemplateReferences references;
  final QuickEntryTemplate? template;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late String _categoryId;
  String? _paymentMethodId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _nameController = TextEditingController(text: template?.name ?? '');
    _noteController = TextEditingController(
      text: template?.merchantOrNote ?? '',
    );
    _categoryId =
        template?.categoryId ?? widget.references.categoryNamesById.keys.first;
    _paymentMethodId = template?.paymentMethodId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a template name.');
      return;
    }
    Navigator.of(context).pop(
      _TemplateDraft(
        name: name,
        categoryId: _categoryId,
        paymentMethodId: _paymentMethodId,
        merchantOrNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.template == null
          ? 'Add Quick Entry template'
          : 'Edit Quick Entry template',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Template name',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: widget.references.categoryNamesById.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _categoryId = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _paymentMethodId,
            decoration: const InputDecoration(
              labelText: 'Default payment method (optional)',
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              ...widget.references.paymentMethodNamesById.entries.map(
                (entry) => DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _paymentMethodId = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Default merchant or note (optional)',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Amounts are never stored in a template.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

class _TemplateDraft {
  const _TemplateDraft({
    required this.name,
    required this.categoryId,
    required this.paymentMethodId,
    required this.merchantOrNote,
  });

  final String name;
  final String categoryId;
  final String? paymentMethodId;
  final String? merchantOrNote;
}

enum _TemplateAction { use, edit, favorite, delete }
