Task groups map to the commit sequence. Each group must leave `flutter analyze` at zero issues and
the app suite green before the next begins. The user commits; do not run `git commit`.

Reference for anything ambiguous: `docs/modules/ui_screens.md` §0 and §1, which are more detailed
than the specs in this change.

Depends on `add-ledger-runtime` (boot phases, banner state) and `add-drift-store` (a real store to
boot against). The master doc's sequencing rule: no UI work before Phase 3 is green.

## 0. Store wiring

Not in the original plan. `add-drift-store` built the store but left `storeProvider` throwing,
because there was no shell to boot into, so the handover named this Phase 5's first job.

- [x] 0.1 Give `storeProvider` a real default building a `DriftLedgerStore` over
      `openLedgerConnection`, behind a `databaseConnectionProvider` seam so tests inject an in-memory
      executor and the store construction itself stays under test
- [x] 0.2 Replace the test pinning the old throw with one pinning that an override still wins
- [x] 0.3 Test: the provider resolves unoverridden, boot reaches `Ready` against a real Drift store,
      and first launch seeds so the app opens with content

## 1. Formatting

- [x] 1.1 Add `formatCurrency(Decimal)` via `intl` — grouping, 2 decimal places, one shared
      definition so a future multi-currency change is one edit. Add `intl` to `app/pubspec.yaml`
- [x] 1.2 Add the amount sign rule: magnitude always absolute, income positive-prefixed, expense
      negative-prefixed, transfer unsigned
- [x] 1.3 Add the net-amount color rule: above zero gain, below zero loss, exactly zero neutral. Theme
      colors only — never hardcoded black (`design.md`)
- [x] 1.4 Add `colorHex` parsing: accept `#RRGGBB` and `RRGGBB`, fall back to gray on malformed input.
      Write back uppercase `#RRGGBB`, components clamped, alpha dropped
- [x] 1.5 Add the plain amount format for pre-filling fields: 2 decimal places, no grouping, no symbol
- [x] 1.6 Add date formats: day header (day number plus abbreviated weekday/month/year), month and year
      selector labels, week range, plan next-occurrence
- [x] 1.7 Week range renders a half-open window by subtracting one day from the exclusive end, so the
      displayed end is the last included day
- [x] 1.8 Add percentage formatting with no fraction digits
- [x] 1.9 Test: currency grouping; the sign rule per kind; the color rule at exactly zero; the hex
      fallback to gray; the week-range decrement

## 2. Amount input sanitizer

- [x] 2.1 Add `sanitizeAmount(text, {allowsNegative})` as a pure function: keep digits and one decimal
      point, DROP fraction digits beyond two rather than rounding, permit a single leading minus only
      when negatives are allowed
- [x] 2.2 Wrap it in a `TextInputFormatter` applied on every keystroke
- [x] 2.3 Test: a third fraction digit is dropped and the first two are untouched; a minus is stripped
      where not allowed and kept where allowed; junk characters are removed

      A partly-typed number is never rewritten, so `12.` and a lone `.` survive, a second decimal
      point is dropped while the digits after it are kept, and leading zeros stand. All three match
      the Swift, which was read to settle them.

      One deliberate divergence: Swift keeps a minus only at index 0 of the raw text, so `a-5`
      loses its sign there and keeps it here. Ours gates on the first surviving character, because
      a stray keystroke ahead of the minus should not silently turn a negative into a positive.

## 3. Symbol map

- [x] 3.1 Add `symbol_map.dart` mapping the fixed chrome symbol set to Material icons
- [x] 3.2 Map the full category catalog — 9 sections of 10 names — plus a fallback icon for unknown
      strings from imported or synced data

      111 distinct keys, covering all 90 catalog names checked against the Swift source plus the
      chrome set, three of which the two surfaces share.
- [x] 3.3 Stored values stay SF Symbol names; the map is presentation-only, so data round-trips with
      the native app
- [x] 3.4 Test: every catalog name resolves to an icon; an unknown name yields the fallback

## 4. Shared components

- [x] 4.1 Add the two-tab bar: equal widths, animated underline sliding between tabs, bold when active
- [x] 4.2 Add the month/year selector: chevrons stepping one month or one year, label from §1.6, state
      owned by the screen's provider — never widget-local

      Stepping normalizes to the first of the month, so the widget does not carry a caller's
      day-of-month.
