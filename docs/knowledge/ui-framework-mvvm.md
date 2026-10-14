# UI Framework (MVVM)

Last reconciled: 2026-10-15

## Feature overview

The presentation-layer architecture under `app/lib/ui/`: strict MVVM where a View holds no business
logic and imports neither `package:domain/` nor persistence, a ViewModel per View owns all state and
behavior, a Flow owns each feature folder's nested navigator, and `Step` is the plain-data signal a
ViewModel emits for a UI action it must not decide for itself. Shared formatting helpers live in
`app/lib/ui/format/`.

## Key files

- `app/lib/ui/common/base/ledger_backed_notifier.dart` — the `LedgerBackedNotifier` mixin: a `ledger`
  getter that throws if the ledger is not ready, and `updateState()` that applies a transform to the
  current `ViewState` and no-ops if the provider is disposed.
- `app/lib/ui/common/base/step_emitting.dart` — the `Step` emission contract.
- `app/lib/ui/common/base/flow_base.dart` — the Flow base that watches ViewModels for `Step` and maps each
  to a push/pop on its own `Navigator`.
- `app/lib/ui/shell/app_shell.dart` - the shell: no ViewModel, only the layout
  mode (`shellLayoutModeProvider`), mounting one Flow per destination.
- `app/lib/ui/shell/shell_binding.dart` - the root window binding:
  `buildShellAppContent` is the single `MaterialApp.builder` used by
  `SpendWiseApp`; it reads the root `MediaQuery` size before `SafeArea` and
  supplies it through a scoped `shellWindowSizeProvider` override in a
  retained `ProviderScope`, publishing the resolved mode through a plain
  `ShellLayoutModeScope` above the root `Navigator`. An explicit
  `shellLayoutModeProvider` override in an enclosing scope wins over derived
  geometry. `shellWindowSizeProvider` defaults to `Size.zero`, so fixtures
  without the binding resolve mobile to phone and desktop platforms to
  desktop.
- `app/lib/ui/symbol_map.dart` — symbol-to-IconData mapping.
- `app/lib/ui/theme/` - `spendwise_colors.dart` (`SpendWiseColors` ThemeExtension with the
  Harbour glass light/dark tokens), `spendwise_text.dart` (`SpendWiseText` amount roles plus the
  `context.colors` / `context.text` accessors), `spendwise_theme.dart`
  (`buildSpendWiseTheme(Brightness)`).
- `app/lib/ui/format/` - `money_format.dart`, `amount_style.dart`, `amount_input.dart`,
  `color_hex.dart`, `date_format.dart`, `amount_parse.dart`, `account_type_format.dart`.
- Per-screen: `transactions/transactions_view_model.dart`, `stats/`, `accounts/`, `budgets/`,
  `settings/`, `overview/` (`OverviewFlow`, `OverviewNotifier`, `OverviewScreen`; see
  [overview-ui.md](overview-ui.md)).

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
- **Shared Add presenter** - `openNewEntry` (`app/lib/ui/transactions/entry/new_entry_presenter.dart`)
  is the single entry point for creating entries: it reads `shellLayoutModeProvider` from the
  caller-side ref, maps phone, open and desktop to the matching `AppSheet` presentation, and pushes
  the null-key `EntryForm` (keyed `'new-entry-form'`) with `showAppSheet` on the root navigator,
  supplying a presentation resolver that re-reads the live mode through `ShellLayoutModeScope`
  in the route context and falls back to the captured presentation when no scope is bound.
  Before opening it invalidates the null-key form and receipt
  providers, initializes the fresh form, then applies the optional scoped source prefill. It holds
  exactly one `ref.listenManual` subscription to the null-key form for the modal lifetime, dispatches
  each Step through the shared entry Step handlers (`entry_step_handlers.dart`, presented above the
  sheet through the root navigator), clears each handled Step once, and closes the subscription in
  `finally`. A container-local `newEntryPresentationProvider` (`closed`, `opening`, `presented`)
  drops duplicate requests while non-`closed`: `closed` becomes `opening` before asynchronous
  initialization, `presented` is published immediately before `showAppSheet`, and the provider
  returns to `closed` in `finally`. The provider publishes `presented` while the sheet is up so the
  shell can narrow its page for the open right-half form. A resize neither restarts the presenter nor invalidates the form or coordinator nor
  replaces the subscription or route, so the draft, auxiliary picker routes above the sheet and
  the captured Money source survive threshold crossings.
  `AppShell` routes its phone, open and desktop Add controls through one callback. It captures a source
  only when Money is selected, using a constructor-injected getter backed by the stable
  `MoneyNavigatorObserver`; the observer tracks the top route of AccountsFlow's navigator, and
  scoped Transactions routes carry their preferred source ID. TransactionsFlow handles only
  existing-entry forms. There is no `ProviderScope`, shared lock provider, nested `Navigator` or new Flow.
  (`app/lib/ui/transactions/entry/new_entry_presenter.dart`,
  `app/lib/ui/transactions/entry/steps/entry_step_handlers.dart`,
  `app/lib/ui/transactions/transactions_flow.dart`)
