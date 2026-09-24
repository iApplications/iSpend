# Phase 1 release checklist

## Automated checks

- [x] `flutter analyze` completes with no issues.
- [x] `flutter test` completes successfully.
- [x] `flutter build apk --release` completes successfully.
- [x] Install `build\app\outputs\flutter-apk\app-release.apk` and open it.

## Core regression check

- [x] Add, edit, and delete an expense; confirm the list and rolling summaries update.
- [x] Confirm category and payment-method add, rename, duplicate prevention, and in-use deletion protection.
- [x] Confirm currency remains fixed after restarting the app.
- [x] Confirm appearance and time-format preferences remain after restarting the app.
- [x] Confirm the recovery-passphrase screen can create a new passphrase for
  future backups on an already-open original device, and shows a success toast.

## Android backup and recovery check

This can be performed with two clean Android devices or profiles using the same
backup account. For development verification, Android's local backup transport
also permits a safe one-emulator test: create a backup, uninstall only iSpend,
then reinstall the same APK to trigger restoration.

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

### Verified development result — 9 September 2026

- [x] Release APK installed on Android emulator `emulator-5554`.
- [x] Local encrypted backup for `com.apps.ispend.v1` completed successfully.
- [x] After uninstall/reinstall, iSpend requested the recovery passphrase.
- [x] A wrong passphrase stayed on the restore screen and displayed an error.
- [x] The correct passphrase restored expenses, custom labels, Summary data,
  Appearance, and Time format.

## Publishing boundary

- [ ] A private Android upload-signing key is configured and stored outside the
  repository before any public distribution.
- [x] The final Phase 1 pull request is opened from `dev/Phase1_main` into

  `main` only after all relevant checks above pass.
