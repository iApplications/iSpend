# iSpend

iSpend is a private, offline-first personal expense tracker for iOS and Android. It is built with Flutter and designed to make everyday spending quick to record, easy to review, and securely stored on the device.

## Project goals

* Record an expense in a few taps.
* Organise expenses by category and payment method.
* See clear rolling-period and category-based spending summaries.
* Keep financial data private, encrypted, and usable without an iSpend account.
* Support safe device backup and recovery without collecting user financial data.
* Keep fast-entry features simple without relying on bank, card, or e-wallet integrations.

## Phase 1

The first release established the core offline expense tracker.

It includes:

* A three-tab navigation bar: **Expenses**, **Summary**, and **Settings**.
* Manual expense entry, editing, and deletion.
* Expense list ordered newest first and grouped under date headers.
* Default categories and payment methods, with management in Settings.
* Food preselected as the default category for a new expense.
* Category and payment-method deletion protection: deletion is blocked when expenses still use the item, and iSpend shows the number affected.
* Amounts rounded normally to two decimal places and stored internally as integer cents/sen to avoid floating-point errors.
* Today, last 7 days, and last 30 days totals ending on a user-selected date.
* Category and payment-method spending summaries.
* A currency selected at first launch and kept fixed even if the device region changes later.
* No per-expense currency selector in the core release; multi-currency is deferred to a later enhancement.
* Automatic device-backup support and recovery-passphrase onboarding.
* Encrypted local storage with no iSpend account or backend server.

## Privacy and security

iSpend has no sign-in requirement and does not use an iSpend cloud account for normal operation.

The local database uses SQLCipher Community Edition encryption. Its per-install database key is held in platform secure storage rather than inside the database itself.

For backup recovery, users create a required recovery passphrase during first launch. The passphrase protects a backup-specific envelope containing the database key. It is not requested during normal app use.

If the recovery passphrase is forgotten, backups protected by that passphrase cannot be decrypted. iSpend cannot reset, recover, or bypass the passphrase.

Recovery passphrases are protected with Argon2id using fixed parameters:

* `t=3`
* `m=65536` (64 MiB)
* `p=4`
* A unique random salt for each passphrase

Recovery passphrases must be at least 10 characters.

If the original device can still open its local database, **Settings** can create a new recovery passphrase for future backups without requiring the forgotten old passphrase. Existing backup files created under the old passphrase still require that previous passphrase.

On a fresh or new device, an unrecoverable backup must never trap the user on the restore screen. The recovery flow provides:

* **Try again**
* **Use another backup**
* **Start fresh instead**

Starting fresh removes only the inaccessible local restored iSpend state on that device. It does not delete an external backup file.

## Phase 1.5

Phase 1.5 adds depth to the core tracker while keeping the app fully local-first.

### Manual encrypted backup and restore

Users can export a complete encrypted iSpend backup and restore it on another installation using the same recovery-passphrase mechanism established in Phase 1.

### Recurring expenses

Basic monthly recurring expenses are supported.

A recurring schedule is stored separately from its generated expense occurrences. When a schedule becomes due, iSpend presents one pending draft for the scheduled date. It becomes a normal expense only after the user confirms or edits it.

The saved occurrence retains its recurring-rule reference but cannot create another recurring rule.

Schedule amount, category, payment method, next date, and active state are managed from:

**Settings > Recurring expenses**

Description, category, and payment method are shared series metadata. Editing these from the original expense, a confirmed occurrence, or schedule management updates the recurring series and linked expenses.

Amounts and transaction dates remain specific to each occurrence.

Stopping a schedule preserves its history. A stopped schedule can later be reactivated by choosing its next occurrence date, continuing the same recurring rule instead of creating a duplicate series.

### Budget limits

Monthly category budget limits are managed from:

**Settings > Budget limits**

Summary compares each configured category's spending for the selected reference month with its target and shows a plain remaining or over-budget amount.

Budget limits are included in full encrypted backups.

### Tax-deductible tracking

Expenses can optionally be marked tax-deductible for personal record-keeping.

Summary shows the tagged-expense count and total for the selected period.

This is a user-applied tracking label only. iSpend does not determine whether an expense qualifies for tax relief and does not provide tax advice or calculate tax deductions.

### App lock

App lock is optional and disabled by default.

When enabled from:

**Settings > Privacy & Data**

iSpend uses the device's supported biometric or device-credential authentication to protect access to financial data.

Recovery onboarding and backup recovery remain separate from the normal unlocked app shell.

## Appearance

iSpend supports three appearance modes:

* **System** — follows the device appearance.
* **Light** — always uses the light theme.
* **Dark** — always uses the dark theme.

All current and future UI, including Phase 2b quick-entry surfaces and payment-method badge colours, must support both light and dark themes.

## Phase 2 — Native iOS Fast Entry

> **Status: On hold pending Mac access.**

