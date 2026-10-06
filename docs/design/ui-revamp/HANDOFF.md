# SpendWise reference page: final generator handoff

Brief: `/Users/macbook/Desktop/SpendWise/.lavish/briefs/spendwise-reference.md`.
Output: `/Users/macbook/Desktop/SpendWise/.lavish/spendwise-reference.html`.
Generator: `/Users/macbook/Desktop/SpendWise/.lavish/reference-src/`.

The reference page is rebuilt from the current generator. The light theme now uses a light blue canvas with white content cards, neutral separation and blue accents. The owner reviews the generated result; browser and screenshot verification are excluded from this revision. Earlier layout evidence below remains historical static evidence.

## 2026-10-06: tracked copy with D8 captions and relative paths

This directory supersedes `.lavish/` as the source of truth: `spec.md` is the brief from `.lavish/briefs/spendwise-reference.md`, the generator sources live under `generator/`, and `spendwise-reference.html` is rebuilt from them. The older sections below describe the `.lavish/` working copy; paths and commands there still point at `.lavish/`.

Five changes against the `.lavish/` working copy, then rebuilt:

1. `generator/build.py` resolves its input and output relative to its own directory, so the build works from any working directory and writes `docs/design/ui-revamp/spendwise-reference.html`. `inventory.json` is read from the same parent directory. The build also emits `frames.json`, one entry per registered frame with its area, covered inventory rows and phone or desktop form factor.
2. D8 completeness captions: seed September now draws as complete. Every qualifier or caption string that called seed September incomplete now names only October: `August has no records; October is incomplete.` (in `data.py`, `s_history_trends.py` and `s_money.py`), `October is incomplete.` (standalone qualifier in `s_history_trends.py`), and `Only September and October have recorded income. October is incomplete.` (in `s_history_trends.py`). Every chart draws September as a complete bar; only October keeps the pale incomplete style.
3. `build.py` no longer maps the `Emergency Fund` inventory row to `mo-pocket` a second time, so `frames.json` lists each covered row once.
4. Insight baseline: usual is the mean of the same days in the three months immediately before the current month, and is available only when all three are complete. Months are never skipped. The labelled sample windows move from May, June and July to July, August and September with the same values (Groceries 40.00, 50.00 and 45.00), so every drawn result is unchanged. The Settings insights note and the `ov-insights` and `ov-evidence` captions state the new rule.
5. Week so far and Usual pace: usual uses the same weekdays of the three weeks immediately before the current week, available only when all three are complete. Weeks are never skipped and no week needs its own expense. The seed still draws the history-needed state because the three windows hold only 2 expenses. The Week so far message, its widget caption and the Usual pace setting state the new rule.

Build from the repository root:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 docs/design/ui-revamp/generator/build.py
```

The rebuild reports 184 frames and 168 of 177 inventory rows: 173 phone frames and 11 desktop windows, matching `frames.json`.

## Build and coverage

Run the generator from its source directory:

```sh
cd /Users/macbook/Desktop/SpendWise/.lavish/reference-src
python3 build.py
```

The current build reports `frames 184 bytes 763030`. The reported byte field is the Python string length, rather than the UTF-8 file size.

The page draws 184 registered screens and states: 173 phone frames and 11 desktop windows. It lists 193 states including the 9 deliberately omitted states. It covers 168 of the original 177 inventory rows. Side-by-side copies, 24 usual/sparse widget specimens, and component specimens do not increase the registered screen count.

`build.py` imports shared components and section builders, checks inventory coverage and unique registered frame IDs, and writes the HTML. Edit sources and rebuild; do not edit the generated HTML.

## Latest owner feedback revision: layered sheets and transient alerts

This revision applies only the owner's two notes about the receipt chooser's background sheet and errors or warnings that increase a sheet's height. The light canvas remains `#EDF4F8` with white content cards and blue accents. Dark surfaces remain near-black neutral. Instrument Sans, the Daylight structure, the existing sheet caps and every seed and sample number remain intact. The owner reviews the generated result; browser and screenshot verification are excluded.

### Layered sheets

`rc-choose` now draws the underlying Add entry form through the shared sheet surface, with its handle, pinned header, scrolling form, primary action and number pad. It sizes to content and retains the 500 px cap in the 760 px phone. The compact receipt chooser overlays this sheet instead of placing the Add entry form directly in the full-height backdrop. The Overview header remains visible above the background sheet. The shared compact-phone cap remains 366 px in a 560 px phone.

