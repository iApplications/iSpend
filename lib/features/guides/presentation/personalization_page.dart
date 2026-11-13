import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../guide_providers.dart';

/// Edit or clear the optional name used in greetings. Clearing it returns the
/// greeting to plain "Good morning" (by time of day); saved expenses are never touched.
class PersonalizationPage extends ConsumerStatefulWidget {
  const PersonalizationPage({super.key});

  @override
  ConsumerState<PersonalizationPage> createState() =>
      _PersonalizationPageState();
}

class _PersonalizationPageState extends ConsumerState<PersonalizationPage> {
  late final _controller = TextEditingController(
    text: ref.read(displayNameProvider) ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = await ref
          .read(displayNameProvider.notifier)
          .set(clear ? '' : _controller.text);
      if (!mounted) return;
      _controller.text = name ?? '';
      AppToast.show(context, name == null ? 'Name cleared' : 'Name saved');
    } catch (_) {
      if (mounted) AppToast.showError(context, 'Could not save the name.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(displayNameProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Personalization')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            greetingFor(name),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'The name is optional and only used for a friendly greeting. It is '
            'stored on this phone, included in your encrypted backup, and '
            'never sent anywhere.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            maxLength: maxDisplayNameLength,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'What should iSpend call you?',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving || name == null
                ? null
                : () => _save(clear: true),
            child: const Text('Clear name'),
          ),
        ],
      ),
    );
  }
}