Phase 2 focuses on native Apple fast-entry features such as:

* Lock Screen widgets.
* Home Screen widgets.
* Apple Watch quick entry.
* Native iOS quick actions.

This phase requires genuine Mac access for development and testing.

The rest of the Flutter roadmap does not depend on Phase 2 being completed first. When Phase 2 resumes, it should reuse the shared quick-entry template model introduced in Phase 2b instead of maintaining a separate preset system.

## Phase 2b — Android Fast Entry

Phase 2b is the current development focus.

Its goal is to make expense entry significantly faster on Android while keeping all transactions local and user-confirmed.

### Stable category and payment-method IDs

Before quick-entry templates and payment-method colour customisation are built, categories and payment methods are migrated away from name-based relationship keys.

Each category and payment method receives a stable immutable ID.

Names remain editable display values, while expenses, recurring schedules, budgets, templates, colours, and other relationships reference the stable IDs.

This ensures renaming items such as **Food** or **Cash** does not break existing data or configuration.

Backup and restore must preserve these IDs and relationships.

### Payment-method colours

Payment methods can use a user-selected badge colour from a fixed accessible palette.

The picker provides:

* **Use default**
* 10 curated muted colours with light- and dark-theme variants

The selected palette key is stored against the payment method's stable ID so the choice survives renaming and full encrypted backup/restore.

**Use default** keeps the existing provider/default colour.

Free-form RGB and hex colour input is not supported.

Colour is only a visual recognition aid. Payment-method text and icons remain visible.

### Quick-entry templates

Users can create saved quick-entry templates for frequently repeated expense types.

A template can store:

* Template name
* Category
* Optional default payment method
* Optional merchant or note

The amount is normally **not stored in the template**, because the actual amount may change each time.

Using a template opens a minimal quick-entry screen with:

* Amount focused for immediate input
* Category prefilled but editable
* Payment method visible and editable
* Optional default payment method preselected
* Fast save action

Template changes apply only to future entries and never modify previously saved expenses.

Quick-entry templates and recurring-expense schedules are separate features.

The Phase 2b foundation is managed in **Settings > Quick Entry**. Templates
use immutable category and payment-method IDs, so renamed labels remain linked.
They can be created, edited, favourited, reordered, and deleted; removing a
category or payment method is blocked while any template still references it.
Full encrypted backups preserve templates, their order, favourite state, and
their optional payment-method defaults.

When a template has no separate default merchant/note, its template name is
used as the editable merchant/note fallback during quick entry.

### Smart Quick Entry

The Expenses **+ Add** action opens a compact local Smart Quick Entry flow.
It accepts a plain amount or short text such as `hokkien mee 8.20` and always
shows its amount, merchant, category, and payment-method interpretation for
editing before it saves. Category suggestions use explicit text first, then
matching local history, safe on-device keywords, and finally the normal Food
default. It does not use a cloud service or silently commit an uncertain guess.

### Android Home Screen widget

The Home Screen widget acts as a fast launcher rather than trying to provide unrestricted editable form fields directly inside the widget.

It can show:

* Today’s total and the latest expense, when app lock is off
* One optional favourite-template quick-add action
* A prominent **+ Add Expense** action

This keeps the compact widget to two tap targets. When app lock is enabled,
financial details are replaced with a privacy-safe prompt. Both actions open
the shared minimal quick-entry flow.
The widget uses one fixed compact Android size: it shows up to two favourite
quick-add chips and a **More ›** action for any additional favourites.

### App Shortcuts

Long-pressing the Android app icon provides:

* **Add Expense**
* Favourite quick-entry templates, up to the number supported by the device

Shortcuts use the same quick-entry flow as the Home Screen widget.
The app asks Android for the launcher-supported shortcut limit, reserves one
slot for **Add Expense**, and uses only the remaining slots for favourite
templates. Shortcut actions contain immutable template IDs, so a renamed
template remains the same shortcut target.

### Quick-entry safety

Widget and shortcut actions use the same expense-creation service as normal manual entry.

This keeps:

* Expenses
* Summary totals
* Budgets
* Tax-deductible tracking
* Backup and restore
* Recurring-expense behaviour

consistent across entry methods.

Quick-entry actions include request-scoped duplicate-action protection: while a
widget, App Shortcut, or Quick Settings Tile entry sheet is already opening or
active, re-delivered external actions are ignored. Once that sheet is saved or
cancelled, the next intentional action can start a new entry. This prevents one
interaction from creating duplicate expenses without rejecting separate,
legitimate expenses that happen to have the same values.

### App-lock behaviour

External quick-entry surfaces respect the normal app lock by default.

**Allow quick logging without app unlock**

This option is disabled by default.

When enabled, quick entry must expose only the minimum information required to create an expense and must not reveal spending history.