A static audit of every registered frame found `rc-choose` as the only frame that draws a background sheet beneath another sheet, dialog or chooser. No backdrop contains an unwrapped sheet header. Other picker and confirmation frames draw page backdrops and retain their existing layout.

### Transient sheet banners

The shared `sheet_alert()` component draws a transient banner at the top of the phone, below the status bar and above the sheet. The banner is an absolutely positioned sibling of the sheet wrapper, so it consumes no sheet space. Both themes use the same component. Errors use the existing error text and background tokens; warnings use the existing notice tokens. The two messages previously drawn as neutral snackbars keep their existing neutral colours. This static reference shows the banner while visible; it does not add a dismissal timer.

Existing message text remains exact. The banners replace nested receipt warnings, form validation messages, sheet load and save failures, sync setup failures and repair notices. Retry and save controls remain in the sheet. The invalid server field retains an error underline through an inset shadow, with no additional row height or error-box margin. Verification-code validation changes only its existing underline colour. Informational field hints and notices on full screens remain inline.

The 23 frames that use the shared banner are:

- **Receipt and entry:** `rc-denied`, `rc-draft`, `add-save-failure`.
- **Sync:** `sy-code-failure`, `sy-failure`, `sy-prev-timeout`, `sy-custom-invalid`, `sy-custom-unavailable`, `sy-save-failure`, `sy-repair`, `sy-renew`.
- **Form load errors:** `le-add-err`, `le-budget-add-err`, `le-account-add-err`, `le-account-edit-err`, `le-category-add-err`, `le-plan-edit-err`.
- **Save failures:** `sf-account-add`, `sf-account-edit`, `sf-category`, `sf-plan`, `sf-budget`, `sf-limit`.

`rc-notext` retains its blank draft and focused amount. It contained no error or warning text, so this revision invents no message for that state.

### Build and static verification

`PYTHONDONTWRITEBYTECODE=1 python3 build.py` passes the coverage and unique-frame assertions with 184 registered frames, 168 of 177 inventory rows covered and 9 deliberately omitted. Static Python syntax checks pass. Every sheet alert sits outside the sheet; no sheet contains an inline error or warning message. The only layered-sheet frame has two shared sheet surfaces. Scoped Python sources, this handoff and the generated HTML contain no em dash. These checks are static; visual acceptance belongs to the owner.

The changed sources are `comp.py`, `styles.py`, `s_add.py`, `s_settings.py`, `s_states.py`, `build.py` and this handoff. The sole generated output is `.lavish/spendwise-reference.html`.

## Previous owner feedback revision: sheet sizes and Trends income

This revision applies only the owner's content-sized sheet requirement and the approved Trends income view. The light canvas remains `#EDF4F8` with white content cards and blue accents. Dark surfaces remain near-black neutral. Instrument Sans, the Daylight structure and all existing seed and sample numbers remain intact. Browser and screenshot verification are excluded; the owner reviews the generated result.

### Content-sized sheets

Every phone sheet now uses its natural content height, capped at 500 px in the 760 px phone or 366 px in the compact 560 px phone. Both caps are about two thirds of the phone height. Short forms and pickers naturally occupy half the screen or less. There is no spacer or minimum half-screen height. The underlying page fills the space above the sheet and stays visible.

The shared sheet component separates the handle and header, scrolling form or list, and fixed footer. Cancel, title and header Save stay pinned. Footer actions stay above the number pad or keyboard; without either input surface they sit immediately after the content. Edit entry keeps Delete entry as the last quiet action in the scrolling form and pins Update entry immediately above the pad. Secondary actions in number-pad forms also scroll with the form so they do not sit between the primary action and the pad. Add category retains header Save and also provides Save category directly above its keyboard. The form scrolls when its natural size plus the fixed header, actions and input surface exceeds the cap. Desktop Add entry uses a small centered dialog with the same scroll-and-footer arrangement instead of a full-height side panel.

All 81 phone sheets use this rule. The twelve existing short pickers also gain the cap and pinned header. The frames are:

