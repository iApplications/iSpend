import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
import '../data/receipt_parser.dart';
import '../data/image_compression.dart';
import '../data/paid_amount_ocr.dart';
import '../data/shopping_order_parser.dart';
import '../data/shopping_screenshot_ocr.dart';
import '../data/temporary_image_cleanup.dart';
import 'shopping_order_import_page.dart';

class ReceiptImportPage extends ConsumerStatefulWidget {
  const ReceiptImportPage({super.key, this.initialSuggestion});

  final ReceiptSuggestion? initialSuggestion;

  @override
  ConsumerState<ReceiptImportPage> createState() => _ReceiptImportPageState();
}

class _ReceiptImportPageState extends ConsumerState<ReceiptImportPage> {
  final _picker = ImagePicker();
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  ReceiptSuggestion? _suggestion;
  String? _sourcePath;
  bool _keepImage = false;
  bool _useScannedAmount = false;
  DateTime? _occurredAt;
  String? _category;
  String? _paymentMethod;
  bool _scanning = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initialSuggestion = widget.initialSuggestion;
    if (initialSuggestion != null) {
      _suggestion = initialSuggestion;
      _amount.text = initialSuggestion.amountCents == null
          ? ''
          : formatCents(initialSuggestion.amountCents!);
      _merchant.text = initialSuggestion.merchant ?? '';
      _occurredAt = initialSuggestion.occurredAt;
    }
    Future<void>.microtask(_recoverLostImage);
  }

  Future<void> _recoverLostImage() async {
    try {
      final lost = await _picker.retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      final files = lost.files;
      if (files != null && files.isNotEmpty) {
        await _scanImage(files.first);
      } else if (lost.exception != null) {
        AppToast.showError(
          context,
          'Could not recover the camera photo. Try again.',
        );
      }
    } catch (_) {
      // Other platforms may not support lost-data recovery.
    }
  }

  @override
  void dispose() {
    unawaited(discardTemporaryOcrImage(_sourcePath));
    _amount.dispose();
    _merchant.dispose();
    super.dispose();
  }

  Future<void> _chooseImage(ImageSource source) async {
    if (_scanning || _saving) return;
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (mounted) AppToast.showError(context, 'Could not open the image.');
      return;
    }
    if (file == null || !mounted) return;
    await _scanImage(file);
  }

  Future<void> _chooseImageFile() async {
    if (_scanning || _saving) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (file == null || !mounted) return;
      if (!{'png', 'jpg', 'jpeg'}.contains(file.extension?.toLowerCase())) {
        AppToast.showError(context, 'Choose a PNG or JPEG image.');
        return;
      }
      await _scanImage(file.xFile);
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Could not open the image file.');
      }
    }
  }

  Future<void> _scanImage(XFile file) async {
    if (_scanning || !mounted) return;
    setState(() => _scanning = true);
    final recognizer = ShoppingScreenshotOcr();
    try {
      final lines = await recognizer.recognize(file.path);
      final currency = ref.read(appCurrencyProvider);
      final orderCandidates = const ShoppingOrderParser().parseImage(
        imagePath: file.path,
        lines: lines,
        currencyCode: currency.code,
        currencySymbol: currency.symbol,
      );
      if (hasMultipleTaobaoOrderCards(orderCandidates)) {
        if (!mounted) return;
        final previousPath = _sourcePath;
        _sourcePath = null; // The batch-review page now owns this image.
        if (previousPath != file.path) {
          unawaited(discardTemporaryOcrImage(previousPath));
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ShoppingOrderImportPage(
              initialImagePath: file.path,
              initialCandidates: orderCandidates,
            ),
          ),
        );
        return;
      }
      final suggestion = const ReceiptParser().parse(
        input: lines,
        currencyCode: currency.code,
        currencySymbol: currency.symbol,
      );
      if (!mounted) return;
      final categories = ref.read(categoriesProvider);
      final methods = ref.read(paymentMethodsProvider);
      final history = ref.read(expensesProvider);
      final suggestedCategory = categories.isEmpty
          ? null
          : const SmartQuickEntryParser()
                .parse(
                  input: suggestion.merchant ?? '',
                  categories: categories,
                  paymentMethods: methods,
                  history: history,
                )
                .category;
      _amount.text = suggestion.amountCents == null
          ? ''
          : formatCents(suggestion.amountCents!);
      _merchant.text = suggestion.merchant ?? '';
      final previousPath = _sourcePath;
      setState(() {
        _suggestion = suggestion;
        _sourcePath = file.path;
        _keepImage = false;
        _useScannedAmount = false;
        _occurredAt = suggestion.occurredAt;
        _category = suggestedCategory;
        _paymentMethod = _detectedPaymentMethod(suggestion.rawText, methods);
      });
      if (previousPath != file.path) {
        unawaited(discardTemporaryOcrImage(previousPath));
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Could not read this image. Try another.');
      }
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  String? _detectedPaymentMethod(String text, List<String> methods) {
    final paymentLines = text
        .split('\n')
        .where(
          (line) => RegExp(
            r'payment method|paid (?:by|with|via)|付款方式|支付方式',
            caseSensitive: false,
          ).hasMatch(line),
        );
    for (final line in paymentLines) {
      for (final method in methods) {
        if (line.toLowerCase().contains(method.toLowerCase())) return method;
      }
    }
    return null;
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final initial = _occurredAt ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose purchase date',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _occurredAt?.hour ?? 12,
        _occurredAt?.minute ?? 0,
      );
    });
  }

  Future<void> _chooseTime() async {
    if (_occurredAt == null) {
      await _chooseDate();
      if (_occurredAt == null || !mounted) return;
    }
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt!),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final date = _occurredAt!;
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  bool _looksLikeExisting(int amountCents, DateTime occurredAt) {
    final merchant = _normalize(_merchant.text);
    if (merchant.isEmpty) return false;
    return ref
        .read(expensesProvider)
        .any(
          (expense) =>
              expense.amountCents == amountCents &&
              _normalize(expense.merchantOrNote ?? '') == merchant &&
              expense.occurredAt.year == occurredAt.year &&
              expense.occurredAt.month == occurredAt.month &&
              expense.occurredAt.day == occurredAt.day,
        );
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');

  Future<void> _save() async {
    if (_saving) return;
    final cents = parseAmountToCents(_amount.text);
    final date = _occurredAt;
    final category = _category;
    if (cents == null || cents <= 0 || date == null || category == null) {
      AppToast.showError(
        context,
        'Enter an amount and purchase date before adding this expense.',
      );
      return;
    }
    if (_looksLikeExisting(cents, date)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Possible duplicate'),
          content: const Text(
            'An expense with this merchant, amount, and date already exists. Add another one?',
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
      final expense = Expense(
        id: const Uuid().v4(),
        amountCents: cents,
        category: category,
        occurredAt: date,
        createdAt: DateTime.now(),
        merchantOrNote: _merchant.text.trim().isEmpty
            ? null
            : _merchant.text.trim(),
        paymentMethod: _paymentMethod,
      );
      final imageBytes = _keepImage && _sourcePath != null
          ? await compressImageForStorage(_sourcePath!)
          : null;
      await ref.read(expensesProvider.notifier).addAll(
        [expense],
        attachments: imageBytes == null
            ? const []
            : [
                ExpenseImageAttachment(
                  bytes: imageBytes,
                  expenseIds: {expense.id},
                ),
              ],
      );
      if (!mounted) return;
      AppToast.show(context, 'Expense added');
      Navigator.of(context).pop();
    } on ImageStorageLimitException {
      if (mounted) {
        AppToast.showError(
          context,
          'Image storage is full. Turn off Keep image to add this expense.',
        );
      }
    } on FormatException {
      if (mounted) {
        AppToast.showError(
          context,
          'This image could not be retained within 1 MB. Turn off Keep image to continue.',
        );
      }
    } catch (_) {
      if (mounted) AppToast.showError(context, 'Could not save this expense.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final methods = ref.watch(paymentMethodsProvider);
    final currency = ref.watch(appCurrencyProvider);
    if (_category != null && !categories.contains(_category)) {
      _category = categories.isEmpty ? null : categories.first;
    }
    if (_paymentMethod != null && !methods.contains(_paymentMethod)) {
      _paymentMethod = null;
    }
    final suggestion = _suggestion;
    final scannedAmountCents = scannedPaidAmountCents(
      suggestion?.foreignAmountReference,
    );
    final scannedAmountText = scannedAmountCents == null
        ? null
        : formatCents(scannedAmountCents);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a receipt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text(
              'Take a photo or choose an existing receipt or payment screenshot. Files in Downloads can be selected with Browse files. Check the details before adding it.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _scanning
                  ? null
                  : () => _chooseImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take receipt photo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _scanning
                  ? null
                  : () => _chooseImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photo or screenshot'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _scanning ? null : _chooseImageFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Browse files in Downloads'),
            ),
            if (_scanning) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Reading image on this device…'),
            ],
            if (suggestion != null && !_scanning) ...[
              const SizedBox(height: 20),
              AppSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Review expense',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Recognition can make mistakes. Edit any field below.',
                    ),
                    if (suggestion.amountNeedsReview &&
                        suggestion.foreignAmountReference == null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Amount needs review: no clear final payment was found.',
                      ),
                    ],
                    if (suggestion.foreignAmountReference != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Detected ${suggestion.foreignAmountReference}. Enter an amount in ${currency.code}, or choose to copy the scanned number unchanged. No currency conversion is applied.',
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Amount (${currency.code})',
                        prefixText: '${currency.symbol} ',
                      ),
                      onChanged: (value) {
                        if (_useScannedAmount && value != scannedAmountText) {
                          setState(() => _useScannedAmount = false);
                        }
                      },
                    ),
                    if (scannedAmountText != null)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _useScannedAmount,
                        title: const Text('Use scanned amount'),
                        subtitle: Text(
                          'Copy ${suggestion.foreignAmountReference} as ${currency.code} $scannedAmountText. No conversion.',
                        ),
                        onChanged: (value) => setState(() {
                          _useScannedAmount = value ?? false;
                          if (_useScannedAmount) {
                            _amount.text = scannedAmountText;
                          } else if (_amount.text == scannedAmountText) {
                            _amount.clear();
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _merchant,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Merchant or note',
                      ),
                    ),
                    if (suggestion.merchant == null)
                      const Text(
                        'Merchant needs review: enter a shop or note if known.',
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: (value) => setState(() => _category = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment method',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Not specified'),
                        ),
                        for (final method in methods)
                          DropdownMenuItem<String?>(
                            value: method,
                            child: Text(method),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _paymentMethod = value),
                    ),
                    const SizedBox(height: 8),
                    if (suggestion.dateNeedsReview)
                      const Text('Purchase date needs review.'),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _chooseDate,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            _occurredAt == null
                                ? 'Choose purchase date'
                                : '${_occurredAt!.day}/${_occurredAt!.month}/${_occurredAt!.year}',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _chooseTime,
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            _occurredAt == null
                                ? 'Choose time'
                                : TimeOfDay.fromDateTime(
                                    _occurredAt!,
                                  ).format(context),
                          ),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Recognized image text'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            suggestion.rawText.isEmpty
                                ? 'No text recognized.'
                                : suggestion.rawText,
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Keep image with expense'),
                      subtitle: const Text('Off by default · up to 1 MB'),
                      value: _keepImage,
                      onChanged: (value) => setState(() => _keepImage = value),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Add expense'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
