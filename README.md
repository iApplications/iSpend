# iSpend

iSpend is a private, offline-first personal expense tracker for iOS and
Android. It is being built with Flutter and is designed to make everyday
spending quick to record, easy to review, and securely stored on the device.

## Project goals

- Record an expense in a few taps.
- Organise expenses by category and payment method.
- See clear weekly, monthly, and category-based spending summaries.
- Keep financial data private, encrypted, and usable without an account.
- Support safe device backup and recovery without collecting user data.

## Phase 1

The first release focuses on a dependable offline expense tracker. It will
include:

- A three-tab navigation bar: **Expenses**, **Summary**, and **Settings**.
- Manual expense entry, editing, and deletion.
- Default categories and payment methods, with management in Settings.
- Food preselected as the default category for a new expense.
- Category and payment-method deletion protection: deletion is blocked when
  expenses still use the item, and iSpend shows the number affected.
- Amounts rounded normally to two decimal places and stored internally as
  integer cents/sen to avoid floating-point errors.
- Weekly and monthly totals, with Monday as the first day of the week.
- A currency selected at first launch and kept fixed even if the device region
  changes later.
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

## Design principles

- Simple, calm, and readable screens.
- Original provider icons only. Names may be shown as text, but iSpend will
  never reproduce official logos or trademarked artwork.
- Local-first data ownership.
- Accessible controls and clear confirmation for destructive actions.

## Technology

- Flutter / Dart
- Riverpod using manual providers (no code generation in Phase 1)
- SQLCipher via `sqflite_sqlcipher`
- `flutter_secure_storage` for platform secure storage
- `sodium` for Argon2id-based recovery-key handling

## Development status

The project is in Phase 1 setup and implementation. The current app shell is
only a starting point; the expense-tracking features listed above are planned
work, not yet a completed release.

## Running locally

From the project folder:

```powershell
& "C:\Users\leong\develop\flutter\bin\flutter.bat" pub get
& "C:\Users\leong\develop\flutter\bin\flutter.bat" run
```

On Windows, the `sodium` dependency needs MSYS2 build tools available on
`PATH`, including `C:\msys64\usr\bin\bash.exe` and
`C:\msys64\usr\bin\make.exe`.