- **Overview and History:** `ov-addwidgets`, `hi-period`.
- **Add, receipt and editing:** `add-expense`, `add-note`, `add-income`, `add-transfer`, `add-repeat`, `pick-category`, `pick-account`, `pick-repeat`, `pick-date`, `rc-choose`, `rc-reading`, `rc-denied`, `rc-notext`, `rc-draft`, `rc-crop`, `rc-crop-loading`, `edit-entry`, `edit-system`, `add-save-failure`.
- **Money:** `mo-budget-add`, `mo-budget-pick`, `mo-budget-edit-default`, `mo-budget-edit-month`, `mo-fix-balance`, `mo-add-account`, `mo-add-card`, `mo-type-pick`, `mo-statement-pick`, `mo-add-pocket`, `mo-pocket-parent`, `mo-edit-account`, `mo-edit-card`, `mo-edit-pocket`, `mo-plan-edit`, `mo-plan-end`.
- **Categories:** `st-cat-edit`, `st-cat-add`, `st-sub-add`, `st-sub-edit`, `st-parent-pick`, `st-symbol`.
- **Sync:** `sy-setup`, `sy-cancelled`, `sy-cooldown`, `sy-code`, `sy-code-failure`, `sy-finishing`, `sy-failure`, `sy-enrolled`, `sy-prev-finishing`, `sy-prev-timeout`, `sy-custom`, `sy-custom-invalid`, `sy-custom-unavailable`, `sy-saving`, `sy-save-failure`, `sy-repair`, `sy-renew`, `sy-repair-code`, `sy-repair-progress`, `sy-restored`. These flows now sit over the Settings backdrop. Progress and success states use compact content rather than padded page-height centers.
- **Form loading and errors:** `le-add-load`, `le-add-err`, `le-budget-add-load`, `le-budget-add-err`, `le-account-add-load`, `le-account-add-err`, `le-account-edit-load`, `le-account-edit-err`, `le-category-add-load`, `le-category-add-err`, `le-plan-edit-load`, `le-plan-edit-err`.
- **Save failures:** `sf-account-add`, `sf-account-edit`, `sf-category`, `sf-plan`, `sf-budget`, `sf-limit`.

The dense forms expected to need internal scrolling are `add-expense`, `add-note`, `add-income`, `add-transfer`, `add-repeat`, `rc-reading`, `rc-denied`, `rc-notext`, `rc-draft`, `edit-entry`, `edit-system` and `add-save-failure`. The twelve-widget `ov-addwidgets` list and the four-kind `mo-add-account` and `mo-add-card` forms also need scrolling. These are conservative static estimates rather than browser measurements. Every sheet supports the same overflow path if text wrapping increases its natural height. The full form or catalogue remains available; fixed controls and input surfaces consume none of its scroll range.

`add-note` previously showed only Name and Category and placed the caret in Name. It omitted Account, Date, Repeat, Note, Include in analysis and Add receipt. It now uses the complete expense form, with the blank Note field focused. A blank Note field also appears in the corresponding Add expense, income, transfer, repeating and Edit entry forms so changing focus does not remove form sections. No note text is invented.

### Trends income

Existing main Trends phone, desktop, empty, loading and error frames gain the shared Expense / Income segmented control. Expense remains selected in the existing frames, whose charts, breakdowns and numbers remain intact. Breakdown level and chart choices stay in Settings.

- `tr-income` selects October 2026 and shows `+S$3,200.00`. Its monthly chart uses only the recorded September salary of `+3,200.00` on 25 September and October salary of `+3,200.00` on 3 October, both in DBS Checking. All earlier slots stay blank. October uses the existing selected-mark token. Its income breakdown is Salary, 100.0%, `+3,200.00`, with income amount styling.
- `tr-no-income` selects July 2026, which has no recorded seed income. It shows no zero amount or fabricated breakdown. The chart retains the two recorded salary months and leaves every other month blank.
- `tr-desk-income` reuses the existing desktop chart-and-breakdown pair with the same October selection, seed-only monthly bars and Salary breakdown.

The inventory rows `Stats, income` and `Stats, no income` now map to the phone frames and are removed from the omitted list.

### Build and static verification

Run `python3 build.py` from this folder. Coverage and unique-frame assertions pass with 184 registered frames, 168 of 177 inventory rows covered and 9 deliberately omitted. Python source compilation and sheet wrapper checks pass. Each sheet has a scroll body, each active input surface has a fixed footer, and no sheet contains a height-padding flex spacer. No scoped Python source or generated HTML contains an em dash. These checks are static; visual acceptance belongs to the owner.

