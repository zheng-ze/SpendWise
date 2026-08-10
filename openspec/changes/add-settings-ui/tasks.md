Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §5, which is more detailed than the
specs in this change.

Depends on `add-app-shell-and-boot` for the form scaffold, category chip, pickers and formatting, and
on `add-transactions-ui` for the recurrence picker the plan form reuses.

## 1. Settings root

- [ ] 1.1 Add the root: a grouped list linking to Categories and Recurring Plans, then a second group
      linking to the Recycle Bin
- [ ] 1.2 Test: each link pushes its screen

## 2. Category list

- [ ] 2.1 Add the list with Income then Expense sections, rows pre-ordered from `categories(of:)` —
      roots alphabetically, each followed by its own children alphabetically, children indented
- [ ] 2.2 Per-section empty text when a section has no categories
- [ ] 2.3 Row: category chip, name, and a marker when the category is excluded from analysis
- [ ] 2.4 Parent rows outside edit mode offer subcategory creation with the parent preset, inheriting
      its kind and color
- [ ] 2.5 Add the Edit/Done toggle revealing delete buttons, plus an add button defaulting to expense
- [ ] 2.6 Delete by button or swipe, behind a confirmation stating how many entries will become
      uncategorized when any reference it, else that the category will be removed. Handle singular and
      plural. Delete archives to the bin
- [ ] 2.7 Test: ordering including indentation; the exclusion marker; the delete copy in both the
      referenced and unreferenced cases, singular and plural

## 3. Category form

- [ ] 3.1 Add the sheet with titles for new, new-subcategory and edit
- [ ] 3.2 Add name, and the kind segmented control LOCKED when the parent is preset or when any entry
      references the category being edited, with the reason shown to the user
- [ ] 3.3 Changing kind clears a parent selection that no longer matches
- [ ] 3.4 Add the symbol row opening the picker, the color picker without opacity, the analysis toggle,
      and the parent picker offering none plus same-kind roots excluding self — hidden when the parent
      is preset or nothing is eligible
- [ ] 3.5 Defaults for a new category: tag symbol, default or parent's color, analysis included
- [ ] 3.6 `canSave` is a non-blank trimmed name. Save persists the color as `#RRGGBB`; errors surface
      inline
- [ ] 3.7 Editing offers a full-width delete that archives and dismisses with NO confirmation — the
      list path is the confirmed one (V1 parity)
- [ ] 3.8 Test: the kind-lock predicate in both locking cases; the parent picker excluding self;
      kind change clearing a mismatched parent

## 4. Symbol picker

- [ ] 4.1 Add the pushed picker: a sectioned six-column grid over the catalog, rendered in the form's
      current color, marking the current selection with the inverted chip
- [ ] 4.2 Search filters by case-insensitive trimmed substring on the symbol name; sections with no
      matches drop out; section headers stay pinned
- [ ] 4.3 Tapping writes the selection and pops
- [ ] 4.4 Test: search filtering including a term matching only some sections

## 5. Plan list

- [ ] 5.1 Add `sortedPlans(plans, state, now)` as a pure function: ascending by next occurrence, plans
      with no next occurrence last, name as the tiebreak in BOTH cases — V1 left equal non-null dates
      unspecified (`design.md`, flagged strengthening)
- [ ] 5.2 Row: name, a caption of frequency and source name, a tertiary caption of the next occurrence
      or "Ended", and the trailing amount as a magnitude colored to distinguish income from expense
- [ ] 5.3 Edit/Done toggle shown only when the list is non-empty; empty text otherwise
- [ ] 5.4 Add NO creation affordance — plans come from the entry form's recurrence flow only
      (`design.md`)
- [ ] 5.5 Delete by button or swipe behind a confirmation stating that already-generated transactions
      are kept, then `deletePlan`
- [ ] 5.6 Test the sort matrix: ended plans last, the name tiebreak in both branches

## 6. Plan form

- [ ] 6.1 Add the edit sheet: name, amount as a magnitude, and the source shown READ-ONLY
- [ ] 6.2 Preserve the template's original sign on save — an expense plan stays an expense
      (`design.md`)
- [ ] 6.3 Add the repeat row reusing the recurrence picker with a non-optional binding, where choosing
      one-time is ignored; a first-date picker; and an end-date toggle and picker with no lower bound
- [ ] 6.4 `canSave`: non-zero amount and non-blank name. Save via `updatePlan`; errors inline
- [ ] 6.5 Editing the anchor or frequency does not retro-generate or delete existing entries
- [ ] 6.6 Test: sign preservation across an amount edit — this is the test that catches a plan silently
      changing kind

## 7. Recycle bin

- [ ] 7.1 Add the three sections — accounts, subpockets, categories — each hidden when empty, with a
      whole-screen empty message
- [ ] 7.2 Rows sorted by name within each section, showing the glyph or category chip, the name, and a
      trailing reference count. Pockets show their qualified name when the parent still resolves
- [ ] 7.3 Leading swipe restores. A pocket whose parent is still archived is a silent no-op — a domain
      rule, kept faithfully. Improving the affordance is Phase 6 work (`design.md`)
- [ ] 7.4 Trailing swipe purges behind a confirmation naming the row and explaining that existing
      transactions keep the name but it can no longer be restored. Include the space V1's interpolation
      swallowed
- [ ] 7.5 Route purge by row kind: money source to the account or pocket purge, category to the category
      purge
- [ ] 7.6 Test: section membership and reference counts; purge routing per kind; the pocket restore
      no-op

## 8. Close-out

- [ ] 8.1 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors
- [ ] 8.2 Confirm no `double` money reached `app/lib/`
- [ ] 8.3 Confirm the derivation functions carry no widget imports
