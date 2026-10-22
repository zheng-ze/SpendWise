# SpendWise reference generator handoff

The reference source is `docs/design/ui-revamp/generator/`. Build it with:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 docs/design/ui-revamp/generator/build.py
```

The generator writes `spendwise-reference.html` and `frames.json` in this directory. Edit generator sources rather than generated output. [spec.md](spec.md) defines the design contract; [README.md](README.md) maps the source files.

## Frame model and coverage

The page contains 205 registered frames: 173 phone, 11 desktop and 21 foldable frames. The foldable set contains 7 folded and 14 open frames. There is one frame per screen or significant state, controlled by **App theme** at the top of the page. Every frame and app specimen switches between Light and Dark. The separate **Page background** control affects the surrounding page only. Theme duplicates and the side-by-side theme section are absent.

The manifest covers 168 of the original 177 inventory rows. Widget and component specimens do not increase the registered count. Foldable manifest entries have no inventory rows. Frame ids are unique across all form factors. The build checks the foldable frame count, folded count, shared phone bodies for Budgets, Accounts and Plans, device-name placement and inventory coverage.

Samsung Galaxy Z Fold8 and Apple iPhone Duo share the foldable design. The open display uses a 4:3 landscape canvas with navigation along the right edge. The folded screens reuse phone content. The single open Overview frame is `overview`.

## Shared theme and surface rules

`tokens.py` is the source for both app palettes. Light uses the light blue canvas with white content cards and neutral grey separation. Dark uses neutral near-black canvas, raised trays and higher-layer surfaces, with the approved blue accent and dark category colours. Entry rows, History day headers, trays, forms and controls retain their grey borders and dividers in both appearances.

Shared components and layouts use theme tokens for surfaces, text, separators, outlines, accents and category colours. A tablet frame must not contain a light-only surface literal. Photographed receipts retain their paper appearance; palette swatches display the token values they describe. Neither requires fixing an app frame to a theme.

Use App theme to review every phone, desktop and foldable frame in both appearances. Check row boundaries, tray separation, selected controls, chart marks, category colours and text contrast. History's Saturday 3 October day header and the Overview Monthly salary row are useful checks for separator parity.

## Trends: One breakdown, two scopes

The desktop and open-foldable Trends layouts share one full-screen composition. Preserve its structure:

- A full-width top card contains controls, period navigation and the period chart.
- The left column contains a shared breakdown card with Whole period / Selected month, followed by Insights.
- The right column contains the selected-period headline, a month-only Compared with usual card and a chart-free Category averages table.

Scope changes replace the shared breakdown content. There is no separate detail pane or Close action. Trends and category detail keep History selected; Trends returns to History and category detail returns to Trends. Breakdown level and chart style live in Settings.

Category averages has three aligned columns: category name with colour swatch, October amount and monthly average. Each header sits above its column. The expense rows use October totals of Dining 83.90, Groceries 73.50 and Transport 10.00, with monthly averages 403.28, 304.00 and 134.04. Their unrounded averages sum to the usual recorded month of 841.32.

October is the incomplete current month, observed through day 3. The labelled July day 1-3 allocation is Dining 174.00 and Groceries 135.00, with Transport 0.00. These allocations fit within the unchanged July category totals 432.00, 324.00 and 144.00. August has no records and September's seed and sample expenses occur after day 3, so both matched windows contribute 0.00. The three-window total is 309.00, its mean is 103.00 and October's 167.40 is 62.5% higher. Calendar-complete months remain eligible even when they have no entries.

The card uses the shipped wording from `app/lib/ui/stats/trends/trends_usual.dart`:

> Compared with usual: 62.5% higher
>
> Usual is S$103.00, the day 1 to 3 average for July to September, clipped to each month's length.

Year mode has no usual card. Missing-history states remain where the required baseline cannot be formed. Keep qualifiers and completeness explanations outside charts, in frame captions. Category averages remains a table without another chart.

## Navigation and content contracts

The phone bar is Overview, History, Add, Money and Settings. Desktop lists Overview, History, Money with Budgets, Accounts and Plans, and Settings. The foldable rail lists the four destinations, then Add. No page header draws a gear. Settings root has no back action; subpages retain Back to Settings.

Overview defaults to Today, Recent entries and Coming up. Its catalogue and Edit Overview expose all 16 widgets. Overview links to Trends select History and open Trends above it. Sparse widgets retain history-needed, choose-accounts or empty states when appropriate.

Unscoped History list frames place Top categories directly below the summary band and above By week. They show up to three category rows and See more detail; empty periods show only that action. Calendar and search omit the card. The action retains a 48 px hit region. Desktop History opens the editable entry details beside the register.

Money keeps Budgets, Accounts and Plans separate. Category budget bars show spending, a month-end forecast mark and an On pace or Over by chip. Accounts includes Net worth trend and Card utilisation. Plans includes Plans cash flow. Compact labelled FABs serve Add budget, Add account and Add category with reserved end space. Add entry remains in the navigation bar.

Phone sheets size to content, capped at 500 px in a 760 px phone and 366 px in a compact 560 px phone. Headers, actions and input surfaces stay pinned while longer content scrolls. Edit entry keeps Delete entry last in the scrolling content and Update entry above the pad. Receipt selection retains the underlying Add entry sheet. Transient errors and warnings sit outside sheets and consume no sheet height. Desktop Add entry uses a compact content-sized dialog.

## Data sources and arithmetic

All shared figures come from `data.py`; widget calculations and consistency assertions live in `tiles.py`.

| Figure | Value or source |
| --- | --- |
| Reference date | 3 October 2026, SGD |
| October expense totals | Dining 83.90 + Groceries 73.50 + Transport 10.00 = 167.40 |
| October income and net | 3,200.00 income; +3,032.60 net |
| Today's spending | 42.50 + 3.20 = 45.70; the 500.00 transfer is excluded |
| September sample additions | 24.30 Dining, 31.80 Groceries, 18.40 Transport on 28-30 September; total 74.50 on Amex Card |
| Combined September | 263.20 spent: Dining 120.80, Groceries 106.00, Transport 36.40 |
| Amex | 399.60 owed; 285.10 this cycle; statement day 15; sample limit 5,000.00 |
| Net worth now | 20,819.40 |
| OCBC Savings | 1,700.00 own balance + 8,000.00 Emergency Fund + 650.00 Holiday = 10,350.00 |
| Whole-period expenses | Dining 4,116.70 + Groceries 3,113.50 + Transport 1,350.40 = 8,580.60 |
| Monthly category averages | Dining 403.28; Groceries 304.00; Transport 134.04 |
| Complete recorded months for category averages | November 2025 - July 2026 and September 2026, ten months |
| Highest complete recorded month | December 2025, 1,000.00 |
| Sample budget limits | Dining 350.00; Groceries 450.00; Transport 120.00 |
| All spending cap | 1,200.00 |
| Week so far | 241.90 spent; usual 30.73 from prior matching windows 18.00, 74.20 and 0.00 |

`SEP` combines `SEP_SEED` and `SEP_SAMPLE`; `MONTHS` uses that same September. Account figures derive from the combined entries. `MONTHS` holds the labelled monthly history; sample months use the 48 / 36 / 16 category split. `SAMPLE_COMPLETE_MONTHS` and `COMPLETE_MONTHS` define recorded-month averages. Keep this recorded-month table baseline distinct from the immediately preceding calendar-month windows used for Compared with usual and Insights.

Insights use a separately labelled matched-day sample: the July to September Groceries windows are 40.00, 50.00 and 45.00, averaging 45.00; Dining's usual start is 58.00. This specimen is separate from the Trends monthly history and early-July allocation. Insights compare matching days in the three immediately preceding complete months without skipping months. Week so far compares the same weekdays in the three immediately preceding complete weeks without skipping weeks. A week or complete month can have no expenses. The default sparse Week so far state reflects the seed's limited history; its populated specimen is labelled as a sample.

Other named samples include the weekday spending split, net-worth history, previous Netflix price, Gym attention plan, held import and paused-sync account. Preserve their provenance in captions and their definitions in `data.py`. Coming up includes seeded future entries, plans and the Amex statement cut. Card statement cuts are distinct from due dates. Existing fixed sync messages remain exact.

## Deliberately omitted inventory states

1. Add account, no pocketable parents: pockets are added from an eligible account page.
2. Legacy read-only entry view: tapping an entry opens Edit entry.
3. Swipe-to-delete entry confirmation: Delete entry in the edit sheet is followed by Undo.
4. Native receipt capture / camera: platform UI.
5. Native photo / file picker: platform UI.
6. Camera / photo permission prompt: platform UI; the app's denial state is drawn.
7. Conflict review: no approved screen or route.
8. Recycle bin filter: the approved bin uses section groups.
9. Dedicated hosted sync status page: all six status states live inline in Settings.

## Verification and remaining review

The build passes inventory coverage, unique registered ids, foldable counts and shared phone-body equality. Structural checks find 205 figures matching the manifest and 284 unique HTML ids. Python and inline JavaScript parse checks pass, and CSS braces balance. No frame-theme pins, side-by-side section or Overview theme twins remain. Foldable CSS contains no hex colour literals, and theme-specific CSS does not remove borders, outlines or shadows. These checks establish structure and sample consistency, not rendered appearance.

The coordinator reviews the generated page through App theme in both positions. Visual review must cover every frame, the aligned Category averages headers and values, the numerical usual sample, raised dark trays, separator parity, chart and category colours, clipping and overlap. This handoff does not claim a completed browser sweep, screenshot review, measured overflow check at 1440, 1200 and 900 px, or owner visual acceptance. App implementation and runtime checks are outside this reference-only verification.
