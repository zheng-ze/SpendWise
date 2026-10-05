# Settings UI

Last reconciled: 0d906b7

## Feature overview

The Settings tab contains category management (list, form, symbol picker), recurring-plan management
(list, form), the Recycle Bin for archived rows, and Hosted Sync status, enrollment, and device-access
repair. The ledger screens are mostly stateless facades over `Ledger`, with per-sheet `autoDispose`
form controllers.

## Key files

- `app/lib/ui/settings/settings_root_view_model.dart`, `settings_root_screen.dart`,
  `settings_flow.dart` - the root list of navigation links.
- `app/lib/ui/settings/category/` - category list, form, and the symbol picker.
- `app/lib/ui/settings/plan/` - plan list and form.
- `app/lib/ui/settings/recycle_bin/` - the recycle bin.
- `app/lib/boot/providers.dart`, `app/lib/sync/hosted_sync_status.dart` - the Hosted Sync status
  provider and durable-metadata projection.
- `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` - fresh enrollment and
  repair presentation opened from Settings; see `sync-enrollment-flow.md`.
- `packages/domain/lib/src/ledger_state/ledger_state_categories.dart`, `ledger_state_plans.dart`
  - the domain mutators (see `ledger-and-money-model.md`, `recurring-plans-and-accounting.md`).
- `app/lib/settings/display_preferences.dart`,
  `app/lib/settings/display_preferences_store.dart`,
  `app/lib/settings/display_preferences_providers.dart` - the device-local
  display preferences model, store and providers.
- `app/lib/main.dart` - `main`, `loadInitialDisplayPreferences`, `SpendWiseApp`,
  `themeModeFor`.


## Module interactions

The list providers read `Ledger` query methods (e.g. `categories(of:)` ordering per
`ledger_runtime.md` §1.3) and mutate through `Ledger`. Forms use per-sheet `autoDispose` controllers
seeded with the initial data. Delete copies (recycle-bin messaging) are derived from referencing
counts.

## Navigation

The Settings Flow owns this tab's nested navigator. Rows push the category/plan edit sheets and the
symbol picker; forms open as sheets via `FormScaffold`. The recycle bin lists archived items in
three sections (Accounts, Subpockets, Categories), each hidden when empty.

## Hosted Sync

The Hosted Sync section watches `hostedSyncStatusProvider` and displays status text for
every `HostedSyncStatus`: not configured, setup pending, ready, binding repair needed, sign-in expired,
unsupported endpoint, or status unavailable. Binding repair explains that device access needs
authorization and reconciliation precedes resumed writes. Session reauth explains that the existing
device access is kept. Only those two repair statuses show `Repair Device Access`. Custom endpoints
show the sync protocol v2 unsupported notice; unavailable status shows a read-only failure message.

The `hostedSyncStatus` tile is tappable and shows a chevron only for `HostedSyncNoSelection` and
`HostedSyncSetupPending`. `SettingsRootNotifier.requestStartHostedEnrollment()` emits
`StartHostedEnrollmentRequested`; `_SettingsFlowState._openFreshFlow()` rechecks those statuses before
opening `SyncEnrollmentFlow(repairMode: false)`, whose root is the backend picker. Other statuses
keep the tile passive. Fresh and repair routes share `enrollmentFlowOpenProvider` to prevent
duplicate pushes across Settings Flow instances; only the instance that owns the route releases
the guard. Hosted Sync status refreshes when Settings becomes selected and after either route closes.
Source: `app/lib/ui/settings/settings_root_screen.dart` - `_HostedSyncSection`;
`app/lib/ui/settings/settings_root_view_model.dart` - `StartHostedEnrollmentRequested`;
`app/lib/ui/settings/settings_flow.dart` - `_openFreshFlow`, `_pushEnrollmentRoute`,
`_markEnrollmentRouteClosed`; `app/lib/ui/shell/shell_providers.dart`.

`SettingsRootNotifier.requestRepair()` emits the single-shot `RepairDeviceAccessRequested` navigation
step. The persistent shell repair banner also uses this seam; it appears for binding-repair and
session-reauth status and takes precedence over the timed plan/save message. Tapping it selects
Settings and requests repair only when `enrollmentFlowOpenProvider` is false. `SettingsFlow` opens
`SyncEnrollmentFlow(repairMode: true)` for the request and re-checks a pending step after its navigator
mounts, so a request made before Settings is built is consumed once. The banner hides while either
fresh enrollment or repair is open and Settings is selected. On another tab it returns; tapping it
exposes the existing route, preserving a fresh route awaiting binding authorization. Source:
`app/lib/ui/settings/settings_flow.dart`, `app/lib/ui/shell/status_banner.dart`,
`app/lib/ui/shell/shell_providers.dart`.

