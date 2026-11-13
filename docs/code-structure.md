# Code Structure Reference

Companion to `expense-tracker-app-spec.md`. Describes how the Flutter
codebase is organized — read this before writing or reviewing any code,
and update it if the actual structure diverges once building starts.

**Before making any decision not already settled here** — a folder/file
placement question, a naming choice, a technical tradeoff (e.g. which
Riverpod style to use) — ask CJ before deciding and moving on, rather
than picking silently. See the note at the top of
`expense-tracker-app-spec.md` for the full reasoning; it applies equally
here, including for AI coding agents (Codex, Antigravity, or otherwise)
working from this document.

---

## Development workflow

All implementation work starts from an up-to-date `main` branch. Create a
task branch named `dev/{name}`, make and test the change there, then commit
only after the relevant checks pass. Open a pull request from `dev/{name}`
to `main` for review and merge; do not make direct changes or commits to
`main`.

## Architecture approach

Feature-first, lightly layered within each feature. Deliberately avoids
heavy Clean Architecture (no 5-layer-per-feature setup) since this is a
solo, nights/weekends project — but keeps clear separation so the
codebase stays navigable as Phase 1.5, 2b, 3, and 4 get added on top of
Phase 1.

**State management: Riverpod, using manual providers (not code
generation).** The app is entirely local with no server/auth state, so
Riverpod's lighter footprint (versus Bloc) fits — less boilerplate,
straightforward testing, scales cleanly as more features are added
without needing a rewrite. For Phase 1, use **manually-written providers**
(`Provider`, `StateNotifierProvider`, etc.) rather than the code-generator
style (`@riverpod` annotations + build_runner) — less tooling overhead
(no build_runner watch process to keep running) and simpler to reason
about for a solo dev on an MVP. Revisit this choice if the provider count
grows large enough that generated boilerplate becomes clearly worth the
added tooling.

**Database layer: Repository pattern per feature.** Each feature owns a
repository class that is the *only* thing touching its raw database
tables. This matters concretely for:
- The encryption setup (SQLCipher / Android EncryptedSharedPreferences +
  Keystore) — one central, auditable place to apply it, per the spec's
  Security & Privacy Baseline
- The secure-delete/compact logic — same reasoning
- Backup/restore (Phase 1.5) — needs to enumerate and serialize every
  repository's data, which is straightforward if each repository is the
  single source of truth for its table(s)

**Database key + recovery passphrase (`recovery_key.dart`) — built in
Phase 1, not Phase 1.5.** The day-to-day SQLCipher key lives in the OS's
hardware-backed secure storage (iOS Keychain, `ThisDeviceOnly` protection
class; Android Keystore) — this is correct for normal use, but
`ThisDeviceOnly` Keychain items do not migrate to a new physical device
even via encrypted backup, so a plain export/import of the database file
would be unreadable on a different device. Since automatic device
backups are included by default from Phase 1 (per the Security & Privacy
Baseline), this envelope mechanism must exist from Phase 1 too — Phase
1.5 only adds the manual export/import UI on top of it, reusing the same
mechanism. `recovery_key.dart` is the one place that:
- Derives a wrapping key from the user's recovery passphrase (mandatory,
  set during first-run onboarding — the app cannot be used until this is
  set) using **Argon2id** — specifically chosen over PBKDF2, since
  Argon2id is memory-hard and resistant to GPU/ASIC-accelerated offline
  attacks, which matters for a key envelope that may sit inside a cloud
  backup indefinitely. Use parameters on the stronger end of current
  OWASP guidance: **`t=3, m=65536 (64 MiB), p=4`**. These are fixed
  requirements, not placeholders. If real-device testing identifies a
  performance concern, report it to CJ for an explicit decision; do not
  silently lower the parameters. A brief delay is acceptable here since
  this runs only at backup/restore, not on every app launch. Use a unique
  random salt (≥16 bytes) per passphrase, stored alongside the encrypted
  envelope.
- Wraps a recoverable copy of the real SQLCipher key with that derived
  key, and includes only the *wrapped* copy in the device backup /
  exported backup file — never the raw key, and never the passphrase
  itself
- On restore, prompts for the passphrase, derives the same wrapping key,
  and unwraps the real SQLCipher key to open the restored database
- Is never called during normal app launch/use — only during onboarding
  (setting the passphrase) and the backup-export/backup-restore flows —
  so daily use stays exactly as fast and seamless as the rest of the app
- **Has no recovery path if the passphrase is forgotten, by design.**
  There is no reset/bypass — this is the only honest option for a
  passphrase whose entire purpose is protecting a key that shouldn't be
  recoverable any other way. Surface a clear, calm (not alarming)
  explanation of this during onboarding.

