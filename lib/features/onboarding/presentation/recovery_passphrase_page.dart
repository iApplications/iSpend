import 'package:flutter/material.dart';

class RecoveryPassphrasePage extends StatefulWidget {
  const RecoveryPassphrasePage({
    required this.isRestore,
    required this.onSubmit,
    super.key,
  });

  final bool isRestore;
  final Future<String?> Function(String passphrase) onSubmit;

  @override
  State<RecoveryPassphrasePage> createState() => _RecoveryPassphrasePageState();
}

class _RecoveryPassphrasePageState extends State<RecoveryPassphrasePage> {
  final _passphraseController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() => _error = 'Enter your recovery passphrase.');
      return;
    }
    if (!widget.isRestore && passphrase != _confirmationController.text) {
      setState(() => _error = 'The passphrases do not match.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onSubmit(passphrase);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.savings_outlined, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    widget.isRestore
                        ? 'Restore your iSpend data'
                        : 'Protect your iSpend backup',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.isRestore
                        ? 'Enter the recovery passphrase you created on your previous device.'
                        : 'Create a recovery passphrase so an automatic device backup can be opened on a new device.',
                    textAlign: TextAlign.center,
                  ),
                  if (!widget.isRestore) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Keep it somewhere safe. If you forget it, that backup cannot be restored. There is no reset or bypass.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 28),
                  TextField(
                    controller: _passphraseController,
                    obscureText: _obscure,
                    autofocus: true,
                    textInputAction: widget.isRestore
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onSubmitted: widget.isRestore ? (_) => _submit() : null,
                    decoration: InputDecoration(
                      labelText: 'Recovery passphrase',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscure
                            ? 'Show passphrase'
                            : 'Hide passphrase',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isRestore) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmationController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm recovery passphrase',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isRestore ? 'Restore data' : 'Continue',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
