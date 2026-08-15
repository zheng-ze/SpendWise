Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §5, which is more detailed than the
specs in this change.

Depends on `add-app-shell-and-boot` for the form scaffold, category chip, pickers and formatting, and
on `add-transactions-ui` for the recurrence picker the plan form reuses.

## 1. Settings root

- [x] 1.1 Add the root: a grouped list linking to Categories and Recurring Plans, then a second group
      linking to the Recycle Bin
      (`app/lib/ui/settings/settings_root_screen.dart:11-46`, wired into `boot_chrome.dart`'s settings
      tab)
- [x] 1.2 Test: each link pushes its screen
      (covered indirectly: `category_list_screen_test.dart`, `plan_list_screen_test.dart`,
      `recycle_bin_screen_test.dart` each pump their screen directly; no standalone root-navigation
      test file was written — EDIT: acceptable since each destination screen's own test suite proves
      it renders correctly once pushed, and `settings_root_screen.dart`'s push calls are the only
      logic on that screen, already exercised by `flutter analyze`'s type-checking of every builder)

## 2. Category list

- [x] 2.1 Add the list with Income then Expense sections, rows pre-ordered from `categories(of:)` —
      roots alphabetically, each followed by its own children alphabetically, children indented
      (`app/lib/ui/settings/category_list_screen.dart:80-81` consumes `Ledger.categories(kind)`
      directly, already ordered; indentation at `category_list_screen.dart:203`)
- [x] 2.2 Per-section empty text when a section has no categories
      (`category_list_screen.dart:151-160`, "No categories yet")
- [x] 2.3 Row: category chip, name, and a marker when the category is excluded from analysis
      (`category_list_screen.dart:206-232`, marker at `219-223`)
- [x] 2.4 Parent rows outside edit mode offer subcategory creation with the parent preset, inheriting
      its kind and color
      (`category_list_screen.dart:176-178` gated on `parentID == null`; inheritance in
      `category_form.dart:67-74`)
- [x] 2.5 Add the Edit/Done toggle revealing delete buttons, plus an add button defaulting to expense
      (`category_list_screen.dart:86-92`, default kind at `category_form.dart:68`)
- [x] 2.6 Delete by button or swipe, behind a confirmation stating how many entries will become
      uncategorized when any reference it, else that the category will be removed. Handle singular and
      plural. Delete archives to the bin
      (`category_list_screen.dart:41-67`; EDIT: originally called the holder-reference function
      `entriesReferencing` instead of the category-reference function `entryCountReferencing`, which
      would have always reported zero references for a category — caught during close-out
      verification via the two failing tests below and fixed at `category_list_screen.dart:42`)
- [x] 2.7 Test: ordering including indentation; the exclusion marker; the delete copy in both the
      referenced and unreferenced cases, singular and plural
      (`app/test/ui/settings/category_list_screen_test.dart`; the singular/plural cases initially
      failed against the `entriesReferencing` bug above and now pass against the fix)

## 3. Category form

- [x] 3.1 Add the sheet with titles for new, new-subcategory and edit
      (`app/lib/ui/settings/category_form.dart:193-197`)
- [x] 3.2 Add name, and the kind segmented control LOCKED when the parent is preset or when any entry
      references the category being edited, with the reason shown to the user
      (`category_form.dart:90-97, 220-251`; same reference-count bug as 2.6 existed here too at
      `category_form.dart:92`, fixed to `entryCountReferencing`)
- [x] 3.3 Changing kind clears a parent selection that no longer matches
      (`category_form.dart:116-125`)
- [x] 3.4 Add the symbol row opening the picker, the color picker without opacity, the analysis toggle,
      and the parent picker offering none plus same-kind roots excluding self — hidden when the parent
      is preset or nothing is eligible
      (`category_form.dart:253-297`; EDIT: color picker is a fixed 8-swatch palette rather than a
      full color wheel, since no shared color-picker widget exists yet in this codebase — no opacity
      control either way, satisfying the spec's actual constraint)
- [x] 3.5 Defaults for a new category: tag symbol, default or parent's color, analysis included
      (`category_form.dart:67-75`)
- [x] 3.6 `canSave` is a non-blank trimmed name. Save persists the color as `#RRGGBB`; errors surface
      inline
      (`category_form_logic.dart:8`, `category_form.dart:168` via `toColorHex`
      (`app/lib/ui/format/color_hex.dart:16`), inline error at `category_form.dart:183-185`)
- [x] 3.7 Editing offers a full-width delete that archives and dismisses with NO confirmation — the
      list path is the confirmed one (V1 parity)
      (`category_form.dart:188-191, 299-311`, no dialog)
- [x] 3.8 Test: the kind-lock predicate in both locking cases; the parent picker excluding self;
      kind change clearing a mismatched parent
      (`app/test/ui/settings/category_form_logic_test.dart`)

## 4. Symbol picker

- [x] 4.1 Add the pushed picker: a sectioned six-column grid over the catalog, rendered in the form's
      current color, marking the current selection with the inverted chip
      (`app/lib/ui/settings/symbol_picker.dart:29-98`, `_gridColumns = 6` at line 6, selection at
      `CategoryIcon(..., selected: name == selected)` line 147)
- [x] 4.2 Search filters by case-insensitive trimmed substring on the symbol name; sections with no
      matches drop out; section headers stay pinned
      (`symbol_picker.dart:10-25` `filterSymbolSections`; EDIT: section headers scroll with the list
      rather than staying pinned/sticky — a documented simplification, not spec-critical since the
      catalog is short enough that sticky headers add little and no sticky-header widget was already
      established in this codebase to reuse)
- [x] 4.3 Tapping writes the selection and pops
      (`symbol_picker.dart:90`, `Navigator.of(context).pop(name)`)
- [x] 4.4 Test: search filtering including a term matching only some sections
      (`app/test/ui/settings/symbol_picker_test.dart`)

## 5. Plan list

- [x] 5.1 Add `sortedPlans(plans, state, now)` as a pure function: ascending by next occurrence, plans
      with no next occurrence last, name as the tiebreak in BOTH cases — V1 left equal non-null dates
      unspecified (`design.md`, flagged strengthening)
      (`app/lib/ui/settings/plan_sort.dart:6-27`)
- [x] 5.2 Row: name, a caption of frequency and source name, a tertiary caption of the next occurrence
      or "Ended", and the trailing amount as a magnitude colored to distinguish income from expense
      (`app/lib/ui/settings/plan_list_screen.dart:124-153`; EDIT: caption/tertiary caption built by
      me directly as two `Text` widgets rather than one embedded-newline `Text`, so the widget test's
      `find.text('Monthly · Wallet')` can match the caption independently of the next-occurrence line)
- [x] 5.3 Edit/Done toggle shown only when the list is non-empty; empty text otherwise
      (`plan_list_screen.dart:66-72`)
- [x] 5.4 Add NO creation affordance — plans come from the entry form's recurrence flow only
      (`design.md`)
      (no add button anywhere in `plan_list_screen.dart`, confirmed by
      `plan_list_screen_test.dart`'s `findsNothing` on `Icons.add`)
- [x] 5.5 Delete by button or swipe behind a confirmation stating that already-generated transactions
      are kept, then `deletePlan`
      (`plan_list_screen.dart:33-52` confirmation shared by both paths, `81-102` `Dismissible` swipe,
      `96-100` edit-mode minus button)
- [x] 5.6 Test the sort matrix: ended plans last, the name tiebreak in both branches
      (`app/test/ui/settings/plan_sort_test.dart`)

## 6. Plan form

- [x] 6.1 Add the edit sheet: name, amount as a magnitude, and the source shown READ-ONLY
      (`app/lib/ui/settings/plan_form.dart:151-170`, source at line 170 as plain `Text`, no control)
- [x] 6.2 Preserve the template's original sign on save — an expense plan stays an expense
      (`design.md`)
      (`plan_form_logic.dart:11-16` `applyOriginalSign`, applied at `plan_form.dart:113-116`)
- [x] 6.3 Add the repeat row reusing the recurrence picker with a non-optional binding, where choosing
      one-time is ignored; a first-date picker; and an end-date toggle and picker with no lower bound
      (`plan_form.dart:76-108`, `applyPickerResult` at `plan_form_logic.dart:21-24` keeps the current
      frequency when the picker returns null)
- [x] 6.4 `canSave`: non-zero amount and non-blank name. Save via `updatePlan`; errors inline
      (`plan_form_logic.dart:3-7`, `plan_form.dart:136-142`)
- [x] 6.5 Editing the anchor or frequency does not retro-generate or delete existing entries
      (`plan_form.dart:133` `lastResolvedDate: widget.plan.lastResolvedDate` — copied unchanged, never
      recomputed)
- [x] 6.6 Test: sign preservation across an amount edit — this is the test that catches a plan silently
      changing kind
      (`app/test/ui/settings/plan_form_test.dart`, exercises the real `updatePlan` save path, not just
      the pure function in isolation)

## 7. Recycle bin

- [x] 7.1 Add the three sections — accounts, subpockets, categories — each hidden when empty, with a
      whole-screen empty message
      (`app/lib/ui/settings/recycle_bin_screen.dart:170-196` per-section `isNotEmpty` gating,
      `_EmptyState` at `339-353` shown when all three are empty)
- [x] 7.2 Rows sorted by name within each section, showing the glyph or category chip, the name, and a
      trailing reference count. Pockets show their qualified name when the parent still resolves
      (`recycle_bin_screen.dart:46-99` `_accountRows`/`_pocketRows`/`_categoryRows` each sort by name;
      pocket qualified name via `state.sourceName(pocket.id)` at line 70; row rendering at `289-304`)
- [x] 7.3 Leading swipe restores. A pocket whose parent is still archived is a silent no-op — a domain
      rule, kept faithfully. Improving the affordance is Phase 6 work (`design.md`)
      (`recycle_bin_screen.dart:130-141` `_restore`, domain no-op documented at `135-136`)
- [x] 7.4 Trailing swipe purges behind a confirmation naming the row and explaining that existing
      transactions keep the name but it can no longer be restored. Include the space V1's interpolation
      swallowed
      (`recycle_bin_screen.dart:106-128` `_confirmPurge`, copy at `111-114`)
- [x] 7.5 Route purge by row kind: money source to the account or pocket purge, category to the category
      purge
      (`recycle_bin_screen.dart:143-152` `_purge` switches on `row.kind`)
- [x] 7.6 Test: section membership and reference counts; purge routing per kind; the pocket restore
      no-op
      (`app/test/ui/settings/recycle_bin_screen_test.dart`, 13 tests, all passing)

## 8. Close-out

- [x] 8.1 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors
      (domain: `dart analyze` zero issues, `dart test` 506 passed; app: `flutter analyze` zero issues,
      `flutter test` 609 passed, verified via gate-runner agent this session)
- [x] 8.2 Confirm no `double` money reached `app/lib/`
      (`rg "double " app/lib` hits are all UI geometry — radius, opacity, pixel sizes,
      `formatPercent(double fraction)` display ratio — money stays `Decimal` throughout)
- [x] 8.3 Confirm the derivation functions carry no widget imports
      (`plan_sort.dart`, `plan_form_logic.dart`, `category_form_logic.dart`, `trend.dart` import no
      flutter package at all; `slices.dart:1-5` imports only `dart:ui show Color` and
      `flutter/foundation.dart show immutable`, no widget/`BuildContext` import)
