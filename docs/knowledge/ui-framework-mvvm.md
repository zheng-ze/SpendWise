# UI Framework (MVVM)

Last reconciled: 2026-10-10

## Feature overview

The presentation-layer architecture under `app/lib/ui/`: strict MVVM where a View holds no business
logic and imports neither `package:domain/` nor persistence, a ViewModel per View owns all state and
behavior, a Flow owns each feature folder's nested navigator, and `Step` is the plain-data signal a
ViewModel emits for a UI action it must not decide for itself. Shared formatting helpers live in
`app/lib/ui/format/`.

## Key files

- `app/lib/ui/common/ledger_backed_notifier.dart` — the `LedgerBackedNotifier` mixin: a `ledger`
  getter that throws if the ledger is not ready, and `updateState()` that applies a transform to the
  current `ViewState` and no-ops if the provider is disposed.
- `app/lib/ui/common/step_emitting.dart` — the `Step` emission contract.
- `app/lib/ui/common/flow_base.dart` — the Flow base that watches ViewModels for `Step` and maps each
  to a push/pop on its own `Navigator`.
- `app/lib/ui/shell/app_shell.dart` — the responsive shell: no ViewModel, only layout bookkeeping
  (`_useRail`, `_extended`), mounting one Flow per destination.
- `app/lib/ui/symbol_map.dart` — symbol-to-IconData mapping.
- `app/lib/ui/theme/` - `spendwise_colors.dart` (`SpendWiseColors` ThemeExtension with the
  Harbour glass light/dark tokens), `spendwise_text.dart` (`SpendWiseText` amount roles plus the
  `context.colors` / `context.text` accessors), `spendwise_theme.dart`
  (`buildSpendWiseTheme(Brightness)`).
- `app/lib/ui/format/` - `money_format.dart`, `amount_style.dart`, `amount_input.dart`,
  `color_hex.dart`, `date_format.dart`, `amount_parse.dart`, `account_type_format.dart`.
- Per-screen: `transactions/transactions_view_model.dart`, `stats/`, `accounts/`, `budgets/`,
  `settings/`.

## Architecture rules

- **View** imports no domain or persistence code, calls named methods on its ViewModel taking only
  raw unparsed values (a `String`, a `bool`), and depends on the ViewModel's abstract interface
  type, never the concrete class. It never parses, validates, or interprets a value; that is the
  ViewModel's job.
- **ViewModel** implements a per-screen abstract interface, owns all state for exactly one View, and
  is exposed by a thin Riverpod provider that is not the ViewModel. A screen that loads data uses
  `AsyncNotifier<ViewState>`, so the View renders via `AsyncValue.when(data:, loading:, error:)`.
- **Flow** is a `ConsumerStatefulWidget` owning one feature folder's nested `Navigator` scoped with
  a local `GlobalKey<NavigatorState>`; it watches ViewModels for a `Step` via `ref.listenManual` and
  maps each `Step` to a push/pop. The View never touches navigation.
- **Step** is a sealed per-Flow type carrying only plain data (e.g. `BudgetSelected(String id)`), no
  `Widget` or `BuildContext`; consumption is single-shot — the Flow clears it via `clearStep()` after
  acting. Replaces the earlier `NavigationIntent` field.
- **One ViewModel per View**; shared presentation widgets own no ViewModel because they never read
  Riverpod state (zero `ConsumerWidget`/`WidgetRef` usage).
- **AppShell** gets no ViewModel: its only state is a flat width-to-bool layout computation, no
  async loading, no domain import. It mounts one Flow per destination, with no shell-level navigator.
  The Settings navigation item is a writer of `settingsOpenProvider`, not a destination.
  (`app/lib/ui/shell/app_shell.dart`, `app/lib/ui/shell/shell_providers.dart`)
