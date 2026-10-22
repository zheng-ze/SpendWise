# SpendWise reference specification

The reference is the comprehensive visual contract for SpendWise's approved Daylight structure and Harbour glass appearance. It covers phone, desktop and foldable layouts, including significant loading, empty, error, editing and sync states. Apply the established design consistently.

## Deliverable and source

Maintain the source in `generator/` and regenerate `spendwise-reference.html` and `frames.json` with the command in [README.md](README.md). Never edit generated output by hand. `inventory.json` defines the 177-row checklist; the generated inventory table maps drawn screens to code locations and records intentionally omitted states.

Draw one frame per screen or significant state. Every frame follows the page's **App theme** control, which switches all app content between Light and Dark using shared token sets. Do not draw duplicate Light and Dark frames or a side-by-side theme section. A separate **Page background** control changes only the surrounding page. Widget and component specimens also follow App theme.

Phone frames cover every applicable screen. Desktop uses one neutral window style shared by macOS and Windows. Include desktop compositions wherever layout differs meaningfully: Overview, History, Trends, Money Budgets, Accounts and Plans, account detail, Add entry, Settings and Edit Overview. Foldable frames share a design for Samsung Galaxy Z Fold8 and Apple iPhone Duo, with folded phone layouts and open layouts with right-edge navigation.

## Navigation and shared appearance

The four destinations are Overview, History, Money and Settings. The phone tab bar places Add in the centre. Money contains Budgets, Accounts and Plans. Desktop uses a sidebar with the same destinations and groups the Money screens together. No page header draws a gear. Settings is its own destination; its subpages retain Back to Settings.

Trends opens from History and keeps History selected in the phone bar, desktop sidebar and foldable rail. Its back action returns to History. Category detail returns to Trends. Overview links to Trends select History and open Trends above it.

Use Instrument Sans with Arial as the offline fallback and tabular numerals for money. Light uses a light blue canvas, white cards, neutral grey separation and blue accents. Dark uses neutral near-black canvas, raised tray and higher-layer surfaces, the approved blue accent and dark category counterparts. Preserve every border, divider, outline and separation boundary in both themes through appropriate tokens, including entry rows and History day headers. Photographed receipt paper retains its document appearance.

Shared components include record trays, icon medallions, signed summary bands, segmented controls, compact labelled FABs, widget cards, notices, sheets and the number pad. Summary totals take the colour of their sign. Transfers stay neutral. Reserve end space beneath list FABs. Field focus uses an underline and caret. Edit entry places Update entry before Delete entry and provides Undo after deletion. The amount-first number pad hands off to the keyboard for text fields.

Sheets size to content, capped at about two thirds of the phone height. Handles, headers, actions and input surfaces stay pinned while longer content scrolls. Transient sheet errors and warnings sit above the sheet and consume no form height. Layered receipt selection retains the Add entry sheet behind the compact chooser.

## Trends composition

Preserve the shared full-screen composition, **One breakdown, two scopes**. A full-width top card holds the Expense / Income and Month by month / Year by year controls, period navigation and period chart. The left column holds one shared breakdown card with a Whole period / Selected month scope control, followed by Insights. The right column holds the selected-period headline, a month-only Compared with usual card and a chart-free Category averages table. Changing scope replaces the shared breakdown content. Do not introduce a detail pane or Close action.

Category averages has three aligned columns: category name with colour swatch, selected-month amount and monthly average. Place each header above its column and align money columns consistently in both themes.

The October expense sample includes a numerical Compared with usual result derived from the labelled sample history. Use the shipped wording in `app/lib/ui/stats/trends/trends_usual.dart`, including its elapsed-day wording for the incomplete current month. Keep comparison data consistent across applicable Trends frames. Missing-history states remain appropriate where a valid baseline is unavailable.

Month by month shows fixed 12-month spreads. Year by year compares three years over matching months. Arrows move one spread. Year mode has no Compared with usual card. Breakdown level (Categories or Subcategories) and chart style (Donut or Category map) live in Settings; content screens show the selected settings. Tapping a category opens its detail with subcategories and entries.

Charts contain no qualifier text. Put sample provenance and completeness explanations in frame captions. Use a dashed stub for a month with no records and blank slots before the first record. Incomplete periods use the incomplete-mark treatment; selected bars use the purple selected-mark token without an outline. Category maps show names and shares, using adjacent colour-linked labels when blocks are too small. Never show bare-number map labels.

## Overview, History and coverage

Overview defaults to Today, Recent entries and Coming up. Edit Overview and the catalogue expose all 16 widgets, with populated and sparse specimens where appropriate. Notices sit above content. History list mode places Top categories below the summary band and above By week, with up to three category rows and See more detail. Calendar and search omit this card. The desktop register and editable entry detail share a screen.

Draw Add, Edit and receipt flows, pickers, dialogs, every Settings page, hosted and own-server sync flows, fresh-install states, notices and failures. Appearance offers Light, Dark and System. Sync status lives inline in Settings. The nine deliberately omitted inventory states and their reasons are listed in [HANDOFF.md](HANDOFF.md).

## Data rules

Use `generator/data.py` as the shared source of seed and labelled sample values. Every displayed total must reconcile with that data.

- October 1-3 spending is Dining 83.90, Groceries 73.50 and Transport 10.00, totalling 167.40. Income is +3,200.00 and net is +3,032.60.
- Today's entries are Monthly salary +3,200.00, To savings 500.00, FairPrice groceries -42.50 and MRT to work -3.20. The transfer does not count as spending.
- OCBC Savings is 10,350.00, comprising own balance 1,700.00, Emergency Fund 8,000.00 and Holiday 650.00.
- September combines the four seed entries with three labelled sample expenses totalling 74.50. Its spending is 263.20. With these samples included, Amex payable is 399.60, the current cycle is 285.10 and net worth is 20,819.40. Statement day is 15.
- Monthly history, category splits, budget limits, matched-day insight windows and other sample values remain labelled in captions. Keep annotations outside drawn app content.

Insights compare matching days in the three immediately preceding complete months. Months are never skipped. A complete month can have no records. Week so far compares the same weekdays in the three immediately preceding complete weeks; a week does not need an expense to count. Keep sparse states when the required history is unavailable.

## Tokens and verification

Include a compact appendix for both colour sets and their contrast values, type scale, spacing, radii, elevation, chart rules, icon style and shared components. Keep app colours in shared tokens. Frame-specific light colour literals must not determine tablet appearance. Receipt-paper colours and token swatches represent their own content rather than app-theme overrides.

The page is static and portable, with inline CSS and JavaScript; Google Fonts are allowed. Use sentence case, plain verbs and plain hyphens. Avoid litotes and irony. The feedback block provides one note per area, an overall note and Prepare feedback.

The build must pass coverage and unique-id assertions. Audit theme CSS for equivalent borders, dividers, outlines and shadows across phone, desktop and foldable elements. Confirm that no screen uses a fixed Light or Dark override. Review the generated frames with App theme in both positions, checking raised surfaces, contrast, chart and category colours, table alignment, clipping and overlap. Check for horizontal overflow at 1440, 1200 and 900 px in a browser when browser verification is available. Static checks alone do not verify rendered geometry or the theme interaction. Report remaining verification limits explicitly.