The changed sources are `comp.py`, `styles.py`, `s_add.py`, `s_history_trends.py`, `s_money.py`, `s_overview.py`, `s_settings.py`, `s_states.py`, `build.py` and this handoff. The sole generated output is `.lavish/spendwise-reference.html`.

## Previous selected-mark, amount and short-picker feedback revision

This revision applies only the owner's seven selected-mark, amount and short-picker notes. The light canvas remains `#EDF4F8`, content cards remain white, the accent remains blue, and the dark palette remains neutral. Instrument Sans, Daylight structure, all registered frames and every seed and sample amount remain unchanged. The owner reviews the generated page; this revision uses no browser or screenshot verification.

1. **Selected chart marks, notes 1-3.** The new `selectedmark` token is purple: `#8B48A0` in light and `#D8A3EB` in dark. Every monthly, annual, miniature, category-trend, budget and component-specimen chart uses the shared selected-fill rule. Selected marks have no outline, ring or border, including selected incomplete bars. Unselected incomplete bars retain their pale fill and accent boundary; period captions retain the incomplete-state explanation. The selected fill contrasts with the canvas at 5.35:1 in light and 9.32:1 in dark, and with white or dark trays at 5.95:1 and 8.32:1.
2. **Amount typography, note 4.** `-S$735.00` in `tr-first` already inherits Instrument Sans; no monospace or alternate font-family rule caused the difference. The preceding revision added `.selp .big` with weight 700 and letter spacing of -0.9 px, overriding the standard `.big` amount style of weight 500 and -0.7 px. This revision removes that override. Shared amount roles explicitly use Instrument Sans, its standard Arial offline fallback and tabular figures. Role-specific sizes remain intact.
3. **Category headlines, note 5.** `tr-cat`, `tr-cat-sub`, `tr-cat-direct` and `tr-desk-cat` remove the icon beside the amount and the category-colour override. Their headline amounts use the expense token and the standard 26 px amount style with weight 500 and -0.7 px tracking. The phone headlines remain directly on the canvas, without a new white card. Desktop retains its existing scope-and-map pane.
4. **Short pickers, notes 6-7.** Twelve phone frames now use content-height bottom sheets with the backdrop visible above them: `hi-period`, `pick-category`, `pick-account`, `pick-repeat`, `pick-date`, `rc-choose`, `mo-budget-pick`, `mo-type-pick`, `mo-statement-pick`, `mo-pocket-parent`, `st-parent-pick` and `st-symbol`. `rc-choose` was already naturally sized; it now shares the same backdrop and height treatment as the other short choosers. The shared sheet reserves at least 96 px above the sheet and allows sheet scrolling if content exceeds its available space.

The following sheets retain their current height because they are forms or long content, rather than short choosers:

- **Long list:** `ov-addwidgets` shows all twelve widgets and their descriptions.
- **Number-pad forms:** `add-expense`, `add-income`, `add-transfer`, `add-repeat`, `rc-reading`, `rc-denied`, `rc-notext`, `rc-draft`, `edit-entry`, `edit-system`, `add-save-failure`, `mo-budget-add`, `mo-budget-edit-default`, `mo-budget-edit-month` and `mo-fix-balance` retain room for the complete pad and action.
- **Text or multi-field forms:** `add-note`, `mo-add-account`, `mo-add-card`, `mo-add-pocket`, `mo-edit-account`, `mo-edit-card`, `mo-edit-pocket`, `mo-plan-edit`, `mo-plan-end`, `st-cat-edit`, `st-cat-add`, `st-sub-add` and `st-sub-edit` retain their existing editing surface, keyboard or form actions.
- **Form loading and error states:** `le-add-load`, `le-add-err`, `le-budget-add-load`, `le-budget-add-err`, `le-account-add-load`, `le-account-add-err`, `le-account-edit-load`, `le-account-edit-err`, `le-category-add-load`, `le-category-add-err`, `le-plan-edit-load` and `le-plan-edit-err` preserve the associated form surface during loading and retry.
- **Form save failures:** `sf-account-add`, `sf-account-edit`, `sf-category`, `sf-plan`, `sf-budget` and `sf-limit` retain the form and recovery action.

Existing confirmation dialogs and contextual menus already size to their content and retain their small dialog or popover treatment. No desktop short chooser used a full-height modal. The desktop Add entry panel retains its existing multi-field form with a typed amount.