The setting is off by default and is available under Settings > Privacy & Data
when App lock is enabled. With it enabled, a widget or App Shortcut opens only
the minimal Quick Entry surface; the normal Expenses, Summary, Settings, and
history screens remain behind device authentication.
The widget's **More** action is treated as a full-app navigation and still
requires the normal unlock.

### Backup and restore

Phase 2b configuration is included in the full encrypted backup, including:

* Quick-entry templates
* Template ordering
* Favourite state
* Payment-method colour choices
* Template default payment methods
* Quick-entry security preferences

### Restore-flow hardening

Phase 2b also strengthens the existing backup recovery experience.

If a user cannot remember the passphrase for a restored backup, the app must always allow them to:

* Try again
* Choose another backup
* Start fresh

Choosing **Start fresh** requires confirmation, clears only inaccessible local restored state, creates a new encrypted database, and returns the user to recovery-passphrase setup.

The app must not require the user to manually clear application data through Android Settings just to exit an unsuccessful restore.

### App icon refresh

Phase 2b introduces the selected iSpend launcher icon direction: a teal/blue wallet design with a prominent plus symbol representing fast expense entry.

The supplied flattened PNG is the approved visual reference.

Android production assets require separate:

* Adaptive foreground
* Adaptive background
* Monochrome themed-icon asset

The wallet and plus must remain inside Android launcher safe areas so different launcher masks do not clip important parts of the icon.

### Optional stretch feature

The optional Android **Quick Settings tile** is a simple **Add expense** fast
launcher. It opens the same minimal Quick Entry flow as the widget and App
Shortcuts; it never accepts an amount or exposes financial details inside
Quick Settings itself.

On Android 13 and later, users can add it from **Settings > Quick Settings
tile** using Android's system placement prompt. On earlier Android versions,
the same declared tile can be added from the system's Quick Settings edit
screen. App-lock and the explicit quick-log bypass setting apply to it exactly
as they do to the other external quick-entry surfaces.

### Not included in Phase 2b

* Notification or bank-transaction parsing
* Receipt OCR
* Multi-currency expenses
* Bank, card, or e-wallet account linking

## Design principles

* Simple, calm, and readable screens.
* Original, non-official provider-inspired icons only.
* Provider names may appear as text, but iSpend never reproduces official logos or trademarked artwork.
* Nothing in the UI should imply endorsement, partnership, or integration with a financial provider.
* Phase 1 uses simple functional category icons.
* A later visual-enhancement phase may explore more expressive original category icon treatments while preserving quick recognition and text labels.
* Local-first data ownership.
* Colour is never the only carrier of information.
* Accessible controls and clear confirmation for destructive actions.
* Fast-entry features should reduce taps without silently creating or modifying financial records.

## Technology

* Flutter / Dart
* Riverpod using manual providers
* SQLCipher via `sqflite_sqlcipher`
* `flutter_secure_storage` for platform secure storage
* `sodium` for Argon2id-based recovery-key handling
* Native Android bridges where required for widgets and shortcuts

There is no iSpend backend server and no bank-account integration.

## Development status

**Phase 1:** Complete
**Phase 1.5:** Complete
**Phase 2:** On hold pending Mac access
**Phase 2b:** In development
**Phase 3:** Not started

Current Phase 2b work focuses on:

* Stable category/payment-method IDs
* Payment-method colour customisation
* Quick-entry templates
* Android widget and App Shortcuts
* Launcher icon refresh
* Backup/restore compatibility
* Restore-flow hardening

## Branching and pull-request workflow

Development uses phase integration branches rather than committing directly to `main`.

1. Start each phase from an up-to-date `main`.
2. Use the phase's integration branch:

   * Phase 1: `dev/Phase1_main`
   * Phase 1.5: `dev/phase1.5_main`
   * Phase 2b: `dev/phase2b_main`
3. Create individual feature branches from the applicable phase integration branch.
4. Push the feature branch to GitHub before making implementation changes.
5. Run the relevant tests and build checks.
6. Commit only after the applicable checks pass.
7. Open the feature pull request back into the phase integration branch.
8. When the phase is complete and verified, open the integration branch pull request into `main`.

Direct changes and commits to `main` should be avoided.

## Running locally

From the project folder:

```powershell
& "C:\Users\leong\develop\flutter\bin\flutter.bat" pub get
& "C:\Users\leong\develop\flutter\bin\flutter.bat" run
```

## Release APK

From the project folder, create an installable release APK with:

```powershell
& "C:\Users\leong\develop\flutter\bin\flutter.bat" build apk --release
```

The resulting APK is:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Before publishing outside testing, configure a private Android upload-signing key. Do not distribute a build signed with a development key.

On Windows, the `sodium` dependency requires MSYS2 build tools available on `PATH`, including:

```text
C:\msys64\usr\bin\bash.exe
C:\msys64\usr\bin\make.exe
```
