# Settings UI

Last reconciled: 2026-11-28

## Feature overview

Settings contains category management (list, form sheet, icon and colour picker), the Recycle Bin for
archived rows, and the "Import from Money Manager" row (see `money-manager-import.md`). Recurring-plan management lives
in the Money Plans segment; its list, detail, form and pane modules live under `app/lib/ui/plans/`,
not under Settings. The ledger
screens are mostly stateless facades over `Ledger`, with per-sheet form view models keyed by their arguments.

## Key files

- `app/lib/ui/settings/settings_root_view_model.dart`, `settings_root_screen.dart`,
  `settings_flow.dart` - the root list of navigation links.
- `app/lib/ui/common/navigation/page_header.dart` - the shared large-title page header. It takes an
  optional back callback, a disabled-back flag, a subtitle and a trailing action, draws its title in
  the headline style's own medium weight, and every screen with a back control uses it, including
  the Settings root, the Categories list and the Recycle bin.
- `app/lib/ui/settings/import_errors_sheet.dart`, `import_error_text.dart` - the import errors sheet and
  the outcome-to-message mapping; `app/lib/import/import_file_picker_service.dart` - the `ImportFilePicker`
  seam the Flow reads.
- `app/lib/ui/settings/category/` - category list, form sheet, subcategories section and parent picker.
- `app/lib/ui/common/pickers/symbol_picker.dart`, `app/lib/ui/theme/category_palette.dart` - the icon and
  colour picker and the saved-colour mapping.
- `app/lib/ui/shell/shell_confirmation.dart`, `app/lib/ui/common/feedback/destructive_confirmation.dart`
  - the shared confirmation dialog route and its content.
- `app/lib/ui/settings/recycle_bin/` - the recycle bin.
- `packages/domain/lib/src/ledger_state/mutators/ledger_state_categories.dart`, `ledger_state_plans.dart`
  - the domain mutators (see `ledger-and-money-model.md`, `recurring-plans-and-accounting.md`).
- `app/lib/settings/display_preferences.dart`,
  `app/lib/settings/display_preferences_store.dart`,
  `app/lib/settings/display_preferences_providers.dart` - the device-local
  display preferences model, store and providers.
- `app/lib/main.dart` - `main`, `loadInitialDisplayPreferences`, `SpendWiseApp`,
  `themeModeFor`.


## Module interactions

The category list and recycle bin view models (`categoryListViewModelProvider`,
`recycleBinViewModelProvider`) are `autoDispose` providers scoped to their mounted view. Each computes
its state synchronously from `LedgerState` (e.g. `categories(of:)` ordering per `ledger_runtime.md` §1.3),
listens to the ledger itself with the listener removed in `onDispose`, carries UI-only state (the
pending step) across ledger changes through its previous `state.value`, and mutates through `Ledger`.
They have no loading state; a failed build ends in `AsyncError` and shows an error state. The category
form uses an `autoDispose` view-model family keyed by its arguments (`categoryFormViewModelProvider`),
seeded with the initial data. It listens to the ledger and refreshes its category snapshot on every
change. The plan list, detail and form view models live with
the Plans segment (see `accounts-ui.md`). Delete copies (recycle-bin messaging) are derived from referencing
counts. These counts include active and binned entries through `entriesReferencing`,
`entryCount` and `entryCountReferencing`
(`packages/domain/lib/src/ledger_state/queries/ledger_state_queries.dart`).

## Navigation

The Settings Flow owns Settings' nested navigator; `AppShell` mounts it only while the
`settings` destination is selected (see `ui-framework-mvvm.md`). The root screen shows the large "Settings" title with no
back control. The Categories list and the Recycle bin use the same `PageHeader` (no AppBar) with
Flutter's icon-only `BackButton` (accessible name "Back") that pops the route. Back pops child routes and preserves the destination selection at the root. Selecting another destination disposes the flow and its child routes, and
selecting Settings again builds it fresh at the root. The Categories row opens category management, whose forms open as AppSheets over it. Settings has no Recurring Plans row, request Step or Plans route.
`MoneyFlow` hosts the Plans segment through `PlansFlow`; the Money header has no Plans action, and
plan forms open as AppSheets (`app/lib/ui/plans/plan_form/plan_form.dart`).
(`app/lib/ui/settings/settings_root_screen.dart`, `settings_root_view_model.dart`,
`settings_flow.dart`, `app/lib/ui/money/money_flow.dart`)

