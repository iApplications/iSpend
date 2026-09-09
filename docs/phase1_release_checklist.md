# Phase 1 release checklist

## Automated checks

- [ ] `flutter analyze` completes with no issues.
- [ ] `flutter test` completes successfully.
- [ ] `flutter build apk --release` completes successfully.
- [ ] Install `build\app\outputs\flutter-apk\app-release.apk` and open it.

## Core regression check

- [ ] Add, edit, and delete an expense; confirm the list and rolling summaries update.
- [ ] Confirm category and payment-method add, rename, duplicate prevention, and in-use deletion protection.
- [ ] Confirm currency remains fixed after restarting the app.
- [ ] Confirm appearance and time-format preferences remain after restarting the app.
- [ ] Confirm the recovery-passphrase change screen rejects a wrong current passphrase and shows a toast after a successful update.

## Android backup and recovery check

This must be performed with two clean Android devices or emulator profiles that
use the same Android backup account. Android controls when automatic backups
run, so wait until its backup settings report a recent backup before moving to
the second device.

1. On device A, install iSpend and complete recovery-passphrase onboarding.
2. Add recognisable test data: at least two expenses, a custom category, a
   custom payment method, and a non-default appearance or time-format setting.
3. In Android Settings, confirm device backup is enabled and run/await a backup.
4. Set up device B with the same backup account and restore its Android backup.
5. Open iSpend. It must request the recovery passphrase rather than silently
   opening the database.
6. Enter a wrong passphrase first. The app must remain on the restore screen
   and display an error.
7. Enter the correct passphrase. Confirm the original expenses, custom labels,
   currency, appearance, and time-format setting are present.
8. Record the device models, Android versions, and result in the pull request.

## Publishing boundary

- [ ] A private Android upload-signing key is configured and stored outside the
  repository before any public distribution.
- [ ] The final Phase 1 pull request is opened from `dev/Phase1_main` into
  `main` only after all relevant checks above pass.
