# iSpend

iSpend is a private, offline-first personal expense tracker for iOS and
Android. It is being built with Flutter and is designed to make everyday
spending quick to record, easy to review, and securely stored on the device.

## Project goals

- Record an expense in a few taps.
- Organise expenses by category and payment method.
- See clear rolling-period and category-based spending summaries.
- Keep financial data private, encrypted, and usable without an account.
- Support safe device backup and recovery without collecting user data.

## Phase 1

The first release focuses on a dependable offline expense tracker. It will
include:

- A three-tab navigation bar: **Expenses**, **Summary**, and **Settings**.
- Manual expense entry, editing, and deletion.
- Expense list ordered newest first and grouped under date headers.
- Default categories and payment methods, with management in Settings.
- Food preselected as the default category for a new expense.
- Category and payment-method deletion protection: deletion is blocked when
  expenses still use the item, and iSpend shows the number affected.
- Amounts rounded normally to two decimal places and stored internally as
  integer cents/sen to avoid floating-point errors.
- Today, last 7 days, and last 30 days totals, ending on a user-selected date.
- A currency selected at first launch and kept fixed even if the device region
  changes later. There is no currency selector on Phase 1 expenses;
  multi-currency is deferred to the Phase 4a enhancement.
- Automatic device backups and a recovery-passphrase onboarding flow.

## Privacy and security

iSpend has no sign-in requirement and does not rely on a cloud account for
normal use. The local database will use SQLCipher Community Edition encryption.
Its per-install database key is held in the platform secure storage rather
than in the database itself.

For backup recovery, users create a required recovery passphrase during first
launch. The passphrase protects a backup-specific envelope for the database
key; it is not requested during normal app use. If it is forgotten, the backup
cannot be recovered. This is intentional: iSpend cannot reset or access a
user's recovery passphrase.

Recovery passphrases are protected with Argon2id using fixed parameters:
`t=3`, `m=65536` (64 MiB), and `p=4`, plus a unique random salt for each
passphrase.

Recovery passphrases must be at least 10 characters. If the original device
can still open its local database, Settings can set a new passphrase for
future backups without knowing a forgotten old one. Backups made before that
change still need the previous passphrase. On a new device, an unrecoverable
backup offers Try again, Use another backup, or Start fresh instead; starting
fresh deletes only inaccessible local iSpend state on that device, never an
external backup file.

## Phase 1.5

Phase 1.5 adds manual encrypted backup/restore and basic monthly recurring
expenses. A recurring schedule is stored separately from its generated expense
occurrences. When a schedule is due, iSpend presents one pending draft for the
scheduled date; it becomes a normal expense only after the user confirms or
edits it. The saved occurrence retains its recurring-rule reference but cannot
create another rule. Schedule amount, category, payment method, next date, and
active state are managed from **Settings > Recurring expenses**.
Description, category, and payment method are shared series metadata. Editing
them from the original expense, a confirmed occurrence, or schedule management
updates the schedule and all linked expenses; future drafts inherit the same
values. Amounts and transaction dates remain specific to each occurrence.
Stopping a schedule preserves its series history. It can be reactivated from
**Settings > Recurring expenses** by choosing its next occurrence date; this
resumes the same rule rather than creating a duplicate series.

Monthly category budget limits are managed from **Settings > Budget limits**.
Summary compares each configured category's spending in the selected reference
month with its target, including a plain remaining or over-budget amount.
Limits are encrypted app settings, included in manual backups, and follow a
category when it is renamed.

Expenses can optionally be marked tax-deductible for personal record-keeping.
Summary shows the tagged-expense count and total for its selected period; this
is a user label only and is not tax advice or a tax-relief calculation.

App lock is optional and off by default. When enabled from **Settings > Privacy
& Data**, iSpend uses the device's biometric or device-credential prompt when
opening the app and after it returns from the background. Recovery onboarding
and backup recovery remain available before the app shell is unlocked.

## Design principles

- Simple, calm, and readable screens.
- Original provider icons only. Names may be shown as text, but iSpend will
  never reproduce official logos or trademarked artwork.
- Phase 1 uses simple functional category icons. A later visual-enhancement
  phase will explore more expressive, entertaining original icon treatments
  while preserving quick recognition and text labels.
- Local-first data ownership.
- Accessible controls and clear confirmation for destructive actions.

## Technology

- Flutter / Dart
- Riverpod using manual providers (no code generation in Phase 1)
- SQLCipher via `sqflite_sqlcipher`
- `flutter_secure_storage` for platform secure storage
- `sodium` for Argon2id-based recovery-key handling

## Development status

Phase 1 implementation is complete and is in release-readiness verification.
The final checks are an Android backup/restore test on real devices and a
release APK build.

## Branching and pull-request workflow

All changes follow this workflow:

1. Start from an up-to-date `main` branch.
2. For Phase 1, use `dev/Phase1_main` as the integration branch. Create each
   Phase 1 feature branch from it as `dev/Phase1_{feature}`, push that branch
   to GitHub before making changes, then open its pull request back into
   `dev/Phase1_main`.
3. For Phase 1.5, use `dev/phase1.5_main` as the integration branch. For
   Phase 2b, use `dev/phase2b_main`. Create each feature branch from its
   applicable integration branch, and push it before making changes.
4. Run the relevant tests or build checks, then commit only after they pass.
5. Open a pull request for review and merge. Once Phase 1 is complete,
   `dev/Phase1_main` is the branch that opens the pull request into `main`.

Direct changes and commits to `main` should be avoided.

## Running locally

From the project folder:

```powershell
& "C:\Users\leong\develop\flutter\bin\flutter.bat" pub get
& "C:\Users\leong\develop\flutter\bin\flutter.bat" run
```

### Release APK

From the project folder, create an installable release APK with:

```powershell
& "C:\Users\leong\develop\flutter\bin\flutter.bat" build apk --release
```

The resulting file is `build\app\outputs\flutter-apk\app-release.apk`.
Before publishing outside testing, configure a private Android upload-signing
key; do not distribute a build signed with a development key.

On Windows, the `sodium` dependency needs MSYS2 build tools available on
`PATH`, including `C:\msys64\usr\bin\bash.exe` and
`C:\msys64\usr\bin\make.exe`.
