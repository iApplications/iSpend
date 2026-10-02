import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/app_toast.dart';
import '../../categories/category_providers.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/expense_providers.dart';
import '../../payment_methods/payment_method_providers.dart';
import '../../quick_entry/data/smart_quick_entry_parser.dart';
import '../../settings/currency_preference.dart';
import '../data/shopping_order_candidate.dart';
import '../data/image_compression.dart';
import '../data/paid_amount_ocr.dart';
import '../data/shopping_order_parser.dart';
import '../data/shopping_screenshot_ocr.dart';
import '../data/temporary_image_cleanup.dart';

class ShoppingOrderImportPage extends ConsumerStatefulWidget {
  const ShoppingOrderImportPage({
    super.key,
    this.initialImagePath,
    this.initialCandidates,
  });

  final String? initialImagePath;
  final List<ShoppingOrderCandidate>? initialCandidates;

  @override
  ConsumerState<ShoppingOrderImportPage> createState() =>
      _ShoppingOrderImportPageState();
}

class _ShoppingOrderImportPageState
    extends ConsumerState<ShoppingOrderImportPage> {
  final _parser = const ShoppingOrderParser();
  final _reviewRows = <_ReviewRow>[];
  Set<String> _selectedPaths = {};
  bool _scanning = false;
  bool _saving = false;
  String? _scanMessage;

  @override
  void initState() {
    super.initState();
    final path = widget.initialImagePath;
    final candidates = widget.initialCandidates;
    if (path != null && candidates != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCandidates(candidates, [path]);
      });
    }
  }

  @override
  void dispose() {
    for (final path in _selectedPaths) {
      unawaited(discardTemporaryOcrImage(path));
    }
    _disposeReviewRows();
    super.dispose();
  }

  Future<void> _chooseScreenshots() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result.isEmpty || !mounted) return;
    if (result.any(
      (file) => !{'png', 'jpg', 'jpeg'}.contains(file.extension?.toLowerCase()),
    )) {
      AppToast.showError(context, 'Choose PNG or JPEG screenshots.');
      return;
    }
    final paths = result
        .map((file) => file.path)
        .whereType<String>()
        .toSet()
        .toList();
    if (paths.isEmpty) {
      AppToast.showError(context, 'The selected images could not be opened.');
      return;
    }

    setState(() {
      _scanning = true;
      _scanMessage = null;
    });
    final currency = ref.read(appCurrencyProvider);
    final found = <ShoppingOrderCandidate>[];
    final recognizer = ShoppingScreenshotOcr();
    try {
      for (final path in paths) {
        final lines = await recognizer.recognize(path);
        found.addAll(
          _parser.parseImage(
            imagePath: path,
            lines: lines,
            currencyCode: currency.code,
            currencySymbol: currency.symbol,
          ),
        );
      }
      final candidates = _parser.deduplicateOverlappingScreenshots(found);
      _showCandidates(candidates, paths);
    } catch (_) {
      for (final path in paths.toSet().difference(_selectedPaths)) {
        unawaited(discardTemporaryOcrImage(path));
      }
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanMessage =
              'The screenshots could not be read. Try selecting them again.';
        });
        AppToast.showError(context, 'Could not scan the selected screenshots.');
      }
    } finally {
      await recognizer.close();
      if (mounted && _scanning) setState(() => _scanning = false);
    }
  }

  void _showCandidates(
    List<ShoppingOrderCandidate> candidates,
    List<String> paths,
  ) {
    final categories = ref.read(categoriesProvider);
    final methods = ref.read(paymentMethodsProvider);
    final history = ref.read(expensesProvider);
    final smartParser = const SmartQuickEntryParser();
    final rows = [
      for (final candidate in candidates)
        _createReviewRow(candidate, categories, methods, history, smartParser),
    ];
    if (!mounted) {
      for (final row in rows) {
        row.dispose();
      }
      return;
    }
    final previousRows = List<_ReviewRow>.of(_reviewRows);
    final previousPaths = _selectedPaths;
    setState(() {
      _selectedPaths = paths.toSet();
      _reviewRows.clear();
      _reviewRows.addAll(rows);
      _scanning = false;
      _scanMessage = candidates.isEmpty
          ? 'No order rows were recognized. Try a clearer screenshot.'
          : null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in previousRows) {
        row.dispose();
      }
      for (final path in previousPaths.difference(_selectedPaths)) {
        unawaited(discardTemporaryOcrImage(path));
      }
    });
  }

  bool _looksLikeExisting(
    ShoppingOrderCandidate candidate,
    List<Expense> expenses,
  ) {
    final amount = candidate.amountCents;
    final date = candidate.occurredAt;
    final merchant = _normalize(candidate.merchant ?? '');
    if (amount == null || date == null || merchant.isEmpty) return false;
    return expenses.any((expense) {
      final occurredAt = expense.occurredAt;
      return expense.amountCents == amount &&
          _normalize(expense.merchantOrNote ?? '') == merchant &&
          occurredAt.year == date.year &&
          occurredAt.month == date.month &&
          occurredAt.day == date.day;
    });
  }

  _ReviewRow _createReviewRow(
    ShoppingOrderCandidate candidate,
    List<String> categories,
    List<String> methods,
    List<Expense> history,
    SmartQuickEntryParser smartParser,
  ) {
    final suggestion = smartParser.parse(
      input: candidate.merchant ?? '',
      categories: categories,
      paymentMethods: methods,
      history: history,
    );
    return _ReviewRow(
      candidate: candidate,
      amountText: candidate.amountCents == null
          ? ''
          : formatCents(candidate.amountCents!),
      merchantText: candidate.merchant ?? '',
      category: categories.contains(suggestion.category)
          ? suggestion.category
          : categories.first,
      paymentMethod: suggestion.paymentMethod,
      occurredAt: candidate.occurredAt,
      selected: candidate.canImportByDefault,
      likelyDuplicate: _looksLikeExisting(candidate, history),
    );
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');

  Future<void> _chooseDate(_ReviewRow row) async {
    final now = DateTime.now();
    final initialDate = row.occurredAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose purchase date',
    );
    if (date != null && mounted) {
      setState(() {
        row.occurredAt = DateTime(
          date.year,
          date.month,
          date.day,
          row.occurredAt?.hour ?? 12,
          row.occurredAt?.minute ?? 0,
        );
      });
    }
  }

  Future<void> _importSelected() async {
    if (_saving) return;
    final selected = _reviewRows.where((row) => row.selected).toList();
    final expenses = <Expense>[];
    final keepByPath = <String, Set<String>>{};
    for (final row in selected) {
      final amount = parseAmountToCents(row.amountController.text);
      if (amount == null || amount <= 0 || row.occurredAt == null) {
        AppToast.showError(
          context,
          'Enter a valid amount and purchase date for each selected order.',
        );
        return;
      }
      final expense = Expense(
        id: const Uuid().v4(),
        amountCents: amount,
        category: row.category,
        merchantOrNote: row.merchantController.text.trim().isEmpty
            ? null
            : row.merchantController.text.trim(),
        paymentMethod: row.paymentMethod,
        occurredAt: row.occurredAt!,
        createdAt: DateTime.now(),
      );
      expenses.add(expense);
      if (row.keepImage) {
        (keepByPath[row.candidate.sourceImagePath] ??= {}).add(expense.id);
      }
    }
    if (expenses.isEmpty) return;

    final history = ref.read(expensesProvider);
    final duplicates = expenses
        .where(
          (expense) => history.any(
            (existing) =>
                existing.amountCents == expense.amountCents &&
                _normalize(existing.merchantOrNote ?? '') ==
                    _normalize(expense.merchantOrNote ?? '') &&
                expense.merchantOrNote != null &&
                existing.occurredAt.year == expense.occurredAt.year &&
                existing.occurredAt.month == expense.occurredAt.month &&
                existing.occurredAt.day == expense.occurredAt.day,
          ),
        )
        .length;
    if (duplicates > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Possible duplicates'),
          content: Text(
            '$duplicates selected order${duplicates == 1 ? '' : 's'} may already exist in Expenses. Add anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Review again'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Add anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      final attachments = <ExpenseImageAttachment>[];
      for (final entry in keepByPath.entries) {
        attachments.add(
          ExpenseImageAttachment(
            bytes: await compressImageForStorage(entry.key),
            expenseIds: entry.value,
          ),
        );
      }
      await ref
          .read(expensesProvider.notifier)
          .addAll(expenses, attachments: attachments);
      if (!mounted) return;
      AppToast.show(context, 'Added ${expenses.length} expenses');
      Navigator.of(context).pop();
    } on ImageStorageLimitException {
      if (mounted) {
        AppToast.showError(
          context,
          'Image storage is full. Turn off Keep image to add these expenses.',
        );
      }
    } on FormatException {
      if (mounted) {
        AppToast.showError(
          context,
          'A screenshot could not be retained within 1 MB. Turn off Keep image to continue.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'The selected expenses could not be saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _disposeReviewRows() {
    for (final row in _reviewRows) {
      row.dispose();
    }
    _reviewRows.clear();
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Choose purchase date';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _statusLabel(ShoppingOrderStatus status) => switch (status) {
    ShoppingOrderStatus.paid => 'Paid',
    ShoppingOrderStatus.needsReview => 'Needs review',
    ShoppingOrderStatus.cancelled => 'Cancelled',
    ShoppingOrderStatus.refunded => 'Refunded',
    ShoppingOrderStatus.unpaid => 'Unpaid',
  };

  String _platformLabel(ShoppingPlatform platform) => switch (platform) {
    ShoppingPlatform.shopee => 'Shopee',
    ShoppingPlatform.lazada => 'Lazada',
    ShoppingPlatform.taobao => 'Taobao',
    ShoppingPlatform.unknown => 'Shopping order',
  };

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final methods = ref.watch(paymentMethodsProvider);
    final currency = ref.watch(appCurrencyProvider);
    final selectedCount = _reviewRows.where((row) => row.selected).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Import shopping orders')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose one or more order-list screenshots from Files or Downloads. Review every result before it becomes an expense.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanning ? null : _chooseScreenshots,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _reviewRows.isEmpty
                    ? 'Browse screenshots in Files'
                    : 'Browse different screenshots',
              ),
            ),
            if (_scanning) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Reading screenshots on this device…'),
            ],
            if (_scanMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _scanMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_reviewRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${_reviewRows.length} order${_reviewRows.length == 1 ? '' : 's'} found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _reviewRows.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      itemCount: _reviewRows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _reviewCard(
                        _reviewRows[index],
                        categories,
                        methods,
                        currency,
                      ),
                    ),
            ),
            if (_reviewRows.isNotEmpty)
              FilledButton.icon(
                onPressed: selectedCount == 0 || _scanning || _saving
                    ? null
                    : _importSelected,
                icon: const Icon(Icons.add),
                label: Text('Add selected ($selectedCount)'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(
    _ReviewRow row,
    List<String> categories,
    List<String> methods,
    AppCurrency currency,
  ) {
    final amountValid =
        (parseAmountToCents(row.amountController.text) ?? 0) > 0;
    final canSelect = amountValid && row.occurredAt != null;
    final scannedAmountCents = scannedPaidAmountCents(
      row.candidate.foreignAmountReference,
    );
    final scannedAmountText = scannedAmountCents == null
        ? null
        : formatCents(scannedAmountCents);
    final textTheme = Theme.of(context).textTheme;
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: row.selected,
            onChanged: canSelect
                ? (value) => setState(() => row.selected = value ?? false)
                : null,
            title: Text(
              row.merchantController.text.isEmpty
                  ? 'Order ${_reviewRows.indexOf(row) + 1}'
                  : row.merchantController.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${_platformLabel(row.candidate.platform)} · ${_statusLabel(row.candidate.status)}',
            ),
          ),
          if (row.candidate.foreignAmountReference != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Detected ${row.candidate.foreignAmountReference}. Enter an amount in ${currency.code}, or choose to copy the scanned number unchanged. No currency conversion is applied.',
                style: textTheme.bodySmall,
              ),
            ),
          if (row.likelyDuplicate)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'May match an existing expense. Check before adding.',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          TextField(
            controller: row.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount (${currency.code})',
              prefixText: '${currency.symbol} ',
            ),
            onChanged: (value) => setState(() {
              if (value != scannedAmountText) row.useScannedAmount = false;
            }),
          ),
          if (scannedAmountText != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: row.useScannedAmount,
              title: const Text('Use scanned amount'),
              subtitle: Text(
                'Copy ${row.candidate.foreignAmountReference} as ${currency.code} $scannedAmountText. No conversion.',
              ),
              onChanged: (value) => setState(() {
                row.useScannedAmount = value ?? false;
                if (row.useScannedAmount) {
                  row.amountController.text = scannedAmountText;
                } else if (row.amountController.text == scannedAmountText) {
                  row.amountController.clear();
                  row.selected = false;
                }
              }),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: row.merchantController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Merchant or item'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: row.category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => row.category = value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: row.paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Not specified'),
              ),
              for (final method in methods)
                DropdownMenuItem<String?>(value: method, child: Text(method)),
            ],
            onChanged: (value) => setState(() => row.paymentMethod = value),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _chooseDate(row),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_dateLabel(row.occurredAt)),
            ),
          ),
          if (row.candidate.occurredAt == null)
            Text(
              row.candidate.rawText.toLowerCase().contains('delivered')
                  ? 'Only a delivery time was found. Choose the purchase or payment date to add this order.'
                  : 'The purchase date was not confidently identified. Choose it to add this order.',
              style: textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Recognized screenshot text'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(row.candidate.rawText),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep image with expense'),
            subtitle: const Text('Off by default · up to 1 MB per screenshot'),
            value: row.keepImage,
            onChanged: row.selected
                ? (value) => setState(() => row.keepImage = value)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ReviewRow {
  _ReviewRow({
    required this.candidate,
    required String amountText,
    required String merchantText,
    required this.category,
    required this.paymentMethod,
    required this.occurredAt,
    required this.selected,
    required this.likelyDuplicate,
  }) : amountController = TextEditingController(text: amountText),
       merchantController = TextEditingController(text: merchantText);

  final ShoppingOrderCandidate candidate;
  final TextEditingController amountController;
  final TextEditingController merchantController;
  String category;
  String? paymentMethod;
  DateTime? occurredAt;
  bool selected;
  bool keepImage = false;
  bool useScannedAmount = false;
  final bool likelyDuplicate;

  void dispose() {
    amountController.dispose();
    merchantController.dispose();
  }
}
