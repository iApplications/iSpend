import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/recovery_envelope_store.dart';
import '../../../core/database/recovery_key.dart';
import '../../../core/widgets/app_toast.dart';
import '../../categories/category_providers.dart';
import '../../expenses/expense_providers.dart';
import '../../payment_methods/payment_method_providers.dart';
import '../../settings/appearance_preference.dart';
import '../../settings/currency_preference.dart';
import '../../settings/time_format_preference.dart';
import '../backup_providers.dart';

class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});
  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  bool busy = false;
  Future<String?> pass(String title) async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => _PassphraseDialog(title: title),
    );
    return v == null || v.isEmpty ? null : v;
  }

  Future<void> export() async {
    final p = await pass('Create backup');
    if (p == null) return;
    setState(() => busy = true);
    try {
      final e = await RecoveryEnvelopeStore().read();
      if (e == null) throw const RecoveryPassphraseException();
      await const RecoveryKeyService().unwrap(envelope: e, passphrase: p);
      final d = await ref
          .read(manualBackupServiceProvider)
          .export(database: ref.read(backupDatabaseProvider), passphrase: p);
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final location = await FilePicker.saveFile(
        dialogTitle: 'Save encrypted iSpend backup',
        fileName: 'ispend-backup-$date.ispendbackup',
        bytes: Uint8List.fromList(utf8.encode(d)),
        mimeType: 'application/octet-stream',
        type: FileType.custom,
        allowedExtensions: ['ispendbackup'],
      );
      if (location != null && mounted) {
        AppToast.show(context, 'Backup saved');
      }
    } on RecoveryPassphraseException {
      err('That recovery passphrase is incorrect. Backup not created.');
    } catch (_) {
      err('The backup could not be created. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ispendbackup'],
    );
    if (f == null) return;
    final p = await pass('Restore backup');
    if (p == null) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('Replace current data?'),
        content: const Text(
          'Restoring this backup will replace the expenses and settings currently on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await ref
          .read(manualBackupServiceProvider)
          .restore(
            database: ref.read(backupDatabaseProvider),
            document: utf8.decode(await f.readAsBytes()),
            passphrase: p,
          );
      final e = await const RecoveryKeyService().wrap(
        databaseKey: ref.read(backupDatabaseKeyProvider),
        passphrase: p,
      );
      await RecoveryEnvelopeStore().write(e);
      // Do not invalidate active NotifierProviders here. Their initial loads
      // run in microtasks, so invalidating them mid-restore can leave the
      // Expenses page watching a notifier that was disposed before it loaded.
      // Reload their persisted state instead.
      await ref.read(expensesProvider.notifier).refresh();
      await ref.read(categoriesProvider.notifier).refresh();
      await ref.read(paymentMethodsProvider.notifier).refresh();
      ref.invalidate(categoryIconKeysProvider);
      ref.invalidate(recurringExpensesProvider);
      ref.invalidate(dueRecurringExpensesProvider);
      await ref.read(appCurrencyProvider.notifier).refresh();
      await ref.read(timeFormatPreferenceProvider.notifier).refresh();
      await ref.read(appearancePreferenceProvider.notifier).refresh();
      if (mounted) AppToast.show(context, 'Backup restored');
    } on RecoveryPassphraseException {
      err(
        'That passphrase did not open this backup. Your current data was not changed.',
      );
    } on FormatException {
      err('This is not a supported iSpend backup.');
    } catch (_) {
      err('The backup could not be restored. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void err(String s) {
    if (mounted) {
      AppToast.showError(context, s);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Backup & Restore')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Your data, in your hands',
          style: Theme.of(c).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your expense data stays local. Backups are encrypted and need your recovery passphrase to restore.',
        ),
        const SizedBox(height: 24),
        card(
          Icons.upload_file_outlined,
          'Export backup',
          'Create one encrypted backup file to save safely.',
          'Create backup',
          busy ? null : export,
        ),
        const SizedBox(height: 16),
        card(
          Icons.download_for_offline_outlined,
          'Restore backup',
          'Restore a previously exported iSpend backup file.',
          'Restore backup',
          busy ? null : restore,
        ),
        const SizedBox(height: 24),
        const Text(
          'Restoring a backup replaces the expenses and settings currently on this device.',
        ),
      ],
    ),
  );
  Widget card(IconData i, String t, String d, String b, VoidCallback? f) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i),
              const SizedBox(height: 12),
              Text(t, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(d),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: f, icon: Icon(i), label: Text(b)),
            ],
          ),
        ),
      );
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.title});
  final String title;
  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      obscureText: true,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Recovery passphrase',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Continue'),
      ),
    ],
  );
}
