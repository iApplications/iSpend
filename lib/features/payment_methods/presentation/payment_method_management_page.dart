import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/icon_registry.dart';
import '../payment_method_providers.dart';

class PaymentMethodManagementPage extends ConsumerWidget {
  const PaymentMethodManagementPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final colourKeys = ref.watch(paymentMethodColourKeysProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment methods')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add method'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemCount: methods.length,
        itemBuilder: (context, index) {
          final method = methods[index];
          final style = paymentMethodIconStyle(method);
          final colourKey = colourKeys[method] ?? 'default';
          return Card(
            child: ListTile(
              leading: DecoratedBox(
                decoration: BoxDecoration(
                  color: paymentMethodBadgeColor(
                    colourKey,
                    Theme.of(context).brightness,
                    style.color,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(style.icon, color: style.color),
                ),
              ),
              title: Text(method),
              onTap: () => _edit(context, ref, method),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Badge colour',
                    icon: const Icon(Icons.palette_outlined),
                    onPressed: () =>
                        _chooseColour(context, ref, method, colourKey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, method),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _chooseColour(
    BuildContext context,
    WidgetRef ref,
    String method,
    String selected,
  ) async {
    final colour = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final key in paymentMethodColourKeys)
                RadioListTile<String>(
                  value: key,
                  title: Text(paymentMethodColourLabel(key)),
                  secondary: DecoratedBox(
                    decoration: BoxDecoration(
                      color: paymentMethodBadgeColor(
                        key,
                        Theme.of(sheetContext).brightness,
                        paymentMethodIconStyle(method).color,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(width: 28, height: 28),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (colour != null) {
      await ref
          .read(paymentMethodColourKeysProvider.notifier)
          .set(method, colour);
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    String? oldName,
  ]) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _PaymentMethodNameDialog(
        oldName: oldName,
        existing: ref.read(paymentMethodsProvider),
      ),
    );
    if (name == null || name.isEmpty) return;
    final notifier = ref.read(paymentMethodsProvider.notifier);
    if (oldName == null) {
      await notifier.add(name);
    } else {
      await notifier.rename(oldName, name);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final count = await ref
        .read(paymentMethodsProvider.notifier)
        .expenseCount(name);
    final templateCount = await ref
        .read(paymentMethodsProvider.notifier)
        .templateCount(name);
    if (!context.mounted) return;
    if (count > 0 || templateCount > 0) {
      final message = templateCount == 0
          ? '$count ${count == 1 ? 'expense uses' : 'expenses use'} this payment method. Reassign them before deleting it.'
          : '${[if (count > 0) '$count ${count == 1 ? 'expense' : 'expenses'}', '$templateCount Quick Entry ${templateCount == 1 ? 'template' : 'templates'}'].join(' and ')} use this payment method. Reassign them before deleting it.';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Payment method in use'),
          content: Text(message),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete payment method?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(paymentMethodsProvider.notifier).delete(name);
    }
  }
}

/// Owns its text controller so it is disposed only after the dialog is gone.
class _PaymentMethodNameDialog extends StatefulWidget {
  const _PaymentMethodNameDialog({
    required this.oldName,
    required this.existing,
  });

  final String? oldName;
  final List<String> existing;

  @override
  State<_PaymentMethodNameDialog> createState() =>
      _PaymentMethodNameDialogState();
}

class _PaymentMethodNameDialogState extends State<_PaymentMethodNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.oldName ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    final duplicate = widget.existing.any(
      (method) =>
          method.toLowerCase() == name.toLowerCase() &&
          method != widget.oldName,
    );
    if (name.isEmpty || duplicate) {
      setState(
        () => _error = name.isEmpty
            ? 'Enter a payment method name.'
            : 'This payment method already exists.',
      );
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.oldName == null ? 'Add payment method' : 'Rename payment method',
    ),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(labelText: 'Name', errorText: _error),
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