This revision changes `tokens.py`, `styles.py`, `s_add.py`, `s_history_trends.py`, `s_money.py`, `s_settings.py`, `build.py` and this handoff. `python3 build.py` rebuilds the sole generated output and passes the coverage and unique-frame assertions with 181 frames. Static Python compilation, generated frame classification and scoped em-dash checks pass. The owner performs the visual review.

## Previous spacing and action owner feedback revision

The owner approves the light blue `#EDF4F8` canvas and white content cards overall. This revision applies the remaining feedback through generator sources and shared components. Both appearances receive the spacing, action hierarchy, weekly-track, sync and headline changes. Palette tokens remain unchanged. The earlier light-theme revision and its dark-equivalence checks below describe the preceding build, rather than the current build.

1. **White amount block.** The shared `.amtf` amount field now uses the surface token, with horizontal inset and rounded top corners. It is white in light and uses the dark surface in dark. This covers Add expense, income, transfer and repeat, all receipt drafts, Edit entry and opening balance, budget limits, Fix balance, Edit plan, save failures and desktop entry forms.
2. **Roomier form rows.** Ordinary `.fld` rows use 10 px vertical padding; active number-pad sheets use 8 px instead of 4 px. Form groups now use a surface card with 10 px horizontal inset in both appearances. Add and Edit entry, receipt states and desktop forms share the group. Account, category, budget, plan and sync fields receive the ordinary spacing where applicable. The number pad stays compact so the form, pad and action fit together.
3. **Rounded bottom bar.** Every phone tab bar has 20 px corners, an 8 px horizontal inset and a complete surface outline. The home indicator sits on the canvas, exposing the rounded lower corners. `ov-default`, all other tabbed frames, theme pairs and widget-page copies share this treatment. The bar's 56 px height remains unchanged.
4. **Action hierarchy.** `ov-evidence` now fills Open in Trends and keeps Dismiss quiet. Retry actions in load failures, sync timeout and shared errors, and Edit plan in `mo-plan-detail`, now use the filled accent treatment. Sheet Save and Done actions are filled, including category and account editing, Overview editing, date, statement-day and symbol pickers. Confirmation dialogs fill their final action, using the destructive colour when appropriate. Notices fill their first action and keep later actions as text. Restore default, Today and other secondary actions retain outlines or text. The desktop Add panel uses its existing filled Save entry action without a duplicate header Save.
5. **Entry-type categories.** `pick-category` represents the expense draft and now contains Dining, Groceries and Transport, with Groceries subcategories and No category. Salary is removed. Its caption states that income drafts show only income categories and transfers have no category picker. The budget picker `mo-budget-pick` and category-parent picker `st-parent-pick` already contain only expense categories; their option sets remain scoped.
6. **Grey weekly background.** The supplied selector resolves to the `.wk .wb` tracks in History's By week tray, including `hi-oct`, `hi-sep`, `edit-deleted` and the forced-appearance copies. All weekly tracks now have transparent backgrounds in both appearances. Recorded bars, incomplete marks, future labels and amounts remain intact.
7. **Sync success background.** The check symbol in `sy-enrolled` has a transparent background. `sy-restored` shares the success treatment. The On status tag in `st-root` and `st-sync-ready` also loses its grey fill.
8. **Sync finishing highlight.** The spinner in `sy-prev-finishing` sits in a small surface card with a visible control-colour ring and an accent segment. `sy-finishing` shares the treatment. Other spinners retain their size and gain a surface-based ring instead of the grey tint ring. Period-arrow buttons also use the surface token where they previously used grey tint directly on the canvas.
9. **Category headline presence.** `tr-cat` combines a bold 34 px category-coloured amount with a larger outlined category icon. `tr-cat-sub` uses the Supermarket colour and shopping-bag icon; `tr-cat-direct` and `tr-desk-cat` share the Groceries treatment. No white headline card is added. Selected headline amounts in all monthly and annual Trends chart frames, including their dark canvas layouts, use stronger weight and tighter tracking. Account, budget and plan headlines already sit in content cards and retain their established treatment.

The sources changed are `styles.py`, `comp.py`, `s_add.py`, `s_overview.py`, `s_history_trends.py`, `s_money.py`, `s_settings.py`, `s_states.py`, `build.py` and this handoff. `python3 build.py` regenerates the sole output file. The build passes coverage and unique-frame assertions with 181 registered frames. Static source compilation passes without creating bytecode caches. No git commands, browser checks or screenshots are used. The owner's visual review remains pending.