- [x] 4.3 Add the column-text row: N equal-width caption-over-value columns
- [x] 4.4 Add the amount field: currency prefix shown only when non-empty, the §2 formatter, decimal
      keyboard, negatives permitted only where the caller allows
- [x] 4.5 Add the category icon chip: circular, glyph at 44% of chip size, category color at 15% opacity
      background with a full-color glyph; the selected variant inverts to a white glyph on solid color
      with a ring
- [x] 4.6 Add the two-column picker sheet as a modal bottom sheet

      Returns a `PickerOutcome` rather than a string. Confirming None and dismissing are different
      answers and an empty-string sentinel invited a caller to run them together.
- [x] 4.7 Add the form scaffold: title, Cancel dismissing without confirmation, Save disabled until the
      form reports it can save
- [x] 4.8 Add the error section: appears only after a save threw, phrased "Could not save …: <error>"
- [x] 4.9 Test: the amount field's prefix appears only when non-empty; the form scaffold's Save
      enablement; the error section appearing only after a failure
- [x] 4.10 Test the picker sheet, which 4.9 left uncovered. Choosing a leaf, dismissing and confirming
      None are three outcomes and the tests keep them apart. The first of these caught a `ColoredBox`
      wrapping the row's `ListTile`, which hid every ink splash

## 5. Shell and boot chrome

- [x] 5.1 Add the adaptive shell: bottom navigation bar on compact widths, side rail on wide, four
      destinations in order — Transactions, Stats, Accounts, Settings

      Rail from 720 logical pixels wide.
- [x] 5.2 Give each destination its own navigator so per-tab stacks survive switching
- [x] 5.3 Add boot chrome driven by the Phase 3 phase provider: centered spinner while loading; on
      failure the headline, the error description and a Retry that re-runs boot; the shell when ready
- [x] 5.4 Test: each of the three boot phases renders its chrome; Retry re-enters loading
- [x] 5.5 Test: drill into a detail, switch destination, switch back — the detail is still there
- [x] 5.6 Test: a shell rebuild does not reset a non-current selected month (pins provider-owned state)

      The first version of this test could not fail. It drove the rebuild by changing the window
      width, and `IndexedStack` keeps every destination alive, so a month held in widget state
      survived that too. Remounting under a changed key discards the subtree and makes the test bite.

## 6. Banner overlay

- [x] 6.1 Add a root-level overlay layer driven by the Phase 3 banner state — NOT a `SnackBar`, which
      is transient where the save state is an ongoing condition
- [x] 6.2 Show the plan-error message when set, otherwise the save-state message; show nothing when the
      store reports clear
- [x] 6.3 Test: the banner persists while the state is non-clear; plan errors take precedence; nothing
      renders on a healthy run
- [x] 6.4 Warn when web storage is not durable. `storageIsDurable` in
      `app/lib/persistence/database_connection.dart` is already computed and has no consumer, so a
      browser that offers no durable storage loses the whole ledger when the tab closes and the app
      says nothing. Always true on native. Unlike the save state this is a permanent condition rather
      than a passing one, so decide whether it belongs in this overlay or somewhere it cannot be
      dismissed. Filed by `add-drift-store` group 9

      It went outside the overlay, as a fixed strip above the destinations. The overlay holds
      conditions the app resolves on its own, and a save retry clearing or a plan error timing out
      must not take a warning about permanent data loss with it. The strip also sits outside the
      destination stack, so it survives a switch.

## 7. Close-out

- [x] 7.1 Run `cd app && flutter analyze && flutter test`. Analyzer at zero issues, not just zero errors

      350 app tests and 502 domain tests, both analyzers clean, both packages already formatted.
- [x] 7.2 Confirm no `double` money reached `app/lib/`

      The only `toDouble` in the app is the one inside `formatCurrency`, where `intl` needs it.
      Every other `double` is geometry or an opacity.
- [x] 7.3 Confirm no hardcoded black text: `grep -rn "Colors.black" app/lib/`
- [x] 7.4 Confirm no screen code landed here — screens belong to the four screen changes

      `app/lib/ui/` holds only `format/`, `common/`, `shell/` and `symbol_map.dart`. Destinations
      render placeholders.