Across coexisting Settings Flows during an AppShell layout transition, the shared guard admits one
enrollment route. If its owning Flow is disposed, a microtask releases the guard and reads the cached
`hostedSyncStatusProvider`. For a fresh route, it emits `ResumeFreshEnrollmentRequested` unless the
status is `HostedSyncReady`; the surviving Flow pushes `SyncEnrollmentFlow(repairMode: false)` through
`_pushEnrollmentRoute`, bypassing the tile eligibility check. For a repair route, it requests repair
again only while the cached status is binding repair or session reauth. See `sync-enrollment-flow.md`
for enrollment behavior. Source: `app/lib/ui/settings/settings_flow.dart` -
`_handOverOpenEnrollmentRoute`, `handleStep`; `app/lib/ui/settings/settings_root_view_model.dart` -
`SettingsRootNotifier.requestResumeFreshEnrollment`.

## Display preferences

Appearance, the Overview widget order, the Trends breakdown choices, chart
colours, the insight switches, dismissed insights and the savings pocket id
persist device-locally in SharedPreferences under the `display.v1.*` keys and
never sync. `DisplayPreferences` is immutable with stable string codes, and
decoding is total: an unknown code falls back to its default, and unknown or
duplicate widget codes are dropped. An absent widget key loads the default
Today, Recent entries and Coming up set, while an empty value loads an empty
set. The snapshot loads before the first frame through
`initialDisplayPreferencesProvider`; a failed read boots with defaults.
`displayPreferencesProvider` updates state first and writes through, keeping
the in-memory value when a write fails. `MaterialApp.themeMode` follows the
stored appearance, so Dark overrides a light platform and System follows the
platform. The receipt scan-strip switch stays in `AppSettings`. Source:
`app/lib/settings/display_preferences.dart`,
`app/lib/settings/display_preferences_store.dart`,
`app/lib/settings/display_preferences_providers.dart`; `app/lib/main.dart` -
`main`, `loadInitialDisplayPreferences`, `SpendWiseApp`, `themeModeFor`;
`app/test/settings/display_preferences_store_test.dart`,
`app/test/settings/display_preferences_provider_test.dart`.

## Screens and flows

- **Category list** - two sections (Income, then Expense), rows pre-ordered roots-then-children
  A–Z, child rows indented. Edit/Done toggle shows red delete buttons; an add button opens "New
  Category" (default expense); parent rows show a `plus.circle` that opens "New Subcategory" with the
  parent preset (inherits kind + color). Tap → edit sheet. Delete message: "N transaction(s) will
  become Uncategorized." (singular/plural) when referenced, else "This category will be removed." →
  archive to bin.
- **Category form** - name, kind segmented (locked when a parent is preset or when a category any
  entry references, with a caption), icon row pushing the symbol picker, color picker, include-in-
  analysis toggle, parent picker (None + same-kind roots, excluding self). Defaults: symbol `tag`,
  blue color, include on. Save → add/update (color persisted as `#RRGGBB`). Editing only: a full-
  width destructive Delete Category → archive + dismiss, no confirmation (the list path is the
  confirmed one).
- **Symbol picker** - searchable sectioned grid (6 columns) of the `CategorySymbols` catalog,
  rendered as `CategoryIcon`s in the form's color; search filters names by substring, empty sections
  drop out, section headers are sticky.
- **Plan list** - rows sorted by next occurrence ascending, ended plans (nil next) last, with name
  as the deterministic tiebreak (including between two ended plans). Amount is green when the
  template amount is income, primary when expense. No add button - plans are created from the entry
  form's recurrence flow only. Delete message: "Already generated transactions are kept." →
  `deletePlan`.
- **Plan form** - name, amount magnitude (template's original sign preserved on save), read-only
  source line, Repeat row (`RecurrencePickerSheet` with non-optional binding - "One time" is ignored
  because a plan cannot become one-shot), first-date picker, end-date toggle + picker. Editing the
  anchor/frequency does not retro-generate or delete existing entries.
- **Recycle bin** - archived items in three sections; rows show name (pockets qualified as
  "Parent/Pocket") and a "N references" badge, sorted by name ascending. Leading swipe → Restore
  (silent no-op if the parent account is still binned - restore the account first); trailing swipe →
  purge confirmation ("\<name\> leaves the bin for good..."). Purge routing: money source →
  `purgeAccount`/`purgePocket`, category → `purgeCategory`.

## Gotchas and invariants

- Child-category restore is blocked while its parent is archived; pocket restore is blocked while its
  parent account is archived. `ledger-and-money-model.md` §Restore blocking.
- Plan delete is a hard delete with no recycle bin; the archive path applies only to money sources
  and categories. `recurring-plans-and-accounting.md`
- Category kind is locked while transactions reference it.
- Purge moves referenced rows to `referenceOnly` and unreferenced rows to tombstoned; the domain
  decides which. `ledger-and-money-model.md` §Purge.

## Requirements

- Display preferences persist under `display.v1.*` with stable codes and total
  decoding; a failed preload boots with defaults and a failed write keeps the
  in-memory value.
- Category list ordering is roots-then-children A–Z per kind.
- Plan list sorts by next occurrence ascending with ended plans last and name as tiebreak.
- Plan save preserves the template's original sign.
- Recycle bin restore on a pocket whose parent is still binned is a silent no-op.
- Delete copy pluralizes by referencing-entry count.
