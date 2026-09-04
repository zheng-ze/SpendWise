# Settings UI

Last reconciled: 2026-09-02

## Feature overview

The Settings tab: category management (list, form, symbol picker), recurring-plan management (list,
form), and the Recycle Bin for restoring or purging archived rows. These are mostly stateless
facades over `Ledger`, with per-sheet `autoDispose` controllers for the forms.

## Key files

- `app/lib/ui/settings/settings_root_view_model.dart`, `settings_root_screen.dart`,
  `settings_flow.dart` — the root list of navigation links.
- `app/lib/ui/settings/category/` — category list, form, and the symbol picker.
- `app/lib/ui/settings/plan/` — plan list and form.
- `app/lib/ui/settings/recycle_bin/` — the recycle bin.
- `packages/domain/lib/src/ledger_state/ledger_state_categories.dart`, `ledger_state_plans.dart`
  — the domain mutators (see `ledger-and-money-model.md`, `recurring-plans-and-accounting.md`).


## Module interactions

The list providers read `Ledger` query methods (e.g. `categories(of:)` ordering per
`ledger_runtime.md` §1.3) and mutate through `Ledger`. Forms use per-sheet `autoDispose` controllers
seeded with the initial data. Delete copies (recycle-bin messaging) are derived from referencing
counts.

## Navigation

The Settings Flow owns this tab's nested navigator. Rows push the category/plan edit sheets and the
symbol picker; forms open as sheets via `FormScaffold`. The recycle bin lists archived items in
three sections (Accounts, Subpockets, Categories), each hidden when empty.

## Screens and flows

- **Category list** — two sections (Income, then Expense), rows pre-ordered roots-then-children
  A–Z, child rows indented. Edit/Done toggle shows red delete buttons; an add button opens "New
  Category" (default expense); parent rows show a `plus.circle` that opens "New Subcategory" with the
  parent preset (inherits kind + color). Tap → edit sheet. Delete message: "N transaction(s) will
  become Uncategorized." (singular/plural) when referenced, else "This category will be removed." →
  archive to bin.
- **Category form** — name, kind segmented (locked when a parent is preset or when a category any
  entry references, with a caption), icon row pushing the symbol picker, color picker, include-in-
  analysis toggle, parent picker (None + same-kind roots, excluding self). Defaults: symbol `tag`,
  blue color, include on. Save → add/update (color persisted as `#RRGGBB`). Editing only: a full-
  width destructive Delete Category → archive + dismiss, no confirmation (the list path is the
  confirmed one).
- **Symbol picker** — searchable sectioned grid (6 columns) of the `CategorySymbols` catalog,
  rendered as `CategoryIcon`s in the form's color; search filters names by substring, empty sections
  drop out, section headers are sticky.
- **Plan list** — rows sorted by next occurrence ascending, ended plans (nil next) last, with name
  as the deterministic tiebreak (including between two ended plans). Amount is green when the
  template amount is income, primary when expense. No add button — plans are created from the entry
  form's recurrence flow only. Delete message: "Already generated transactions are kept." →
  `deletePlan`.
- **Plan form** — name, amount magnitude (template's original sign preserved on save), read-only
  source line, Repeat row (`RecurrencePickerSheet` with non-optional binding — "One time" is ignored
  because a plan cannot become one-shot), first-date picker, end-date toggle + picker. Editing the
  anchor/frequency does not retro-generate or delete existing entries.
- **Recycle bin** — archived items in three sections; rows show name (pockets qualified as
  "Parent/Pocket") and a "N references" badge, sorted by name ascending. Leading swipe → Restore
  (silent no-op if the parent account is still binned — restore the account first); trailing swipe →
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

- Category list ordering is roots-then-children A–Z per kind.
- Plan list sorts by next occurrence ascending with ended plans last and name as tiebreak.
- Plan save preserves the template's original sign.
- Recycle bin restore on a pocket whose parent is still binned is a silent no-op.
- Delete copy pluralizes by referencing-entry count.