- **One ViewModel per View**; shared presentation widgets own no ViewModel because they never read
  Riverpod state (zero `ConsumerWidget`/`WidgetRef` usage).
- **AppShell** gets no ViewModel: its only state is the layout mode, no async
  loading, no domain import. `shellLayoutModeProvider`
  (`app/lib/ui/shell/shell_providers.dart`) resolves `ShellLayoutMode.phone`,
  `ShellLayoutMode.open` or `ShellLayoutMode.desktop` from fixed platform
  facts (`shellPlatformProvider` captures `isWeb` and `TargetPlatform` once
  per root container) plus the current logical window size
  (`shellWindowSizeProvider`). Web, macOS, Windows and Linux always resolve
  to desktop at any window size; the Fuchsia desktop fallback is preserved.
  On iOS and Android the mode is open exactly when the window is at least
  600 dp wide and at least 480 dp high (`openModeMinWidth`,
  `openModeMinHeight`, both inclusive), otherwise phone, following window
  size changes at runtime in both directions with no hysteresis. Phones are locked to portrait (iPhone `UISupportedInterfaceOrientations` lists portrait only; Android `MainActivity` requests portrait while `smallestScreenWidthDp` is below 600 and re-applies on configuration change), so landscape phones no longer occur; tablets and unfolded foldables keep every orientation, and the 600 x 480 threshold is unchanged for tablets and split-screen windows. The
  inspected Flutter 3.47.4 iOS embedder reports no display features, and the
  rule ignores display features on every platform. Phone and open share one
  stable Scaffold, content Stack and keyed `IndexedStack` with five fixed
  destination positions (overview, history, trends, money, settings) resolved
  through one explicit destination list, never `enum.index`; only chrome and
  the content gutter change between them, so a phone/open switch keeps the
  selected destination, every Flow State, Navigator State and nested route.
  Desktop keeps its own scaffold with the same five slots.
  `ShellDestination` (`overview`, `history`, `trends`, `money`, `settings`)
  defaults to `overview`. Phone shows a rounded five-position bar in exactly
  this order: Overview, Trends, Add, Money, Settings. Add is the exact-centre
  action: an action control with button semantics that opens the shared
  `openNewEntry` presenter without changing the selection and is never
  selected. Open shows a vertical rail docked bottom right in the order
  Overview, History, Trends, Money, Settings, Add (`openRailWidth` 54,
  `openRailRightInset` 9, `openRailBottomInset` 10, `openRailCornerRadius` 18,
  all dp); Add is a filled accent action that is never selected and opens the
  same presenter. The rail keeps labelled button semantics with 48 dp minimum
  hit targets, scrolls vertically when height or text scaling requires it, and
  renders no header gear. Open content reserves an `openRailGutter` of 72 dp
  for existing single pages, and `StatusBanner` shifts by the same gutter.
  Desktop shows a sidebar with the SpendWise wordmark, Overview,
  History, Trends, Money, an Add entry button, flexible separation and
  Settings at the bottom. Overview hosts `OverviewFlow`,
  Trends hosts `StatsFlow`, Money hosts `AccountsFlow`, History hosts
  the unscoped `TransactionsFlow`, Settings hosts `SettingsFlow`. The mobile
  History slot materializes lazily on first open-mode use or explicit History
  selection and is retained afterwards; the phone bar still shows no History
  item. If shell History is selected when the window becomes phone-sized, it
  stays selected and visible with a root back control labelled Overview whose
  explicit back action reselects Overview. A History page already pushed
  inside Overview stays on that nested stack across resize; later Overview
  History requests push within Overview on phone and select shell History on
  open or desktop. There is no header gear and no shell Add FAB.
  `ShellPaneScope` supplies the mode, safe body width and whether Add is
  presented. `ShellPaneHost` calls `pageBuilder(context, presentation)` with
  bounded page constraints and either `ShellPagePresentation.fullPage` or
  `ShellPagePresentation.singleColumn`. In open mode, let W be the complete safe body width: the page
  is W/2 wide when a detail or Add occupies the right half, and W - 72 dp wide
  without either. A visible detail starts at W/2 and is W/2 - 72 dp wide; the
  72 dp rail gutter is reserved once. The host retains the page child at one
  element location across selection, resize and Add visibility changes. It owns
  the detail divider, pinned title/subtitle/actions header and Close button.
  `ShellDetail` requires a stable `id`, title, body builder and `onClose`, with
  optional subtitle and header actions. Page and detail body builders own their
  vertical scrolling. When detail is hidden by phone/desktop mode
  or Add, its subtree remains offstage with feature selection intact.
  `ShellPaneHost` never changes routes. A visible floating action appears only
  for the active, current page in open mode without Add, at 10 dp from the
  bottom and 3 dp from the usable page's right edge (75 dp from the full body's
  right edge). (`app/lib/ui/shell/shell_pane_host.dart`,
  `app/lib/ui/shell/open_rail.dart`)

  Selected-detail state, including `selectedDetailId`, belongs to the feature
  ViewModel and is independent of layout mode. Phone and open row actions write
  the same selection. A retained feature Flow owns at most one managed phone
  detail route; its content observes the latest selection. After selection or
  mode changes, one post-frame reconciliation reads the latest values. Entering
  open removes only that Flow's tracked phone detail route as a presentation-
  only removal, preserving selection. Entering phone pushes one managed detail
  route when selection exists and none is present. A selection change updates
  the existing route instead of stacking another. User Back or Close clears
  selection; presentation-only removal preserves it. Route identity prevents a
  completed outgoing route from clearing a replacement selection. Reconcile
  only after the feature page is exposed: preserve unrelated routes and defer a
  missing phone-detail push while one covers that page. Exactly one exposed
  detail must match the latest selection. Desktop detail presentation remains
  feature-owned. The fixture Flow in
  `app/test/ui/shell/shell_pane_selection_contract_test.dart` proves the
  reconciliation logic a Flow must implement, not a production Flow.
  The desktop sidebar's sync line is a dedicated `SidebarStatusViewModel` that
  watches `hostedSyncStatusProvider`: no selection shows "Sync not configured",
  setup pending shows "Sync setup pending", ready shows "Sync ready", binding
  repair shows "Device access needs repair", session reauthentication shows
  "Sign in to restore sync", unsupported custom sync shows "Custom sync
  unsupported", and unavailable shows "Sync unavailable". The line starts no
  refresh, polling, enrollment or repair operation and shows no synchronization
  timestamp. Phone chrome has no sync line.
  Every visual value in the shell chrome is a named constant.
  `BootChrome` supplies the five feature builders and only the selected
  layout invokes the builders it needs.
   (`app/lib/ui/shell/app_shell.dart`, `app/lib/ui/shell/shell_providers.dart`,
   `app/lib/ui/shell/boot_chrome.dart`)
