# Phase 4d - Onboarding, Personalization & Help: Feature List & Test Cases

Traceable to "Phase 4d" in `expense-tracker-app-spec.md`. Code lives in
`lib/features/guides/`; automated coverage is `test/guides_test.dart`.
"Auto" means covered by that file; "Manual" must be checked on a device.

## Display name

- **TC-DN-1 (Auto):** A typed name is trimmed, internal whitespace and control
  characters collapse to single spaces, and it is cut to 30 characters. An
  empty or blank name is stored as "no name".
- **TC-DN-2:** The greeting on Expenses follows the time of day: Good morning
  (05:00-11:59), Good afternoon (12:00-17:59), Good evening (otherwise). With
  no name it is just that phrase; with a name it adds ", <name>". No
  placeholder text ever appears. (Auto for the wording and hour boundaries;
  Manual for the Expenses page.)
- **TC-DN-3 (Auto):** The name is saved in the encrypted `app_settings` table
  (`display_name`) and reloads after restart.
- **TC-DN-4 (Manual):** Settings > Personalization edits or clears the name and
  the greeting updates immediately. No saved expense changes.
- **TC-DN-5 (Manual):** A full encrypted backup restored on another install
  brings the name back (the whole `app_settings` table is backed up).

## Welcome guide

- **TC-WG-1 (Auto):** On a fresh install with no expenses, the welcome guide
  appears once, after passphrase setup and any app-lock prompt.
- **TC-WG-2 (Auto):** An install that already has expenses (for example after
  an update) is not shown it, and is recorded as done without any UI.
- **TC-WG-3 (Auto):** Skip works at any step; a name entered before skipping is
  still saved. The guide does not reappear on relaunch.
- **TC-WG-4 (Manual):** The guide covers only Expenses, Summary and Settings,
  and asks only the optional name (no email, phone, birthday or similar).
- **TC-WG-5 (Manual):** Help & Guide can replay the welcome guide at any time.

## Contextual guides

- **TC-CG-1 (Auto):** The first visit to a guided screen shows a card above the
  content; the content stays visible and usable.
- **TC-CG-2 (Auto):** **Got it** dismisses the card and records it; the content
  is unaffected.
- **TC-CG-3 (Manual):** Cards appear once on each of: Budget limits, Recurring
  expenses, Quick entry templates, Tags, Exchange rates, Export data, Backup,
  Receipt scan, Shopping orders. Reopening the screen shows no card.
- **TC-CG-4 (Manual):** The card is height-limited; with large text and a small
  screen the content below is still reachable by scrolling.
- **TC-CG-5 (Auto):** Raising a guide's `version` shows it again once; an
  unchanged guide is never shown again.

## Help & Guide and reset

- **TC-HG-1 (Manual):** Settings > About > Help & Guide lists every guide
  topic, readable at any time whether or not it was dismissed.
- **TC-HG-2 (Auto):** **Reset tutorials** (with confirmation) makes dismissed
  guides appear again but keeps the display name and the welcome-done state.
- **TC-HG-3 (Manual):** Reset deletes no expenses, settings or database data.

## Tutorial state, backup and privacy

- **TC-TS-1 (Auto):** Dismissed state is stored as versioned JSON under
  `tutorial_state` and survives a reload.
- **TC-TS-2 (Auto):** Corrupt saved state falls back to "nothing seen" without
  crashing.
- **TC-TS-3 (Manual):** The tutorial state is included in the encrypted backup
  and returns after restore.
- **TC-TS-4 (Manual):** No analytics or tracking SDK is added and no network
  call is made by onboarding, personalization or help.

## Definition of Done check (spec baseline)

- Encryption: both keys live in the SQLCipher `app_settings` table; no new
  table or column was added.
- Indexes: no new query pattern (single-key reads).
- Off-UI-thread / large data: not applicable; two small settings reads.
- Network: none introduced.
