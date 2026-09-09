import 'package:flutter/material.dart';

import '../../../core/database/recovery_envelope_store.dart';
import '../../../core/database/recovery_key.dart';
import '../../../core/widgets/app_toast.dart';

class RecoveryPassphraseSettingsPage extends StatefulWidget {
  const RecoveryPassphraseSettingsPage({super.key});

  @override
  State<RecoveryPassphraseSettingsPage> createState() =>
      _RecoveryPassphraseSettingsPageState();
}

class _RecoveryPassphraseSettingsPageState
    extends State<RecoveryPassphraseSettingsPage> {
  static const _minimumPassphraseLength = 10;
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _envelopeStore = RecoveryEnvelopeStore();
  final RecoveryKeyOperations _recoveryKeyService = const RecoveryKeyService();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassphrase() async {
    final current = _currentController.text;
    final next = _newController.text;
    if (current.isEmpty) {
      setState(() => _error = 'Enter your current recovery passphrase.');
      return;
    }
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
      final envelope = await _envelopeStore.read();
      if (envelope == null) throw const RecoveryPassphraseException();
      final databaseKey = await _recoveryKeyService.unwrap(
        envelope: envelope,
        passphrase: current,
      );
      final replacement = await _recoveryKeyService.wrap(
        databaseKey: databaseKey,
        passphrase: next,
      );
      await _envelopeStore.write(replacement);
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.show(context, 'Recovery passphrase updated');
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
    } on RecoveryPassphraseException {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Your current recovery passphrase is incorrect.';
        });
      }
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
                'This protects the database key included with future automatic backups. '
                'Backups created before this change still require the old passphrase.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _PassphraseField(
            controller: _currentController,
            label: 'Current recovery passphrase',
          ),
          const SizedBox(height: 16),
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
                : const Text('Change recovery passphrase'),
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
