import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../payment_method_providers.dart';

class PaymentMethodManagementPage extends ConsumerWidget {
  const PaymentMethodManagementPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
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
          return Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(method),
              onTap: () => _edit(context, ref, method),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref, method),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    String? oldName,
  ]) async {
    final controller = TextEditingController(text: oldName ?? '');
    String? error;
    final name = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            oldName == null ? 'Add payment method' : 'Rename payment method',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Name', errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                final duplicate = ref
                    .read(paymentMethodsProvider)
                    .any(
                      (method) =>
                          method.toLowerCase() == name.toLowerCase() &&
                          method != oldName,
                    );
                if (name.isEmpty || duplicate) {
                  setState(
                    () => error = name.isEmpty
                        ? 'Enter a payment method name.'
                        : 'This payment method already exists.',
                  );
                  return;
                }
                Navigator.pop(c, name);
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
    if (!context.mounted) return;
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Payment method in use'),
          content: Text(
            '$count ${count == 1 ? 'expense uses' : 'expenses use'} this payment method. Reassign them before deleting it.',
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
