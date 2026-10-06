Build the final comprehensive reference draft of every SpendWise screen in the approved design. This page becomes the visual reference for implementation, so completeness, consistency and accuracy matter more than novelty. Do not invent new directions; apply what has been approved.

Write one new file, `/Users/macbook/Desktop/SpendWise/.lavish/spendwise-reference.html`. You may keep generator scripts and screenshots in `/private/tmp/claude-501/-Users-macbook-Desktop-SpendWise/d86a5735-4117-4054-9661-1a4bbb541019/scratchpad/reference/`. Change no other repository file. Run no git commands.

## The approved design, and where it is recorded

Read these fully before building. Later items override earlier ones where they conflict.

1. `.lavish/ui-redesign-app.html` and its screen inventory table (177 screens and states taken from `app/lib/ui/`). Use it as the checklist of what the app contains. Its visual style is superseded.
2. `.lavish/ux-ideation-4.html`: the Daylight structure. Tabs are Overview, History, Trends and Money, with Add in the tab bar and Settings reached from the gear. Desktop uses a sidebar. Overview insights follow the rules stated in round 4.
3. `.lavish/ux-ideation-6.html` and `.lavish/ux-ideation-7.html`:
   - the coverage map placing all 24 previously missing features (visible, one tap in, only when needed, under More options, hidden);
   - the six feature screens: History week totals, Add account kinds, the Money Plans tab, Category More options, Sync setup, and Overview notices;
   - Trends as a single Month by month / Year by year control with fixed spreads (12 months; 3 years compared on matching months), arrows that move one spread, and the "Compared with usual" row.
4. `.lavish/ux-ideation-8.html`:
   - the 12 Overview widgets, with the default set Today, Recent entries and Coming up;
   - Edit Overview;
   - the Harbour glass light look: clear blues, Instrument Sans, rounded record trays.
5. `.lavish/harbour-glass-dark-2.html`, the approved dark mode:
   - near-black neutral surfaces, with blue kept for the accent and charts;
   - the full light and dark token sets with contrast values;
   - the Trends expense breakdown for a selected month or year, shown as a donut or category map with a ranked list and drill-down into category detail.
6. Latest owner decision on revision 2, verbatim, attached to the Categories / Subcategories and Donut / Category map controls on Trends: "These should be a controlled in settings rather than an option here to keep things simple." Remove both switches from Trends (and from anywhere else they appear on a content screen). Put both choices in Settings, next to the existing "Trends default chart" choice: breakdown level (Categories or Subcategories) and chart (Donut or Category map). Trends shows the breakdown using those settings. Tapping a category still opens its detail with subcategories and entries.

Also follow the approved base rules in `.lavish/ui-redesign.html`, Decisions section, wherever later rounds did not replace them:
- the summary band with a signed total coloured by sign;
- icon medallions;
- the compact labelled FAB with reserved end space;
- underline-only focus;
- Edit entry with Update entry first and Delete entry last, followed by Undo;
- the amount-first number pad that hands off to the full keyboard for text fields;
- category maps that never show a bare number.

## What to build

- Every screen and significant state in the app, including:
  - the four tabs and their sub-screens;
  - Add, Edit and receipt flows;
  - pickers and dialogs;
  - every Settings page, including Appearance (Light, Dark, System) and the new Trends breakdown settings;
  - the sync screens and states;
  - empty states for a fresh install;
  - notices and error states;
  - Edit Overview and the widget catalogue.

  Group them by area, and keep a screen inventory table at the top that maps each screen to its section, plus the code location from the earlier inventory.
- Phone frames for every screen. Desktop windows (one shared macOS and Windows look, neutral frame) for every screen where the desktop layout differs meaningfully: at minimum Overview with widgets, History, Trends with the breakdown, Money (budgets, accounts, plans), an account page, the Add entry panel, Settings, and Edit Overview.
- Light and dark for every frame. Theme the drawn app with CSS custom properties for both token sets, and give the page a control that switches every app frame between Light and Dark, separate from the page background control. Also include a short "light and dark side by side" section for the main screens (Overview, Trends, History, Add sheet, Money, Settings), so both can be compared without toggling.
- A compact design-token appendix: colours (light and dark, with contrast), type scale, spacing, radii, elevation, chart rules (gap stub, incomplete bar, category colours), icon style and the component list (tray, medallion row, summary band, segmented control, FAB, widget card, notice, sheet, number pad).

## Data rules

Use the seed (`app/lib/boot/seed_data.dart`) exactly:
- October 1-3 spending is Dining 83.90, Groceries 73.50 and Transport 10.00, 167.40 in total.
- October income is +3,200.00 and the net is +3,032.60.
- Today's entries are Monthly salary +3,200.00, To savings 500.00 (a transfer), FairPrice groceries -42.50 and MRT to work -3.20.
- OCBC Savings is 10,350.00: own balance 1,700.00, Emergency Fund 8,000.00 and Holiday 650.00.
- The Amex payable is 325.10, with 210.60 in this cycle and statement day 15.

Use the same labelled sample history as the dark mode revision 2 for Trends and the insights. Every total on a screen must add up. Label samples in captions, and keep annotations out of the drawn UI.

## Quality and verification

- Follow `/Users/macbook/.claude/plugins/cache/claude-plugins-official/frontend-design/2a8ad9f74633/skills/frontend-design/SKILL.md` for craft.
- Page rules:
  - static and portable: inline CSS and JS, with Google Fonts allowed;
  - no horizontal scroll at 1440, 1200 or 900 px;
  - no em dash character (use a plain hyphen);
  - sentence case, plain verbs, no litotes and no irony.
- Verify in Chrome with `chrome-devtools-axi` (run `chrome-devtools-axi --help`):
  - Capture the whole page at 1440 px in both app themes, stepping with `eval "window.scrollTo(0,Y)"` and `screenshot <path>`.
  - View every screenshot with the Read tool.
  - Fix any of: overlapping, clipped or mid-word-wrapping text; a FAB or banner covering content; empty components; bare-number chart labels; wrong numbers; a theme leak, meaning a frame that does not follow the theme switch.
  - Confirm `scrollWidth` equals `clientWidth` at 1440, 1200 and 900 px.
  - Run `chrome-devtools-axi stop` when done.
- End with a short feedback block (one note per area plus an overall note, and a Prepare feedback button) so the owner can flag corrections.

## Report back

The file path; the screen count (drawn versus listed); what moved into Settings for the breakdown; any screen from the inventory you did not draw, and why; any conflict between rounds and how you resolved it; what you verified in the browser, with screenshot paths for Overview, Trends and Settings in both themes; and anything you could not do.
