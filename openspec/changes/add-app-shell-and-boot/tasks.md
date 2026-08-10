Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §0 and §1, which are more detailed
than the specs in this change.

Depends on `add-ledger-runtime` (boot phases, banner state) and `add-drift-store` (a real store to
boot against). The master doc's sequencing rule: no UI work before Phase 3 is green.

## 1. Formatting

- [ ] 1.1 Add `formatCurrency(Decimal)` via `intl` — grouping, 2 decimal places, one shared
      definition so a future multi-currency change is one edit. Add `intl` to `app/pubspec.yaml`
- [ ] 1.2 Add the amount sign rule: magnitude always absolute, income positive-prefixed, expense
      negative-prefixed, transfer unsigned
- [ ] 1.3 Add the net-amount color rule: above zero gain, below zero loss, exactly zero neutral. Theme
      colors only — never hardcoded black (`design.md`)
- [ ] 1.4 Add `colorHex` parsing: accept `#RRGGBB` and `RRGGBB`, fall back to gray on malformed input.
      Write back uppercase `#RRGGBB`, components clamped, alpha dropped
- [ ] 1.5 Add the plain amount format for pre-filling fields: 2 decimal places, no grouping, no symbol
- [ ] 1.6 Add date formats: day header (day number plus abbreviated weekday/month/year), month and year
      selector labels, week range, plan next-occurrence
- [ ] 1.7 Week range renders a half-open window by subtracting one day from the exclusive end, so the
      displayed end is the last included day
- [ ] 1.8 Add percentage formatting with no fraction digits
- [ ] 1.9 Test: currency grouping; the sign rule per kind; the color rule at exactly zero; the hex
      fallback to gray; the week-range decrement

## 2. Amount input sanitizer

- [ ] 2.1 Add `sanitizeAmount(text, {allowsNegative})` as a pure function: keep digits and one decimal
      point, DROP fraction digits beyond two rather than rounding, permit a single leading minus only
      when negatives are allowed
- [ ] 2.2 Wrap it in a `TextInputFormatter` applied on every keystroke
- [ ] 2.3 Test: a third fraction digit is dropped and the first two are untouched; a minus is stripped
      where not allowed and kept where allowed; junk characters are removed

## 3. Symbol map

- [ ] 3.1 Add `symbol_map.dart` mapping the fixed chrome symbol set to Material icons
- [ ] 3.2 Map the full category catalog — 9 sections of 10 names — plus a fallback icon for unknown
      strings from imported or synced data
- [ ] 3.3 Stored values stay SF Symbol names; the map is presentation-only, so data round-trips with
      the native app
- [ ] 3.4 Test: every catalog name resolves to an icon; an unknown name yields the fallback

## 4. Shared components

- [ ] 4.1 Add the two-tab bar: equal widths, animated underline sliding between tabs, bold when active
- [ ] 4.2 Add the month/year selector: chevrons stepping one month or one year, label from §1.6, state
      owned by the screen's provider — never widget-local
- [ ] 4.3 Add the column-text row: N equal-width caption-over-value columns
- [ ] 4.4 Add the amount field: currency prefix shown only when non-empty, the §2 formatter, decimal
      keyboard, negatives permitted only where the caller allows
- [ ] 4.5 Add the category icon chip: circular, glyph at 44% of chip size, category color at 15% opacity
      background with a full-color glyph; the selected variant inverts to a white glyph on solid color
      with a ring
- [ ] 4.6 Add the two-column picker sheet as a modal bottom sheet
- [ ] 4.7 Add the form scaffold: title, Cancel dismissing without confirmation, Save disabled until the
      form reports it can save
- [ ] 4.8 Add the error section: appears only after a save threw, phrased "Could not save …: <error>"
- [ ] 4.9 Test: the amount field's prefix appears only when non-empty; the form scaffold's Save
      enablement; the error section appearing only after a failure

## 5. Shell and boot chrome

- [ ] 5.1 Add the adaptive shell: bottom navigation bar on compact widths, side rail on wide, four
      destinations in order — Transactions, Stats, Accounts, Settings
- [ ] 5.2 Give each destination its own navigator so per-tab stacks survive switching
- [ ] 5.3 Add boot chrome driven by the Phase 3 phase provider: centered spinner while loading; on
      failure the headline, the error description and a Retry that re-runs boot; the shell when ready
- [ ] 5.4 Test: each of the three boot phases renders its chrome; Retry re-enters loading
- [ ] 5.5 Test: drill into a detail, switch destination, switch back — the detail is still there
- [ ] 5.6 Test: a shell rebuild does not reset a non-current selected month (pins provider-owned state)

## 6. Banner overlay

- [ ] 6.1 Add a root-level overlay layer driven by the Phase 3 banner state — NOT a `SnackBar`, which
      is transient where the save state is an ongoing condition
- [ ] 6.2 Show the plan-error message when set, otherwise the save-state message; show nothing when the
      store reports clear
- [ ] 6.3 Test: the banner persists while the state is non-clear; plan errors take precedence; nothing
      renders on a healthy run

## 7. Close-out

- [ ] 7.1 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors
- [ ] 7.2 Confirm no `double` money reached `app/lib/`
- [ ] 7.3 Confirm no hardcoded black text: `grep -rn "Colors.black" app/lib/`
- [ ] 7.4 Confirm no screen code landed here — screens belong to the four screen changes