The prior sheet-height estimates below are historical. A conservative spacing-only adjustment adds 8 px per field row and 8 px for the amount block margin. Add expense and income become 588 px against 638 px available; the transfer form becomes 518 px against 638 px. Receipt denied, scanned draft and save failure become 641, 657 and 649 px against 702 px. The scanned draft has seven rows, including Receipt attached. Edit entry becomes 593 px against 682 px. These arithmetic checks preserve room for the action in the modeled frame; they do not measure browser wrapping or rendered geometry. The owner reviews the new spacing visually.

## Previous light-theme owner feedback revision

The owner rejected the near-white canvas as bland and asked for the earlier blue background with white content sections, like the Overview widgets. The light theme now uses these centralized surface values:

| Token | Light value | Use |
| --- | --- | --- |
| `base` | `#EDF4F8` | Harbour glass light blue canvas |
| `surface` | `#FFFFFF` | White content cards, trays, panels, number pads and tab bars |
| `raised` | `#FFFFFF` | White sheets and selected controls |
| `tint` | `#F0F1F2` | Neutral chart tracks, medallions and secondary fills |
| `edge` | `#DDDFE2` | Neutral decorative hairlines |
| `control` | `#73777F` | Essential neutral control boundaries |

The reference page's light background also uses `#EDF4F8`. Primary text remains `#25272A`, secondary text remains `#5B5F66`, and the blue action accent remains `#205F83`. Blue remains on actions, selected states, the active tab, links and chart marks. Semantic notice and error surfaces retain their existing colours. Light Add and Edit entry sheets and the desktop Add panel use the canvas as backing for their white form groups; other sheets and the tab bars remain white.

White card coverage is as follows:

1. Trends now has separate chart and expense-breakdown cards in every monthly and annual phone view, including incomplete periods and the first spread. Desktop chart and breakdown panes and category-detail trays remain white.
2. Overview retains white cards for Today and every other widget, including fresh-install and sparse specimens. Today keeps its asymmetric corners and chart marks.
3. History retains its white summary band and By week tray. October and September day groups, calendar-day entries and search-result groups now sit in white cards. The desktop register and selected-entry pane remain white. Deletion and sheet backdrops reuse the same day-group builder.
4. Add entry now has a white form-row group and a white number-pad card. This covers expense, income, transfer, repeating, receipt and save-failure forms, keyboard focus, Edit entry, opening balances and the desktop Add and Edit entry forms. The new form groups add horizontal inset without adding vertical padding or margins. Every number pad uses the same light-only white backing.
5. Money keeps budgets, accounts, plans, account activity and detail content in white shared trays and desktop panes.
6. Settings keeps its groups, categories, recycle-bin sections and sync forms in white shared trays and desktop panes. Fresh-install empty content also receives a white card through the shared empty-state component.

The shared light tokens and light-only selectors cover all registered phone and desktop frames, forced-light side-by-side copies, widget specimens and component specimens. The token appendix lists the restored canvas value and recalculated light contrast ratios. Its elevation, sheet and number-pad descriptions match the new card treatment. The earlier light-only empty future-week track rule remains in place.

`tokens.py`, `styles.py`, `comp.py`, `data.py`, `s_history_trends.py`, `s_add.py` and `build.py` contain the revision. Theme branches keep the original dark content alongside the new light grouping. Every dark token value and dark contrast note matches the previous generator. Existing shared and dark CSS remains unchanged. Two narrowly scoped dark rules preserve the original last-row divider and keypad shrink behavior around the theme-branch wrappers; they do not change the dark palette or layout.

The build passes the existing coverage and unique-frame assertions and still registers 181 frames. Static comparison confirms that all 181 dark-visible frame contents match the previous generator after flattening the theme branches. Python compilation and generated frame tag-balance checks pass. Primary and secondary text contrast on the restored canvas is 13.48:1 and 5.77:1; on white cards it is 14.98:1 and 6.42:1. Blue action text is 6.24:1 on the canvas and 6.94:1 on white cards. Income and expense text on the canvas are 5.94:1 and 5.58:1. Essential control boundaries are 4.04:1 on the canvas and 4.49:1 on white cards. These calculated WCAG token ratios meet AA for the named text roles and are not browser measurements.