The recycle bin lists binned items in four titled cards (Entries, Accounts, Pockets, Categories), each hidden when empty.

## Display preferences

Appearance, the Overview widget order, the Trends breakdown choices, chart
colours and the savings pocket id
persist in SharedPreferences under the `display.v1.*` keys and stay device-local.
`DisplayPreferences` is immutable with stable string codes, and
decoding is total: an unknown code falls back to its default, and unknown or
duplicate widget codes are dropped. An absent widget key loads the eight-kind
default (`DisplayPreferences.defaults.overviewWidgets`: Today, This month,
Recent entries, Card statement, Coming up, Budget watch, Insights and Week so far), while an empty value loads an empty list. The
store does not replace that empty list at load. Overview and the Edit Overview
sheet treat any stored list with no card kind (an empty list, or one holding
only kinds without a card) as the defaults, through `overviewWidgetsOrDefault`
in `app/lib/ui/overview/overview_slots.dart`. The snapshot loads before the
first frame through
`initialDisplayPreferencesProvider`; a failed read boots with defaults.
`displayPreferencesProvider` updates state first and writes through, keeping
the in-memory value when a write fails. The Edit Overview sheet, opened from the
Overview header (`app/lib/ui/overview/overview_edit_sheet.dart`), is the writer
of `overviewWidgets`: its Done calls `displayPreferencesProvider.replace` and is
disabled while no card is shown, while drag-down, tap-outside and system back
dismissal write nothing. `MaterialApp.themeMode` follows the
stored appearance, so Dark overrides a light platform and System follows the
platform. The receipt scan-strip switch stays in `AppSettings`. Source:
`app/lib/settings/display_preferences.dart`,
`app/lib/settings/display_preferences_store.dart`,
`app/lib/settings/display_preferences_providers.dart`; `app/lib/main.dart` -
`main`, `loadInitialDisplayPreferences`, `SpendWiseApp`, `themeModeFor`;
`app/test/settings/display_preferences_store_test.dart`,
`app/test/settings/display_preferences_provider_test.dart`.

## Screens and flows

- **Import from Money Manager** - the first row of the Data section, above Recycle Bin: an upload icon,
  the title "Import from Money Manager" and the subtitle "Replaces all ledger data". It is disabled
  unless `importStatus` is `idle` and shows an `InlineSpinner` while `running`. `SettingsRootViewState`
  carries `importStatus` (`idle`, `picking`, `confirming`, `running`) and `importErrors`. The
  notifier emits `ImportFileRequested`, `ImportConfirmationRequested` and `ImportErrorsRequested`;
  `SettingsFlow` performs each (the file picker, `showDestructiveConfirmation`, and the
  `AppSheet` errors sheet) and reports the raw result back through `applyPickedFile`,
  `applyImportConfirmed` and `dismissImportErrors`. The notifier takes `ref.keepAlive()` for the run
  and holds it until the errors are dismissed, and `SettingsFlow.initState` schedules a post-frame
  `_handleHeldStep` that shows a step still held by the kept-alive notifier. The pipeline and
  persistence behavior are in `money-manager-import.md`.
  (`settings_root_screen.dart`: `_ImportRow`; `settings_root_view_model.dart`; `settings_flow.dart`)
- **Currency** - a fixed row reading "Amounts display in Singapore dollars / SGD". There is no
  multi-currency support. (`app/lib/ui/settings/settings_root_screen.dart`)

- **Category list** - two sections, Expense first and then Income, each a `Tray` card with a `SectionLabel` heading,
  `EdgeDivider` lines between rows, and the empty text "No categories yet". Rows are pre-ordered roots-then-children A-Z. Each row
  is a `MedallionRow` with the category medallion in its saved colour, the name, a chevron, and a
  "N subcategories" meta line ("1 subcategory" for one, none for zero). Child rows are indented 36.
  A bar-chart badge marks a category excluded from analysis. Root rows carry an "Add subcategory"
  action that opens the Add subcategory form with that root preset. A floating "Add category" button
  opens the Add category form. Tapping a row opens its edit form, and a swipe confirms and then moves
  the category to the bin. (`app/lib/ui/settings/category/category_list_screen.dart`)