- **Settings hosting** - `ShellDestination.settings` is a plain retained destination. `BootChrome`
  supplies `SettingsFlow` in the Settings slot and `AppShell` mounts each layout's destinations once in a
  keyed `IndexedStack`, with `SettingsFlow` built without `backLabel` or `onEnded`, so its root
  screen shows no back control. Selecting Settings only writes `selectedDestinationProvider`. Back
  pops Settings child routes; at the root it preserves the selection. Switching destinations retains
  Settings and any open enrollment route. Settings refreshes the hosted sync status on mount,
  whenever Settings becomes the selected destination (a `selectedDestinationProvider` listener),
  and after an enrollment route closes. (`app/lib/ui/shell/app_shell.dart`,
  `app/lib/ui/shell/shell_providers.dart`, `app/lib/ui/shell/boot_chrome.dart`,
  `app/lib/ui/settings/settings_flow.dart`)
- **Destination Back activity** - `DestinationActivity` (`app/lib/ui/common/base/flow_base.dart`) is a
  pure inherited active flag defaulting to active for standalone Flows. Each `IndexedStack` slot
  wraps its destination with the flag derived from the selected destination. An inactive `FlowBase`
  `PopScope` permits propagation and ignores its callback; the active Flow delegates Back through
  its own nested `Navigator`. `FlowBase` reads no shell providers. Nested enrollment and scoped
  Flows inherit their host destination's activity. `TransactionsFlow` additionally gates its
  screen-`Step` consumption on that flag: a hidden retained History instance neither acts on nor
  clears a shared `Step`, rechecks that the provider still holds the same pending `Step` before
  handling, and schedules one post-frame pickup of the current `Step` on activation with the same
  recheck, so a `Step` cleared by the visible owner never replays. (`app/lib/ui/transactions/transactions_flow.dart`)
