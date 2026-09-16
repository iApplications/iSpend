import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../backup/backup_providers.dart';

class RecoveryPassphraseSettingsPage extends ConsumerStatefulWidget {
  const RecoveryPassphraseSettingsPage({super.key});

  @override
  ConsumerState<RecoveryPassphraseSettingsPage> createState() =>
      _RecoveryPassphraseSettingsPageState();
}

class _RecoveryPassphraseSettingsPageState
    extends ConsumerState<RecoveryPassphraseSettingsPage> {
  static const _minimumPassphraseLength = 10;
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassphrase() async {
    final next = _newController.text;
    if (next.length < _minimumPassphraseLength) {
      setState(
        () => _error =
            'Use at least $_minimumPassphraseLength characters for the new passphrase.',
      );
      return;
    }
    if (next != _confirmController.text) {
      setState(() => _error = 'The new passphrases do not match.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final replacement = await ref
          .read(recoveryKeyOperationsProvider)
          .wrap(
            databaseKey: ref.read(backupDatabaseKeyProvider),
            passphrase: next,
          );
      await ref.read(recoveryEnvelopeAccessProvider).write(replacement);
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.show(context, 'Recovery passphrase updated');
      _newController.clear();
      _confirmController.clear();
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'The recovery passphrase could not be changed. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery passphrase')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Your current device can protect future backups with a new passphrase. '
                'Backups created before this change still require the old passphrase.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _PassphraseField(
            controller: _newController,
            label: 'New recovery passphrase',
            helperText: 'Use at least $_minimumPassphraseLength characters.',
          ),
          const SizedBox(height: 16),
          _PassphraseField(
            controller: _confirmController,
            label: 'Confirm new recovery passphrase',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _changePassphrase,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Set new recovery passphrase'),
          ),
        ],
      ),
    );
  }
}

class _PassphraseField extends StatelessWidget {
  const _PassphraseField({
    required this.controller,
    required this.label,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: true,
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
      border: const OutlineInputBorder(),
    ),
  );
}