---

## Folder layout

```
lib/
├── main.dart                     # Entry point
├── app.dart                      # Root widget, theme wiring, routing
│
├── core/                         # Shared across all features
│   ├── database/
│   │   ├── database.dart         # DB init, encryption setup
│   │   ├── recovery_key.dart      # Recovery-passphrase wrap/unwrap logic
│   │   └── migrations/          # Versioned schema migrations
│   ├── theme/
│   │   ├── app_theme.dart        # Light/dark ThemeData, follows system
│   │   ├── colors.dart           # Category/payment-method color mapping
│   │   └── typography.dart       # Enforces "data clarity first" principle
│   ├── widgets/                  # Shared, reusable widgets only
│   │   ├── icon_registry.dart    # Category/payment method → icon + color
│   │   ├── amount_text.dart      # Consistent number formatting everywhere
│   │   └── category_badge.dart   # The rounded icon-in-color-square widget
│   └── utils/
│       ├── currency_formatter.dart
│       └── date_helpers.dart     # "today / this week / this month" logic
│
├── features/                     # One folder per feature area
│   ├── expenses/
│   │   ├── data/
│   │   │   ├── expense_repository.dart
│   │   │   └── expense_model.dart
│   │   ├── presentation/
│   │   │   ├── expense_list_page.dart
│   │   │   ├── expense_entry_sheet.dart
│   │   │   └── widgets/
│   │   │       └── expense_row.dart
│   │   └── expense_providers.dart
│   │
│   ├── categories/
│   │   ├── data/
│   │   │   ├── category_repository.dart
│   │   │   └── category_model.dart
│   │   ├── presentation/
│   │   │   └── category_management_page.dart
│   │   └── category_providers.dart
│   │
│   ├── payment_methods/
│   │   ├── data/
│   │   │   ├── payment_method_repository.dart
│   │   │   ├── payment_method_model.dart
│   │   │   └── payment_method_presets.dart   # Malaysia preset list + icons
│   │   ├── presentation/
│   │   │   └── payment_method_management_page.dart
│   │   └── payment_method_providers.dart
│   │
│   └── summary/                   # The Summary page feature
│       ├── data/
│       │   └── summary_repository.dart       # Aggregation queries
│       └── presentation/
│           └── summary_page.dart
│
│   # Added after Phase 1 (each follows the same data/ + presentation/ shape):
│   ├── budgets/  backup/  security/  settings/   # Phase 1.5 (app lock in security/)
│   ├── quick_entry/                               # Phase 2b templates + bridges
│   ├── ocr_import/  statement_import/             # Phase 3 / 3b
│   ├── export/  reports/  tags/  exchange_rates/  # Phase 4a
│   ├── onboarding/                                # First-run passphrase/currency setup
│   └── guides/                                    # Phase 4d (see below)
│
└── (no lib/platform/ folder yet)
```

Native Android code (widget provider, Quick Settings tile, `MainActivity`)
lives under `android/app/src/main/kotlin/com/apps/ispend/v1/`, not in `lib/`.
The Phase 2 iOS native track has not started. `core/` currently holds
`database/`, `theme/` (`app_theme.dart`, `app_tokens.dart`), `utils/` (amount
and currency helpers) and `widgets/` (`icon_registry.dart`, `app_surface.dart`,
`app_toast.dart`); the original tree above is the Phase 1 plan and the code
is the source of truth where they differ.

---

## Phase-to-folder mapping

Keeps the codebase traceable against the spec and the test case document —
"where's the code for feature X" should always have one obvious answer.

| Spec phase | Folders involved |
|---|---|
| Phase 1 | `features/expenses`, `features/categories`, `features/payment_methods`, `features/summary`, `core/*` |
| Phase 1.5 | Adds to `expenses` (recurring), a new `features/budgets/`, a new `features/backup/` |
| Phase 2b | `features/quick_entry/` owns the shared encrypted quick-entry template model, repository, providers, Settings management UI, Home Widget bridge, and Android App Shortcut bridge. The Android bridge asks `ShortcutManager` for the launcher-supported limit, reserves one action for Add Expense, and fills remaining slots with favourite templates identified by stable IDs. Stable category/payment-method IDs in `core/database/`, `features/categories/`, `features/payment_methods/`, `features/expenses/`, and `features/budgets/` remain the relationship foundation. |
| Phase 2 (on hold) | `platform/ios_native/` — stays empty until Mac access exists |
| Phase 3 / 3b | Built as `features/ocr_import/` (receipt and shopping-order OCR, retained images) and `features/statement_import/` (PDF statements) |
| Phase 4a | `features/export/` (CSV), `features/reports/` (monthly report), `features/tags/`, `features/exchange_rates/` (multi-currency rates) |
| Phase 4b/4c (not started) | Planned `features/settle/`, `features/loans/` — 4b and 4c share a `core/balance_tracking/` concept per the spec's note that both should reuse one underlying model |
| Phase 4d | `features/guides/` — welcome flow, contextual guides, Help & Guide, Personalization |
| Phase 4e (not started) | Split bill; depends on the 4b balance ledger |