- **Settings teardown** - `SettingsFlow.dispose` performs terminal cleanup only through one
  disposal-safe microtask using the captured `ProviderContainer` and guard controller: it releases
  `enrollmentFlowOpenProvider` when this Flow owned the route and clears any pending navigation
  step. It never re-emits resume or repair steps and never reopens a route. A route completion
  arriving after teardown cannot release another owner's guard. (`app/lib/ui/settings/settings_flow.dart`)
- **Repair routing and visibility** - `StatusBanner` hides the repair banner only while
  `selectedDestinationProvider` is `settings` and `enrollmentFlowOpenProvider` is true. A repair
  tap selects Settings first and calls `requestRepair()` only while `enrollmentFlowOpenProvider` is
  false. Returning to Settings reveals the existing route without duplication. `SettingsFlow`
  re-checks a pending step after its navigator mounts, so a request made before Settings is built is
  consumed once. (`app/lib/ui/shell/app_shell.dart`,
  `app/lib/ui/shell/status_banner.dart`,
  `app/lib/ui/settings/settings_flow.dart` - `handleStep`)

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
- **Shell confirmations** - `showShellConfirmation<T>` pushes on the root
  Navigator and returns the caller's result; dismissal returns null. Open mode
  places the bounded dialog over the combined page and detail region, ending
  before the 72 dp rail gutter. A transparent full-window route barrier blocks
  the rail, while an IgnorePointer layer dims only the pane region. The open
  dialog has a 308 dp maximum width and bounded scrolling. Phone and desktop
  remain centred over the full window. Delete and recycle-bin purge helpers
  use this route and map null to false, preserving their wording and results.
  (`app/lib/ui/shell/shell_confirmation.dart`,
  `app/lib/ui/common/feedback/delete_confirmation.dart`,
  `app/lib/ui/settings/recycle_bin/recycle_bin_purge_dialog.dart`)
- **Destructive confirmation styling** - the confirm action is a filled button
  in the error token with the on-action label colour; cancel stays text.
  (`app/lib/ui/common/feedback/delete_confirmation.dart`)

## Sheet and component kit