No browser or screenshot verification is performed for this revision. The owner's visual review remains pending. The earlier layout estimates below predate the new horizontal card insets and remain historical static evidence.

## The three reported defects

1. History summary overlap: `.band` uses three bounded secondary columns, with `.lead` spanning a separate row. The signed `+S$3,032.60` no longer shares a narrow column with Spent. The two-column net-worth variant also gives its lead a full row.
2. Page-style leakage: pair appearance labels use `.pair .two>div>small`. Pair headings use `.pair>h4`, so their bottom margin does not reach app titles. Component and widget catalogue headings and copy use immediate-child selectors. The page colour swatch uses `.swatch`, while app switches retain `.sw`. App specimens and widget panels use app border tokens. App row amounts retain their width.
3. Save clipping: `sheet_phone()` identifies every active number-pad sheet and assigns `.keypad`. The sheet wrapper has `min-height:0`; keypad children retain their natural height, while the spacer absorbs the available room. Fields, segments, alerts, amounts and actions have compact sheet-specific sizes. Dense receipt and save-failure states use no underlay; Edit entry and the repeating form use the 20 px underlay. Save, Update and Delete remain inside the modeled phone area. The denied-receipt snackbar already had an inline rule in `build.py`; its position did not require a new rule.

These changes are present in the generated HTML and inline CSS. The fit results below are static estimates, not browser measurements.

## Additional audit fixes

- Deleting FairPrice updates the History weekly total from S$167.40 to S$124.90, matching the remaining expenses and the summary band.
- Weekly chart amounts carry S$ rather than bare amount labels.
- Category maps check whole-word width and multiline label height. Small blocks use adjacent names and shares. Settings previews use the shared map geometry and the exact October shares, rather than a hardcoded 50% division. Both previews have adjacent category/share labels.
- Settings-only breakdown controls remain in Settings. The Donut / Category map segment was removed from the component specimen. Trends and category detail retain only their period and scope controls.
- Six inline Settings sync-state frames show their full scroll, rather than clipping the later Settings trays.
- Edit Overview, the full widget chooser and History search show their full scroll. The four-kind Add account form has a shorter underlay.
- List loading states with three skeleton trays use 760 px phone frames. Their former 560 px frames could cut off the last tray. Short error states retain compact frames.
- Sparse This month shows the expense-only net -167.40 with From recorded entries, while income says No income recorded.
- Supermarket and Direct to Groceries detail screens include their scoped monthly trend. These use seed-only amounts: October 42.50 for Supermarket, and September 74.20 / October 12.40 for directly assigned Groceries. Slots before the first scoped record stay blank. No sample subcategory history is invented.
- Captions explicitly identify inherited revision 2 history and sample caps or limits, including the selected category trend, desktop category detail and budget deletion backdrop.
- The generator's em-dash assertion uses `chr(0x2014)`, so the source itself also contains no em dash.

## Historical static layout evidence

The phone is 320 x 760 px with a 5 px border. Its inner height is 750 px. Status and home bars use 34 and 14 px. An active sheet without tabs therefore has 702 px before its underlay. The underlays use 64, 20 or 0 px. Sheet border and vertical padding use 24 px in total. The keyboard's ten-key row uses 276 px before its outer padding; the negative horizontal margins extend it into the phone gutter, without extending beyond the inner frame.

The following rounded-up estimates include sheet border and padding, all fields and actions, and the complete pad. Text wrapping was checked with macOS CoreText Arial fallback widths and the current CSS line heights. The downloaded Instrument Sans font and browser cascade still require Chrome verification.

| Active number-pad frame | Estimated natural sheet height | Available sheet height |
| --- | ---: | ---: |
| add-expense | 524 px | 638 px |
| add-income | 524 px | 638 px |
| add-transfer | 470 px | 638 px |
| add-repeat | 519 px | 682 px |
| rc-reading | 525 px | 638 px |
| rc-denied | 577 px | 702 px |
| rc-notext | 524 px | 638 px |
| rc-draft | 593 px | 702 px |
| edit-entry | 537 px | 682 px |
| edit-system | 474 px | 638 px |
| add-save-failure | 585 px | 702 px |
| mo-budget-add | 352 px | 638 px |
| mo-budget-edit-default | 326 px | 638 px |
| mo-budget-edit-month | 363 px | 638 px |
| mo-fix-balance | 359 px | 638 px |

All 15 active number-pad sheets have the keypad class. The receipt chooser also contains a number pad in its deliberately clipped background preview; that pad is not the active sheet.

