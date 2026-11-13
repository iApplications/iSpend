import 'package:flutter/material.dart';

/// One short explanation shown once, where the feature is first opened, and
/// listed in Help & Guide afterwards.
///
/// [id] is stable. Raising [version] shows a materially redesigned guide once
/// more; unchanged guides are never shown again.
class GuideTopic {
  const GuideTopic({
    required this.id,
    required this.title,
    required this.icon,
    required this.summary,
    required this.steps,
    this.version = 1,
  });

  final String id;
  final String title;
  final IconData icon;

  /// One sentence on what the feature is for.
  final String summary;

  /// Plain, task-focused points.
  final List<String> steps;
  final int version;
}

const welcomeGuideVersion = 1;

/// The ids used by the contextual guide cards.
abstract final class GuideIds {
  static const addExpense = 'add_expense';
  static const recurring = 'recurring';
  static const budgets = 'budgets';
  static const quickEntry = 'quick_entry';
  static const receiptScan = 'receipt_scan';
  static const shoppingOrders = 'shopping_orders';
  static const pdfStatements = 'pdf_statements';
  static const tags = 'tags';
  static const foreignCurrency = 'foreign_currency';
  static const exportData = 'export_data';
  static const backup = 'backup';
  static const appLock = 'app_lock';
}

const guideTopics = <GuideTopic>[
  GuideTopic(
    id: GuideIds.addExpense,
    title: 'Adding an expense',
    icon: Icons.add_circle_outline,
    summary: 'Log spending in a few seconds.',
    steps: [
      'Tap Add, then type what you spent, for example "hokkien mee 8.20". '
          'iSpend picks the amount, merchant and a likely category for you.',
      'Change anything it guessed, then save. Tap an expense in the list to '
          'edit or delete it.',
      'Tags and another currency are optional extras in the same sheet.',
    ],
  ),
  GuideTopic(
    id: GuideIds.recurring,
    title: 'Recurring expenses',
    icon: Icons.repeat,
    summary: 'For bills that come back every month.',
    steps: [
      'Turn on "Repeats monthly" under More options when you add an expense.',
      'Each month a draft appears for you to confirm. Nothing is added '
          'without your confirmation.',
      'Stopping a recurring expense keeps the ones already recorded.',
    ],
  ),
  GuideTopic(
    id: GuideIds.budgets,
    title: 'Budget limits',
    icon: Icons.savings_outlined,
    summary: 'A monthly target for each category.',
    steps: [
      'Set a limit for a category here. The Summary tab shows how much of it '
          'you have used this month.',
      'Limits are for your own tracking; nothing is blocked when you pass one.',
    ],
  ),
  GuideTopic(
    id: GuideIds.quickEntry,
    title: 'Quick Entry',
    icon: Icons.bolt_outlined,
    summary: 'Log your usual spending with one tap.',
    steps: [
      'Create a template for something you buy often, such as a coffee, with '
          'its category and payment method.',
      'Favourite templates can appear in the Android widget, app shortcuts and '
          'the Quick Settings tile, so you can log without opening the full app.',
      'If App lock is on, quick logging from outside the app only works when '
          'you allow it in Settings.',
    ],
  ),
  GuideTopic(
    id: GuideIds.receiptScan,
    title: 'Scanning a receipt',
    icon: Icons.document_scanner_outlined,
    summary: 'Read a receipt or payment screenshot on this phone.',
    steps: [
      'Take a photo or choose a screenshot. The text is read on your device; '
          'the picture is never uploaded.',
      'iSpend suggests an amount, merchant and date. You review and change '
          'them before anything is saved.',
      'An amount in another currency is shown for reference and is never '
          'converted for you.',
    ],
  ),
  GuideTopic(
    id: GuideIds.shoppingOrders,
    title: 'Shopping order screenshots',
    icon: Icons.shopping_bag_outlined,
    summary: 'Turn order screenshots into expenses.',
    steps: [
      'Choose screenshots of your orders. iSpend reads the item and the total '
          'paid on your device.',
      'Review each order, tick the ones to add, then save them together.',
    ],
  ),
  GuideTopic(
    id: GuideIds.pdfStatements,
    title: 'PDF statements',
    icon: Icons.picture_as_pdf_outlined,
    summary: 'Import a statement instead of typing each line.',
    steps: [
      "Touch 'n Go, Public Bank and HSBC statements are supported. Open the "
          'scan icon on the Expenses tab and choose Import PDF statement.',
      'Scanned statements are read with on-device text recognition. Check '
          'every amount against the PDF; a warning appears if the total does '
          'not match.',
      'Payments, refunds and cash-back start unticked. Nothing is added until '
          'you save.',
    ],
  ),
  GuideTopic(
    id: GuideIds.tags,
    title: 'Tags',
    icon: Icons.sell_outlined,
    summary: 'Your own labels, in addition to categories.',
    steps: [
      'Add tags when you add or edit an expense. Separate several with commas.',
      'Suggestions come from tags you have used before, matched on this phone.',
      'Rename a tag here to merge it into another, or remove it. Removing a '
          'tag never deletes expenses.',
    ],
  ),
  GuideTopic(
    id: GuideIds.foreignCurrency,
    title: 'Other currencies',
    icon: Icons.currency_exchange,
    summary: 'Record spending abroad without losing the original amount.',
    steps: [
      'Choose a currency when you add an expense, then type the amount you '
          'paid and the exchange rate.',
      'The expense is converted once and saved in your own currency, so past '
          'totals never change when rates move.',
      'Suggested rates are optional and off by default. You can always type '
          'your own.',
    ],
  ),
  GuideTopic(
    id: GuideIds.exportData,
    title: 'Exporting your data',
    icon: Icons.table_chart_outlined,
    summary: 'Save your expenses as a spreadsheet file.',
    steps: [
      'Export everything, or only the expenses you marked tax-deductible for '
          'a year.',
      'The file is not encrypted, so keep it somewhere private. The tax export '
          'lists your own entries; it is not tax advice.',
    ],
  ),
  GuideTopic(
    id: GuideIds.backup,
    title: 'Backup & Restore',
    icon: Icons.backup_outlined,
    summary: 'Move your data to a new phone safely.',
    steps: [
      'A backup is encrypted with your recovery passphrase. Without the '
          'passphrase it cannot be opened, and iSpend cannot recover it.',
      'Restoring replaces the data on this phone with the backup.',
    ],
  ),
  GuideTopic(
    id: GuideIds.appLock,
    title: 'App lock',
    icon: Icons.lock_outline,
    summary: 'Ask for your phone unlock before showing your data.',
    steps: [
      'Turn it on in Settings. iSpend then asks for your fingerprint, face, '
          'PIN or pattern when you return to it.',
      'With App lock on, screenshots and the recent-apps preview are hidden.',
    ],
  ),
];

GuideTopic? guideTopicFor(String id) {
  for (final topic in guideTopics) {
    if (topic.id == id) return topic;
  }
  return null;
}