- **AppSheet** (`app/lib/ui/common/sheets/app_sheet.dart`) is the shared kit sheet surface.
  `showAppSheet<T>(context, presentation:, builder:, presentationResolver:)` pushes an
  `AppSheetRoute` on the root navigator, so its barrier covers the window even when opened from
  a nested Flow. `presentation` is a required plain `AppSheetPresentation`
  (`phone`, `open`, `desktop`) value; every caller supplies it, and `ui/common` reads
  no Riverpod state and no window width. An optional `presentationResolver` maps the route
  context to a live presentation; omitted resolvers keep the captured static presentation, and
  resizing a static sheet changes available geometry, never its presentation. The route keeps
  the captured value as the fallback and publishes the resolved value through a retained
  `effectivePresentation` notifier that also drives the barrier color without replacing the
  route: phone and desktop dim the window, open uses a transparent dismissible full-window
  barrier with the underlying page visible but inert. The page resolves the live presentation
  on every build through one stable `Align` ancestry that varies only alignment, box size and
  chrome around the caller's builder subtree, so a keyed form keeps its `State`, controllers,
  selection and focus across presentation changes. Phone spans the full available width at the
  bottom, desktop centres a dialog no wider than 440 while fitting the viewport, and open docks
  a full-height surface in the safe right half starting at half the window width with an 82 dp
  right content inset reserving rail clearance, no grab handle and no height cap. Phone and
  desktop size to content up to `0.66 * (window height - top safe padding - bottom keyboard
  inset)`. Only the body scrolls; the header, footer and input surface stay
  pinned. The route lifts the sheet above the keyboard, and the surface keeps
  its footer/input above the bottom safe inset while the phone background fills
  that inset.
- **Sheet alerts** - the presentation kit owns no Riverpod state. `AppSheetRoute` owns
  alert and action `ValueNotifier`s plus the captured presentation, exposed
  through `AppSheetAlertSlot`; `AppSheet` publishes them post-frame and clears
  them on dispose. The route renders `SheetAlert` outside the sheet, so errors
  and warnings never change sheet height. A View passes its ViewModel's alert
  and callback down. A standalone `AppSheet` needs the route slot with an
  explicit presentation to display anything; a missing slot is a caller error
  reported as a `FlutterError`, never a width or platform fallback. The banner
  is a live region; its action appears only with both a label and callback.
  (`app/lib/ui/common/sheets/app_sheet.dart`, `app/lib/ui/common/sheets/sheet_alert.dart`)
- **Actions** (`app/lib/ui/common/buttons/app_buttons.dart`): `PrimaryButton` is filled, with
  `destructive: true` using error/on-action tokens; `SecondaryButton` defaults to text and
  uses the control outline when `outlined: true`. A null callback disables either button.
- **Surfaces** (`app/lib/ui/common/`): `Tray`, `MedallionRow`, `SummaryBand` (signed amounts
  coloured through `AmountStyle`), `SegmentedControl`, `CompactLabelledFab` with `FabReserveSpace`,
  `NoticeCard`, `EmptyState`, `LoadingTrays` and `ErrorSection` with an optional filled retry.
- **Selection** - `SegmentedControl` and the selectable charts report choices through
  callbacks; the caller supplies the selected value/index on rebuild. `MonthBars` and
  `DonutChart` use `selectedMark` fill with no selection stroke. Month blanks stay zero-height
  even when selected; unselected gaps are dashed stubs and incomplete bars retain their
  distinct fill/outline. (`app/lib/ui/common/inputs/segmented_control.dart`,
  `app/lib/ui/common/charts/month_bars.dart`, `app/lib/ui/common/charts/donut_chart.dart`)
- **CategoryMap** (`app/lib/ui/common/charts/category_map.dart`) uses pure squarified
  `layoutCategoryMap`; returned rectangles and selection callbacks preserve input indices
  despite sorting for layout. Labels pair the category name with its share, never a bare
  number; labels that fail the text-scaled fit check move beside the map and select the
  category when `onSelect` is supplied.
  `WeekStrip` leaves future days blank and draws dashed stubs for past empty days.
  (`app/lib/ui/common/charts/week_strip.dart`)
- **Sheet checks** - `app/test/support/sheet_contract.dart` provides route pumping
  with an explicit presentation, cap checks for every drawn sheet, and an
  assertion that the alert sits outside the sheet subtree.

## Gotchas and invariants

- Legacy pickers still call `showModalBottomSheet`; using the kit does not imply that all
  sheets have migrated. (`app/lib/ui/common/inputs/statement_day_picker.dart`,
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