Every registered frame was reviewed against its fixed or automatic height, fixed widths, text constraints, overlays and reserved action space. Full-scroll frames have automatic height. FABs use the 58 px reserved footer area, and the deletion Undo snackbar has its own reserved footer. Notices occupy normal flow. Dialogs and the desktop Add overlay intentionally cover their backdrops. No additional concrete static clipping defect remains identified.

At 1440 and 1200 px, main content widths are 1368 and 1128 px. The two pair columns are 669 and 549 px, leaving 328.5 and 268.5 px for each 256 px scaled phone. At 900 px, main content is 852 px and the pair grid has one column. Desktop split panes become one column below 1000 px; Overview columns reduce from three to two below 1250 px. Appendix and catalogue grids also reduce their column counts. These calculations support the target widths, but do not constitute measured `scrollWidth` equality. The page's existing `overflow-x:hidden` is not evidence that overflow is absent.

## Data and theme checks

The independent final data audit confirms the exact seed amounts and arithmetic: October spending 83.90 + 73.50 + 10.00 = 167.40; income +3,200.00; net +3,032.60; today's spending 42.50 + 3.20 = 45.70 with the 500.00 transfer excluded. OCBC Savings includes 1,700.00 + 8,000.00 + 650.00 = 10,350.00. Amex owed remains 325.10 with this cycle 210.60 and statement day 15. Matched-year sample totals and ranked sample splits add up.

Both token sets remain centralized in `tokens.py`. The following audit describes the preceding revision; the current revision keeps its data and palette while changing shared presentation. Registered frames, widget cards and component specimens read app custom properties. The light/dark pairs intentionally retain their forced appearance. Receipt images retain a paper appearance because they represent photographed documents. Static inspection finds no unintended fixed app-theme frame. The owner reviews both appearances in the generated reference page.

Earlier passed checks: generator coverage and unique-frame assertions; balanced generated tags; no duplicate HTML IDs; no missing SVG icon references; Python compilation; inline JavaScript syntax; balanced CSS braces (501 opening and 501 closing); no literal em dash across scoped Python, Markdown, CSS and generated HTML; independent data and Settings-only-control audit. No comments or docstrings were added.

## Deliberately omitted inventory states

1. Add account, no pocketable parents: pockets are added from an eligible account page.
2. Legacy read-only entry view: replaced by tap to Edit entry.
3. Swipe-to-delete entry confirmation: replaced by Delete entry in the edit sheet and Undo.
4. Native receipt capture / camera: platform UI.
5. Native photo / file picker: platform UI.
6. Camera / photo permission prompt: platform UI; the app's denial state is drawn.
7. Conflict review: no approved screen or route.
8. Recycle bin filter: no approved filter; the bin uses section groups.
9. Dedicated hosted sync status page: status lives inline in Settings, including all six states.

## Preserved design decisions

- Direct to Groceries follows dark revision 2 instead of Other Groceries from round 6.
- Money order is Budgets, Accounts, Plans. The Transport sample limit is 120.
- Coming up includes the two seeded future entries, Rent on 3 November and Cold Storage on 8 November, as well as the plans and Amex cut.
- Desktop History opens editable entry details beside the register.
- Add entry remains in the tab bar. Compact labelled FABs serve Add budget, Add account and Add category, with reserved end space.
- Settings retains the earlier full list. Both breakdown choices are in Settings alongside chart colours. Category taps still open detail.
- Insights use the history-needed state by default. The labelled sample state and evidence use the round 4 matched-day windows.
- Existing sync copy remains where the source defines fixed messages.

## Historical browser verification limits

`chrome-devtools-axi` could not bootstrap: `BRIDGE_NOT_READY`. Its cached direct MCP bridge exited with code 1. CUA denied both Google Chrome and Vivaldi because Computer Use was not approved for those applications. The attempted CLI stop was a no-op because no browser session started.

No final browser screenshots were taken. No live visual sweep, theme interaction check, or `scrollWidth` comparison at 1440, 1200 and 900 px passed in this run. The earlier partial Chrome screenshot is historical evidence only.

The owner has explicitly excluded browser and screenshot verification for the current revision. The earlier instruction to open Chrome, sweep frames, measure overflow and capture screenshots is superseded. The owner reviews the generated HTML. The latest revision above resolves the Trends income question.
