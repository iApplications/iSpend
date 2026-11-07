import '../../guides/data/guide_catalog.dart';
import '../../guides/presentation/contextual_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/expense_providers.dart';
import '../../settings/currency_preference.dart';
import '../data/expense_csv_exporter.dart';
import '../export_providers.dart';

/// Exports the user's own expenses as CSV. Both exports are plain, unencrypted
/// files that only contain what the user entered; the tax export is a
/// record-keeping list, not tax advice or a tax calculation.
class ExportDataPage extends ConsumerStatefulWidget {
  const ExportDataPage({super.key});

  @override
  ConsumerState<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends ConsumerState<ExportDataPage> {
  /// Null means every year.
  int? _taxYear;
  bool _exporting = false;

  Future<void> _export({required bool taxOnly}) async {
    if (_exporting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save an unencrypted file?'),
        content: const Text(
          'The CSV is not encrypted or password protected. Anyone who can '
          'open the file can read your spending. Store it somewhere private.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _exporting = true);
    try {
      var expenses = ref.read(expensesProvider);
      if (taxOnly) {
        expenses = [
          for (final expense in expenses)
            if (expense.isTaxDeductible &&
                (_taxYear == null || expense.occurredAt.year == _taxYear))
              expense,
        ];
      }
      if (expenses.isEmpty) {
        AppToast.showError(
          context,
          taxOnly
              ? 'No expenses are marked tax-deductible'
                    '${_taxYear == null ? '' : ' in $_taxYear'}. Turn on '
                    '"Count as tax-deductible" when editing an expense.'
              : 'There are no expenses to export.',
        );
        return;
      }
      final stamp = DateTime.now();
      final name = taxOnly
          ? 'ispend-tax-deductible-${_taxYear ?? 'all'}.csv'
          : 'ispend-expenses-${stamp.year}-'
                '${stamp.month.toString().padLeft(2, '0')}-'
                '${stamp.day.toString().padLeft(2, '0')}.csv';
      final saved = await ref
          .read(exportFileAccessProvider)
          .save(
            fileName: name,
            bytes: const ExpenseCsvExporter().build(
              expenses,
              currencyCode: ref.read(appCurrencyProvider).code,
            ),
          );
      if (saved && mounted) {
        AppToast.show(
          context,
          'Exported ${expenses.length} '
          '${expenses.length == 1 ? 'expense' : 'expenses'}',
        );
      }
    } catch (_) {
      if (mounted) AppToast.showError(context, 'Could not save the file.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Every year with an expense, so the choice is clear even before anything
  /// has been marked tax-deductible.
  List<int> _years(List<Expense> expenses) => {
    DateTime.now().year,
    for (final expense in expenses) expense.occurredAt.year,
  }.toList()..sort((a, b) => b.compareTo(a));

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final years = _years(expenses);
    final taxCount = expenses.where((e) => e.isTaxDeductible).length;
    if (_taxYear != null && !years.contains(_taxYear)) _taxYear = null;
    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: GuidedBody(
        guideId: GuideIds.exportData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Save your expenses as a CSV file you can open in a spreadsheet. '
              'The file is not encrypted; use Backup & Restore to move data '
              'between devices.',
            ),
            const SizedBox(height: 20),
            Text(
              'All expenses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _exporting ? null : () => _export(taxOnly: false),
              icon: const Icon(Icons.download_outlined),
              label: Text('Export all (${expenses.length})'),
            ),
            const SizedBox(height: 28),
            Text(
              'Tax-deductible expenses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Only expenses you marked as tax-deductible. This is a record of '
              'your own entries, not tax advice or a tax calculation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _taxYear,
              decoration: const InputDecoration(labelText: 'Year'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All years'),
                ),
                for (final year in years)
                  DropdownMenuItem<int?>(value: year, child: Text('$year')),
              ],
              onChanged: (value) => setState(() => _taxYear = value),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _exporting ? null : () => _export(taxOnly: true),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Export tax-deductible'),
            ),
            if (taxCount == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No expenses are marked tax-deductible yet. Turn on "Count as '
                  'tax-deductible" when adding or editing an expense.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