- **Category form** - an `AppSheet` (loading and load-error states come from the shared
  `FormSheetAsyncHost`, and its Steps from the `StepListeningState` mixin) that dismisses by dragging down or tapping outside, with no Cancel
  button and a header Save action. Add category also has a "Save category" footer; Add subcategory and
  Edit have the header Save only. A failed save shows an error alert slot above the body. The title is
  Add category, Add subcategory, Edit category or Edit subcategory. The body holds the kind
  segmented control (hidden when the kind is locked), the name, an optional "Inside" parent row and an
  "Icon and colour" row that opens the picker. On Add, "More options" is collapsed and holds the
  "Count in Trends and budgets" switch. On Edit, "More options" is always open and also shows a
  read-only Type row with a lock. The Type hint reads "The type is fixed once entries use this
  category." for a root and "Set by \<parent>" for a subcategory; the Count hint "Include this
  subcategory in totals" shows on subcategories. On an edit form both hints follow the stored parent,
  not the draft pick, so re-parenting a subcategory in the Inside row leaves the hint reading "Set by
  \<stored parent>" until the save. Defaults: symbol `tag`, blue, include on; the colour is saved as
  `#RRGGBB`. A malformed stored colour is treated as unsaved, so the form seeds the same blue default
  as a new category (or the preset parent's colour) instead of the housing grey. Edit forms end with a body "Move to recycle bin" destructive `SecondaryButton` (the former `CategoryDangerButton` was removed) that confirms
  through the shared destructive dialog, then archives and dismisses.
  (`app/lib/ui/settings/category/category_form.dart`, `category_form_fields.dart`,
  `category_form_state.dart`)
- **Category form parent rules** - the kind is locked on every edit, when a parent is preset, and
  when active or binned entries reference the category. The parent picker ("Inside which category?",
  Top level first) lists active roots of the same kind, excluding the edited category, and is hidden
  when none exist or when the edited root already has children. A preset parent shows a read-only
  Inside row. The form's ledger listener clears a newly picked draft parent when it is binned or the edited
  root gains a child, and keeps the edited subcategory's unchanged stored parent even when it is
  binned. Known limitation: if a preset parent is binned elsewhere while an Add
  subcategory form is open, Inside shows Top level but save still files the category under the binned
  parent. (`category_form_state.dart`: `eligibleParents`, `hasStaleParent`;
  `category_form_view_model.dart`: `_onLedgerChanged`)
- **Edit category Subcategories section** - an edit form for a root lists its active subcategories A-Z
  with an "Add subcategory" action. Tapping a row or the action opens the subcategory form as a second
  sheet stacked over the edit form, so unsaved parent edits remain. Only one stacked form opens at a
  time. The whole section, including "Add subcategory", hides while a draft parent is set and returns
  when the Inside row is set back to Top level. Closing the parent form also dismisses the stacked
  subcategory sheet. (`category_subcategories_section.dart`, `category_form.dart`: `_openSubcategoryForm`)
- **Icon and colour picker** - one sheet titled "Icon and colour" with a header Done action. A preview
  row shows the medallion and the category name (the icon name when the name is empty), then one flat
  6-column icon grid with no search and no sections, then 32px colour swatches with a check ring. The
  choice is a draft that the form applies on Done. `CategoryPalette.savedColor` maps the purple
  swatch (#AF52DE) to the fitness colour and an explicitly saved grey swatch (#8E8E93) to the housing
  colour. A null or malformed saved colour keeps the neutral fallback grey (`colorHexFallback`,
  clamped for the theme) in charts and rows, so those rows do not show the housing slate.
  (`app/lib/ui/common/pickers/symbol_picker.dart`, `app/lib/ui/theme/category_palette.dart`,
  `app/lib/ui/format/color_hex.dart`)
- **Plans** - the Money Plans list, detail, edit form and delete are no longer part of Settings. They
  live in `app/lib/ui/plans/`; see `accounts-ui.md` (Plans segment) and
  `recurring-plans-and-accounting.md` (Plan UI). Editing the anchor or frequency does not
  retro-generate or delete existing entries.
- **Recycle bin Entries section** - first section, built from `LedgerState.binnedEntries` by
  `RecycleBinViewModel` as `BinEntryRow`s, newest date first, with no filter. A row shows the entry
  name (the category title when the name is empty), "d MMM yyyy / \<source name\>" (transfers show
  "source > destination"), the category medallion and the kind-styled signed amount, all derived
  through `transactionRow`. The Restore text and a leading swipe call `restoreEntry` with no
  confirmation; a trailing swipe shows the shared purge confirmation, then `purgeEntry`.
- **Recycle bin** - archived items in the Accounts, Pockets and Categories cards below the Entries card.
  Cards without rows are hidden. Rows show the name (pockets use the qualified source name), a
  "Used by N entries" meta line ("Used by 1 entry" for one) and a Restore action, sorted by name
  ascending. Category rows show their medallion. A footer hint reads "Swipe right to restore or left to
  delete permanently." When every card is empty the screen shows the shared `EmptyState` titled "Recycle bin is empty" and no hint. Leading swipe → Restore
  (silent no-op if the parent account is still binned - restore the account first); trailing swipe →
  purge confirmation ("\<name\> leaves the bin for good..."), which `confirmBinPurge` builds and presents
  through the shared `showDestructiveConfirmation`, a centered dialog with Cancel and a confirm action,
  at most 360 wide, shown by `showShellConfirmation` with a dimming scrim, tap-outside dismissal and a
  260 ms fade and slide-up entrance. The purge runs only after that dialog has finished
  closing (`app/lib/ui/settings/recycle_bin/recycle_bin_purge_dialog.dart`). Purge routing: money source →
  `purgeAccount`/`purgePocket`, category → `purgeCategory`.

## Gotchas and invariants

- Child-category restore is blocked while its parent is archived; pocket restore is blocked while its
  parent account is archived. `ledger-and-money-model.md` §Restore blocking.
- Plan delete is a hard delete with no recycle bin. The Settings recycle bin displays entries, money
  sources and categories (`app/lib/ui/settings/recycle_bin/recycle_bin_view_model.dart`).
- Entry rows reuse the swipe, semantics and purge-confirmation path of the other rows, so the
  purge dialog names the entry. Binned entries still count in the other rows' reference labels.
- Category kind is locked while active or binned entries reference it
  (`app/lib/ui/settings/category/category_form_view_model.dart`: `_isReferenced`;
  `packages/domain/lib/src/ledger_state/queries/ledger_state_queries.dart`: `entryCountReferencing`).
- A successful import shows no message and keeps display preferences: the import writes only ledger
  rows (`money-manager-import.md`), and `SettingsRootNotifier.applyImportConfirmed` stores errors only.
- Purge moves referenced rows to `referenceOnly` and unreferenced rows to tombstoned; the domain
  decides which. `ledger-and-money-model.md` §Purge.

## Requirements

- Display preferences persist under `display.v1.*` with stable codes and total
  decoding; a failed preload boots with defaults and a failed write keeps the
  in-memory value.
- Category list ordering is roots-then-children A–Z per kind, with Expense before Income.
- Category forms are AppSheets with no Cancel, keep unsaved parent edits under a stacked subcategory
  form, and lock the kind on edit.
- Plan list sorts by next occurrence ascending with ended plans last and name as tiebreak.
- Plan save preserves the template's original sign.
- The Entries section lists binned entries newest first, hides when none are binned, restores
  without confirmation and purges only after confirmation.
- The import row ignores taps unless the status is `idle`, so a second tap during a pending pick never
  reaches the picker. (`SettingsRootNotifier.requestImport`)
- Recycle bin restore on a pocket whose parent is still binned is a silent no-op.
- Delete copy pluralizes by referencing-entry count.