---

### Phase 1.5 recurring data ownership

- `recurring_expenses` stores one monthly schedule/rule, including its next
  occurrence and active state.
- `expenses.recurring_rule_id` links the original and generated normal expenses
  to that schedule.
- `expenses.recurring_occurrence_millis` records the scheduled date separately
  from the user-editable transaction date and participates in a unique index
  with the rule ID.
- Recurring confirmation is owned by `RecurringExpenseRepository` so inserting
  the occurrence and advancing the schedule happen atomically and defensively.
- `merchant_or_note`, `category`, and `payment_method` are intentionally
  denormalized for list rendering but are shared recurring-series fields.
  `RecurringExpenseRepository` owns their transactional synchronization across
  the schedule and every expense carrying that `recurring_rule_id`; future
  drafts read the synchronized schedule values.
- Stopping sets `recurring_expenses.is_active` to false instead of deleting the
  rule. Reactivation sets it back to true with a user-selected next occurrence
  date, retaining the same rule ID and linked expense history.

### Phase 1.5 budget data ownership

- `SettingsBudgetLimitRepository` stores monthly category limits as a versioned
  JSON value in encrypted `app_settings`; manual backup already carries this
  table in full.
- Budget limits use integer cents and are keyed by category name. Category
  rename/delete calls update/remove the matching limit to prevent stale keys.

### Phase 1.5 app-lock ownership

- `AppLockEnabledNotifier` stores the opt-in boolean in encrypted
  `app_settings`; backup/restore refreshes it with other settings.
- `AppLockGate` wraps only the normal post-onboarding app shell. It delegates
  biometric/device-credential prompting to `AppLockAuthenticator` and relocks
  after the app enters the background.

### Phase 4d guides ownership

- `features/guides/data/guide_catalog.dart` is the single list of guide topics
  (`GuideIds`, `guideTopics`). Each topic has a stable `id` and a `version`;
  raising the version shows a redesigned guide once more.
- `guide_providers.dart` holds `DisplayNameNotifier` (`display_name`) and
  `TutorialNotifier` (`tutorial_state`, versioned JSON). Both persist in
  encrypted `app_settings`, so the existing backup carries them with no new
  table. Corrupt tutorial state falls back to "unseen".
- `GuidedBody` / `ContextualGuide` wrap a feature page with its one-time card
  using a `GuideIds` value; `WelcomeGate` in `welcome_flow.dart` wraps the
  normal shell and skips (and records) the welcome for installs that already
  have expenses.
- A new feature screen adds its guide by adding a `GuideTopic` and wrapping
  its page in `GuidedBody`; Help & Guide lists the catalog automatically.
- Test cases: `phase4d-features-and-test-cases.md`; automated tests:
  `test/guides_test.dart`.

---

## Naming and consistency rules

- **One repository per feature, never shared.** If two features need the
  same data, one calls the other's repository — don't reach into another
  feature's raw tables directly.
- **`icon_registry.dart` is the single source of truth** for every
  category and payment method icon (including the per-provider icons for
  Maybank, CIMB, Touch 'n Go, GrabPay, etc.). No icon logic duplicated
  inline elsewhere — this is what makes the icon test cases (TC-3.9,
  TC-3.10 in the test document) straightforward to verify by inspection.
- **No feature folder reaches into `platform/`** except the specific
  feature it's extending (e.g. `platform/android/quick_actions_bridge.dart`
  calls into `features/expenses/expense_providers.dart` to log a quick
  expense — not the reverse).
- **Every new feature folder gets a matching entry** in
  `phase1-features-and-test-cases.md` (or its Phase 1.5/2b/3/4
  equivalent, once those documents exist) — code and test cases should
  stay traceable to each other as the app grows.

---

## Open items to confirm once building starts

- Whether `core/balance_tracking/` (shared between Phase 4b Settle and
  4c Loans) gets built when 4b starts, or scaffolded early and left
  mostly empty until 4c — reasonable to decide when actually reaching
  Phase 4b, not now.