- **Settings hosting** - `settingsOpenProvider` (`StateProvider<bool>`) is the only settings-visible
  signal. The Settings navigation item and the repair banner tap set it true. It is cleared in
  exactly two places: the `onEnded` callback of `SettingsFlow` (back control or Android back at the
  Settings root, through `goBack`) and selecting a destination. No route-level pop callback writes
  it, so `Navigator.removeRoute` leaves it true. `AppShell` alone materialises the signal. Below the
  rail threshold it pushes exactly one settings route on the root navigator when the flag turns true,
  with the current destination's label as the back label and its own `StatusBanner` over the
  `SettingsFlow` (the shell's banner is covered), and removes it with
  `Navigator.removeRoute` when the flag turns false. At the rail threshold or wider it shows
  `SettingsFlow` in the content area instead of the selected destination; the rail and the 720/680
  hysteresis come from `layout_breakpoints.dart`. `SettingsFlow` is mounted only while shown and
  refreshes the hosted sync status in `initState`.
- **Close or hand-over at dispose** - `SettingsFlow.dispose` reads nothing from `ref`. It schedules one
  microtask using the captured `ProviderContainer` and `StateController`. If
  `settingsOpenProvider` is still true, a layout switch is re-hosting Settings, and the microtask
  hands over: it releases `enrollmentFlowOpenProvider` if this Flow owned the route and requests
  `ResumeFreshEnrollmentRequested` (unless the status is `HostedSyncReady`) or
  `RepairDeviceAccessRequested` (only for binding repair or session reauth). If the flag is false,
  the user closed Settings: the microtask releases `enrollmentFlowOpenProvider` if this Flow owned
  the route and calls `clearStep()`, so the next open shows only the Settings root. A Flow that saw
  the flag turn false while mounted always takes this path, even when Settings was reopened before
  the outgoing layout of a layout switch finished disposing it.
- **Layout switch with Settings open** - the flag stays true. Phone to rail removes the
  settings route and mounts the content `SettingsFlow`; rail to phone unmounts the content
  `SettingsFlow` and pushes the settings route. The disposed Flow takes the hand-over path, the new
  Flow picks up the step after its first frame, and `enrollmentFlowOpenProvider` admits one
  enrollment route, so one `SettingsFlow` and at most one enrollment route remain once the frame
  settles. `StatusBanner` hides the repair banner only while `enrollmentFlowOpenProvider` and
  `settingsOpenProvider` are both true. A repair tap sets the flag and calls `requestRepair()` only
  while `enrollmentFlowOpenProvider` is false. (`app/lib/ui/shell/app_shell.dart`,
  `app/lib/ui/shell/status_banner.dart`,
  `app/lib/ui/settings/settings_flow.dart` - `_settleAtDispose`, `handleStep`)

## Notifier conventions

Every ViewModel backed by the app's single `Ledger` uses the `LedgerBackedNotifier` mixin rather
than repeating its ledger accessor and state-update helper. A ViewModel with no `Ledger` dependency,
or one needing a different state-update shape, has no obligation to use it.

A ViewModel that wraps a plain `ChangeNotifier` service (for example `AnalysisCache`) inside
`build()` must await that service's async work there, not fire it and forget it; starting the work
without awaiting lets the service's listener write fresher state before Riverpod installs `build()`'s
value, which then overwrites it. (issue #38)

## Formatting rules

- **Theme** - `buildSpendWiseTheme(Brightness)` maps the Harbour glass tokens onto the material
  scheme (primary action, surface, raised surfaces, text, subtext, control/edge outlines, error),
  sets the bundled InstrumentSans family, a filled-button theme for primary actions with text and
  outline themes for secondary actions, underline-only inputs in the focus colour, and sheets on the
  raised token. `surfaceContainerHighest` maps to the tint token, so neutral tracks and inset rows
  stay visible on white light-mode surfaces. Widgets read tokens through `context.colors` and amount
  roles through `context.text`.
  (`app/lib/ui/theme/spendwise_theme.dart`)
- **Font** - Instrument Sans static TTFs (Regular 400, Medium 500, SemiBold 600, Bold 700) are bundled
  under `app/assets/fonts/instrument_sans/` with the OFL text; the licence is registered through
  `LicenseRegistry.addLicense` in `main()`. There is no font network fetch.
  (`app/pubspec.yaml`, `app/lib/main.dart`)
- **Currency** - `formatMoney(Decimal, {symbol})` renders `S$3,200.00` with comma grouping and
  Decimal half-even rounding, never converting through `double`; `symbol: false` renders the bare
  `3,200.00`. `formatSignedMoney` adds an explicit sign (`+S$3,032.60`, `-167.40` bare). Headline,
  hero, band and widget amounts show the symbol; list rows and per-row breakdown amounts are bare.
  The single-currency assumption is deliberate, so a future multi-currency change is one edit.
- **Amount sign and colour** - `AmountStyle.of(context, {kind, signedValue})` replaces the removed
  `AmountColors`. Colour follows kind or sign only: income or positive uses the income token, expense
  or negative uses the expense token, transfer or zero uses the text token. There is no category or
  colour parameter, so an amount is never coloured by its category. A negative `signedValue` takes
  the expense token even when `kind` is income, so a negative is never shown in the income colour.
  (`app/lib/ui/format/amount_style.dart`)
- **Amount input** - sanitizer strips to digits and one `.`, max 2 fraction digits, dropped not
  rounded; only the balance field allows a leading `-`.
- **colorHex** — parses `#RRGGBB` or `RRGGBB`; malformed falls back to gray; writing back emits
  `#RRGGBB` uppercase, components clamped 0–255.
- **Dates** — day header, month/year label, week range (exclusive end → subtract a day), and plan
  next-occurrence formats; percentages via `.percent`.
- **Neutral vs semantic color** - neutral label text uses theme `onSurface`; amount roles use the
  income, expense and text tokens through `AmountStyle`, never fixed hex or `Colors.*`.
- **Destructive confirmations** - the confirm action is a filled button in the error token with the
  on-action label colour; cancel stays text. (`app/lib/ui/common/delete_confirmation.dart`)

## Sheet and component kit

- **AppSheet** (`app/lib/ui/common/app_sheet.dart`) is the shared kit sheet surface.
  `showAppSheet<T>(context, builder:)` pushes an `AppSheetRoute` on the root navigator, so
  its barrier covers the window even when opened from a nested Flow. The builder returns
  `AppSheet(header:, body:, footer:, inputSurface:, alert:, onAlertAction:)`. Below
  `LayoutBreakpoints.railEnter` (720), it spans the phone width at the bottom; at or above
  that width, it centres a dialog no wider than 440. Both size to content up to
  `0.66 * (window height - top safe padding - bottom keyboard inset)`. Only the body
  scrolls; the header, footer and input surface stay pinned. The route lifts the sheet above
  the keyboard, and the surface keeps its footer/input above the bottom safe inset while
  the phone background fills that inset. (`app/lib/ui/shell/layout_breakpoints.dart`)
- **Sheet alerts** - the presentation kit owns no Riverpod state. `AppSheetRoute` owns
  alert and action `ValueNotifier`s exposed through `AppSheetAlertSlot`; `AppSheet` publishes
  them post-frame and clears them on dispose. The route renders `SheetAlert` outside the
  sheet, so errors and warnings never change sheet height. A View passes its ViewModel's
  alert and callback down. A standalone `AppSheet` needs the route slot to display alerts.
  The banner is a live region; its action appears only with both a label and callback.
  (`app/lib/ui/common/app_sheet.dart`, `app/lib/ui/common/sheet_alert.dart`)
- **Actions** (`app/lib/ui/common/app_buttons.dart`): `PrimaryButton` is filled, with
  `destructive: true` using error/on-action tokens; `SecondaryButton` defaults to text and
  uses the control outline when `outlined: true`. A null callback disables either button.
- **Surfaces** (`app/lib/ui/common/`): `Tray`, `MedallionRow`, `SummaryBand` (signed amounts
  coloured through `AmountStyle`), `SegmentedControl`, `CompactLabelledFab` with `FabReserveSpace`,
  `NoticeCard`, `EmptyState`, `LoadingTrays` and `ErrorSection` with an optional filled retry.
- **Selection** - `SegmentedControl` and the selectable charts report choices through
  callbacks; the caller supplies the selected value/index on rebuild. `MonthBars` and
  `DonutChart` use `selectedMark` fill with no selection stroke. Month blanks stay zero-height
  even when selected; unselected gaps are dashed stubs and incomplete bars retain their
  distinct fill/outline. (`app/lib/ui/common/segmented_control.dart`,
  `app/lib/ui/common/charts/month_bars.dart`, `app/lib/ui/common/charts/donut_chart.dart`)
- **CategoryMap** (`app/lib/ui/common/charts/category_map.dart`) uses pure squarified
  `layoutCategoryMap`; returned rectangles and selection callbacks preserve input indices
  despite sorting for layout. Labels pair the category name with its share, never a bare
  number; labels that fail the text-scaled fit check move beside the map and select the
  category when `onSelect` is supplied.
  `WeekStrip` leaves future days blank and draws dashed stubs for past empty days.
  (`app/lib/ui/common/charts/week_strip.dart`)
- **Sheet checks** - `app/test/support/sheet_contract.dart` provides route pumping, cap checks
  for every drawn sheet, and an assertion that the alert sits outside the sheet subtree.

## Gotchas and invariants

- Legacy pickers still call `showModalBottomSheet`; using the kit does not imply that all
  sheets have migrated. (`app/lib/ui/common/statement_day_picker.dart`,
  `app/lib/ui/common/pickers/two_column_picker_sheet.dart`,
  `app/lib/ui/common/pickers/recurrence_picker.dart`,
  `app/lib/ui/common/pickers/account_type_picker.dart`)
- "The View never decides what an input means" is a documented convention reviewed like any other
  convention violation, not tool-enforced.
- The `updateState()` dispose guard is what a picker callback needs when its result arrives after the
  sheet that launched it is gone. (`ledger_backed_notifier.dart`)
- A `double` in the domain is a defect; the UI formatting layer uses `Decimal` via the format
  helpers.

## Requirements

- A View imports neither `package:domain/` nor persistence and depends on its ViewModel's abstract
  interface.
- One ViewModel per View; screens that load data use `AsyncNotifier<ViewState>`.
- A Flow owns one feature folder's nested navigator scoped with a local `GlobalKey`; the View never
  navigates.
- `Step` is sealed plain data, single-shot consumed and cleared by the Flow.
- ViewModels backed by `Ledger` use the `LedgerBackedNotifier` mixin. (`ledger_backed_notifier.dart`)
