import 'package:flutter/material.dart';

/// A rounded teal tile holding the page's icon.
class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, size: 28, color: scheme.onPrimary),
        ),
      ),
    );
  }
}

/// The one message that must not be missed: there is no way back from a
/// forgotten passphrase. It is stated in words and does not rely on colour.
class _WarningCallout extends StatelessWidget {
  const _WarningCallout();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF3A2E14) : const Color(0xFFFBF0D9);
    final border = dark ? const Color(0xFF8A6A22) : const Color(0xFFE2C27B);
    final foreground = dark ? const Color(0xFFF6DFA8) : const Color(0xFF5C3B06);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(color: foreground),
                  children: const [
                    TextSpan(
                      text: 'There is no reset or bypass. ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          'If you forget it, that backup cannot be restored. Keep it somewhere safe.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecoveryPassphrasePage extends StatefulWidget {
  const RecoveryPassphrasePage({
    required this.isRestore,
    required this.onSubmit,
    this.onStartFresh,
    super.key,
  });

  final bool isRestore;
  final Future<String?> Function(String passphrase) onSubmit;
  final Future<String?> Function()? onStartFresh;

  @override
  State<RecoveryPassphrasePage> createState() => _RecoveryPassphrasePageState();
}

class _RecoveryPassphrasePageState extends State<RecoveryPassphrasePage> {
  static const _minimumPassphraseLength = 10;
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
    if (!widget.isRestore && passphrase.length < _minimumPassphraseLength) {
      setState(
        () => _error =
            'Use at least $_minimumPassphraseLength characters for your recovery passphrase.',
      );
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

  Future<void> _startFresh() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start fresh instead?'),
        content: const Text(
          'This backup cannot be opened without its recovery passphrase. Starting fresh removes only the inaccessible iSpend data on this device and creates a new empty database. Your backup file stored elsewhere will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Start fresh'),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.onStartFresh == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onStartFresh!();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  void _showAnotherBackupHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use another backup'),
        content: const Text(
          'To use a different device backup, restore it through your device settings and reopen iSpend. For an iSpend backup file, choose Start fresh instead, then use Settings > Backup & Restore after setup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                  const _BrandTile(icon: Icons.shield_outlined),
                  const SizedBox(height: 20),
                  Text(
                    widget.isRestore
                        ? 'Restore your iSpend data'
                        : 'Protect your iSpend backup',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isRestore
                        ? 'Enter the recovery passphrase you created on your previous device.'
                        : 'Create a recovery passphrase so an automatic device backup can be opened on a new device.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!widget.isRestore) ...[
                    const SizedBox(height: 16),
                    const _WarningCallout(),
                  ],
                  const SizedBox(height: 24),
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
                      helperText: widget.isRestore
                          ? null
                          : 'Use at least $_minimumPassphraseLength characters.',
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
                              widget.isRestore && _error != null
                                  ? 'Try again'
                                  : widget.isRestore
                                  ? 'Restore data'
                                  : 'Continue',
                            ),
                    ),
                  ),
                  if (widget.isRestore && widget.onStartFresh != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _submitting ? null : _showAnotherBackupHelp,
                      child: const Text('Use another backup'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _submitting ? null : _startFresh,
                      child: const Text('Start fresh instead'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
