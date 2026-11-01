# UI Framework (MVVM)

Last reconciled: 2026-10-31

## Feature overview

The presentation-layer architecture under `app/lib/ui/`: strict MVVM where a View holds no business
logic and imports neither `package:domain/` nor persistence, a ViewModel per View owns all state and
behavior, a Flow owns each feature folder's nested navigator, and `Step` is the plain-data signal a
ViewModel emits for a UI action it must not decide for itself. Shared formatting helpers live in
`app/lib/ui/format/`.

## Key files

- `app/lib/ui/common/base/ledger_backed_notifier.dart` - the `LedgerBackedNotifier` mixin: a `ledger`
  getter that throws if the ledger is not ready, and `updateState()` that applies a transform to the
  current `ViewState` and no-ops if the provider is disposed.
- `app/lib/ui/common/base/step_emitting.dart` - the `Step` emission contract.
- `app/lib/ui/common/base/flow_base.dart` - the Flow base that watches ViewModels for `Step` and maps each
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
- `app/lib/ui/symbol_map.dart` - symbol-to-IconData mapping.
- `app/lib/ui/theme/` - `spendwise_colors.dart` (`SpendWiseColors` ThemeExtension with the
  Harbour glass light/dark tokens), `spendwise_text.dart` (`SpendWiseText` amount roles plus the
  `context.colors` / `context.text` accessors), `spendwise_theme.dart`
  (`buildSpendWiseTheme(Brightness)`), `category_palette.dart` (`CategoryPalette`, see Category
  palette below).
- `app/lib/ui/format/` - `money_format.dart`, `amount_style.dart`, `amount_input.dart`,
  `color_hex.dart`, `date_format.dart`, `amount_parse.dart`, `account_type_format.dart`,
  `analysis_bucket_name.dart`.
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
  `Widget` or `BuildContext`; consumption is single-shot - the Flow clears it via `clearStep()` after
  acting. Replaces the earlier `NavigationIntent` field.
- **Shared Add presenter** - `openNewEntry` (`app/lib/ui/transactions/entry/new_entry_presenter.dart`)
  is the single entry point for creating entries: it reads `shellLayoutModeProvider` from the
  caller-side ref, maps phone, open and desktop to the matching `AppSheet` presentation, and pushes
  the null-key `EntryForm` (keyed `'new-entry-form'`) with `showAppSheet` on the root navigator,
  supplying a presentation resolver that re-reads the live mode through `ShellLayoutModeScope`
  in the route context and falls back to the captured presentation when no scope is bound.
  The container-local `NewEntryPresentationController` (read through
  `newEntryPresentationControllerProvider`) owns one private Add session per accepted request.
  The session holds a unique identity, the initiating context and ref, the exact root
  `AppSheetRoute` (exposed by the optional `showAppSheet(onRouteCreated:)`), one form Step
  subscription and one completion `Completer`. Ownership is acquired synchronously before
  initialization; a duplicate request, including one made while the outgoing route is still
  animating, returns an immediate no-op `Future`, and only the accepted invocation returns the
  session completion. The controller invalidates the null-key form and receipt providers, starts an
  initialization attempt bound to the session lifetime, subscribes to form Steps, and installs the
  sheet before awaiting that attempt. The route immediately hosts the loading form; a failed load
  leaves the same route open with an explicit Retry action. Retry invalidates only the form provider,
  and the optional scoped source prefill applies once on the first successful attempt. Eligibility
  checks include the owner context, session identity and exact route's `isActive` after awaiting.
  The Add presenter supplies `EntryForm.onDismiss`, which calls the captured session's idempotent `close`. `close` retires the
  session, then pops through the captured Navigator when the Add route is current, or removes only
  that exact route with `removeRoute` when a picker or unrelated route covers it. Covering routes
  stay intact, except the tracked receipt chooser removed during cleanup; their later results are
  rejected by the retired session guard. Retirement is idempotent and also runs on `route.popped` (barrier dismissal, Back) and on route removal, so a
  Navigator teardown that skips `popped` still retires. Ownership releases at `route.completed`,
  which fires after the reverse transition and disposal. Shared shell occupancy also lasts until
  that route completes, keeping the sheet composition through its exit animation.
  Every exit converges on the session's idempotent `retire`: successful save
  (`onDismiss`), Back, barrier dismissal, external route removal, owner teardown and container
  disposal. `retire` closes the Step subscription, marks the plain lifetime token retired so presenter,
  picker and crop continuations stop, and schedules invalidation of
  `receiptEntryCoordinatorProvider(null)` in a microtask outside any lifecycle or tree-finalization
  callback. The controller releases ownership only after that invalidation has run, so a fresh Add
  never starts before the old receipt state is discarded. The coordinator's existing captured
  `initiatingRef.mounted` checks then reject an old scan's prefill and final state; receipt scan code
  is unchanged. `EntryFormNotifier.bindAddLifetime` lets the presenter gate only `save`,
  `requestScan` and `applyCroppedDocument` on the live session; an unbound form keeps its Edit and
  view behavior. A failed Ledger save is not retirement: the session, route, draft and error stay.
  `AppShell` captures the controller when it opens Add and calls `ownerDisposed` from `dispose`
  without reading `WidgetRef`. Owner disposal retires the session; with an installed route it removes
  the route without animation in a microtask (an already outgoing route is left to finish), and with
  no route it releases after deferred cleanup. A late initialization result cannot revive a retired
  session. Other callers rely on the context and session rechecks after awaiting. Container disposal
  runs `NewEntryPresentationController.dispose`,
  which touches only captured state: it retires and defers removal of a surviving route to a
  microtask, and the accepted request still completes at that route's `completed` (it completes
  directly only when no route is installed). A presentation failure is reported once; a route
  created but never installed is disposed, and an installed one is removed and released at `completed`. No process-global state exists.
  The session installs exactly one form Step subscription before pushing the route, but dispatch waits
  for the Add route's first mounted frame. After that frame the session inspects the form's current
  pending Step and runs the same `consumeStep` function the subscription uses. `consumeStep`
  validates the session, reads the current Step, clears it once, rechecks eligibility, then
  dispatches through `dispatchEntryFormStep`; clearing before dispatch means a replacement Step
  emitted during dispatch stays pending for its own consumption, and a later identical user request
  is a new occurrence. Add passes `isCurrent` to every source, destination, category, recurrence,
  date, end-date and crop helper, which check it after each await before mutating; omitted guards
  leave the Edit and view paths unchanged. Resize replaces neither the subscription, the mount
  pickup nor the session identity.
  Add's private session controls duplicate admission and asynchronous eligibility. Shared sheet
  occupancy comes from installed `AppSheetRoute`s through `shellSheetOccupancyProvider`, rather than
  an Add-specific presentation provider. A resize neither restarts the session nor invalidates the
  form or coordinator nor replaces the subscription or route, so the draft, auxiliary picker routes
  and captured Money source survive threshold crossings.
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
  to desktop at any window size; the Fuchsia desktop fallback is preserved. Native desktop windows have a 900 by 600 logical minimum so a docked sheet column stays usable.
  On iOS and Android the mode is open exactly when the window is at least
  600 dp wide and at least 480 dp high (`openModeMinWidth`,
  `openModeMinHeight`, both inclusive), otherwise phone, following window
  size changes at runtime in both directions with no hysteresis. Phones are locked to portrait where the platform honours the request (iPhone `UISupportedInterfaceOrientations` lists portrait only; Android `MainActivity` requests portrait through `requestedOrientation` while `smallestScreenWidthDp` is below 600 and re-applies on configuration change), but Android multi-window can ignore the request and still present a landscape-shaped window; tablets and unfolded foldables keep every orientation, and the 600 x 480 dp rule and its landscape-window tests are unchanged and still cover those cases. The
  inspected Flutter 3.47.4 iOS embedder reports no display features, and the
  rule ignores display features on every platform. Phone and open share one
  stable Scaffold, content Stack and keyed `IndexedStack` with four fixed
  destination positions (overview, history, money, settings) resolved
  through one explicit destination list, never `enum.index`; only chrome and
  the content gutter change between them, so a phone/open switch keeps the
  selected destination, every Flow State, Navigator State and nested route.
  Desktop keeps its own scaffold with the same four slots.
  `ShellDestination` (`overview`, `history`, `money`, `settings`)
  defaults to `overview`. Phone shows a rounded five-position bar in exactly
  this order: Overview, History, Add, Money, Settings. Add is the exact-centre
  action: an action control with button semantics that opens the shared
  `openNewEntry` presenter without changing the selection and is never
  selected. Open shows a vertical rail docked bottom right in the order
  Overview, History, Money, Settings, Add (`openRailWidth` 54,
  `openRailRightInset` 9, `openRailBottomInset` 10, `openRailCornerRadius` 18,
  all dp); Add is a filled accent action that is never selected and opens the
  same presenter. The rail keeps labelled button semantics with 48 dp minimum
  hit targets, scrolls vertically when height or text scaling requires it, and
  renders no header gear. Open content reserves an `openRailGutter` of 72 dp
  for existing single pages, and `StatusBanner` shifts by the same gutter.
  Desktop shows a sidebar with the SpendWise wordmark, Overview,
  History, Money, an Add entry button, flexible separation and
  Settings at the bottom. Overview hosts `OverviewFlow`, Money hosts
  `MoneyFlow`, History hosts the unscoped `TransactionsFlow`, Settings hosts
  `SettingsFlow`. History is mounted eagerly in the keyed stack on every
  layout, with no lazy materialization, no back label and no phone
  back-to-Overview control; its Navigator, selected date and list mode survive
  destination switches and resizes. Overview's View History selects History
  on every layout and pushes no route. There is no Trends destination in the
  shell. There is no header gear and no shell Add FAB.
  `ShellPaneScope` supplies the mode, shared `splitOffset`, `sheetCovered` and `sheetPresented`.
  `sheetPresented` means at least one AppSheet is installed or exiting, including
  forms and pickers. Coverage is narrower: a sheet covers the shell only when its nearest
  non-AppSheet predecessor is the shell route. A sheet over a foreground root page therefore
  contributes occupancy without shifting the shell beneath it.

  `ShellPaneHost` passes bounded constraints and either `ShellPagePresentation.fullPage` or
  `singleColumn` to its page builder. On open and desktop, an exposed detail occupies the right
  column. While the shell is sheet-covered, that current detail shifts left and the list is hidden;
  clearing selection reveals the list, and selecting another detail shifts the new current detail.
  Phone has no shifted pane. With no detail, open and desktop coverage narrow the list into the
  left column beside the docked right-column sheet.
  The page slot always retains its `Align`, sizing, isolation and `MediaQuery` ancestry.
  `_InactivePaneIsolation` toggles Offstage, tickers, focus, semantics and pointer access while
  preserving the page's Flow and Navigator State. A present detail keeps its keyed `_DetailPaneState`
  and body ancestry through shifting; clearing the detail genuinely removes its subtree.
  `ShellDetail.onClose` is optional. The host supplies a Close control only when that callback is
  present; Budgets omits it. A floating action appears only for the active, current open page while
  no AppSheet is installed or exiting. (`app/lib/ui/shell/shell_pane_host.dart`)

  `resolveShellPaneGeometry` is shared by shell and root sheets. Open splits at the physical window
  midpoint, translates the left column through the left safe inset and reserves the 72 dp rail
  gutter once. Desktop splits the safe content remaining after `desktopSidebarWidth` and
  `sidebarDividerWidth` equally, ends at the right safe inset and reserves no rail gutter. The
  desktop sidebar remains mounted. (`app/lib/ui/shell/shell_pane_geometry.dart`,
  `app/lib/ui/shell/app_shell.dart`, `app/lib/ui/shell/desktop_sidebar.dart`)

  Selected detail belongs to the feature. Budgets uses a managed root detail page only on phone,
  reconciled after the frame from current selection, mode and destination activity. Entering open
  or desktop removes that tracked page as a presentation-only change. A matching phone page stays
  when a sheet opens; a new phone push waits until every AppSheet completes. User Back clears the
  selection, while Flow-owned removal preserves it. See [budgets.md](budgets.md) for the route
  completion and subscription contracts (`app/lib/ui/budgets/budget_list/budgets_flow.dart`).
  Trends is an in-page exception to this managed selected-detail presentation:
  open and desktop modes compose its selected-period content in `TrendsOpenLayout`,
  while Category Detail remains a nested route opened by the Trends Flow
  (`app/lib/ui/stats/trends_flow.dart`,
  `app/lib/ui/stats/trends/trends_open_layout.dart`).
  The desktop sidebar's sync line is a dedicated `SidebarStatusViewModel` that
  watches `hostedSyncStatusProvider`: no selection shows "Sync not configured",
  setup pending shows "Sync setup pending", ready shows "Sync ready", binding
  repair shows "Device access needs repair", session reauthentication shows
  "Sign in to restore sync", unsupported custom sync shows "Custom sync
  unsupported", and unavailable shows "Sync unavailable". The line starts no
  refresh, polling, enrollment or repair operation and shows no synchronization
  timestamp. Phone chrome has no sync line.
  Every visual value in the shell chrome is a named constant.
  `BootChrome` supplies the four feature builders and only the selected
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
  wraps its destination with the flag derived from the selected destination. `FlowBaseState` wraps its
  nested `Navigator` in Flutter's `NavigatorPopHandler`, enabled only while the destination is
  active: with depth, system Back and the iOS edge swipe pop the Flow's own `Navigator` (`goBack`);
  at the Flow's root they pass to the enclosing route, so a route-hosted Flow's route pops
  directly and a shell tab Flow's root hands Back to the shell (the system may close the app).
  `goBack` (the on-screen back control when `showsOwnBackButton`, and other direct callers) still calls `onEnded` at the root, but root system Back and the swipe bypass `onEnded` because the enclosing route pops directly.
  An inactive Flow ignores the callback. A Flow that must refuse Back wraps `super.build` in its
  own `PopScope` (the enrollment Flows during a backend save). `FlowBase` reads no shell providers.
  Nested enrollment and scoped Flows inherit their host destination's activity. Add drafts are scoped
  to their sheet, as described in [budgets.md](budgets.md).
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
- **colorHex** - parses `#RRGGBB` or `RRGGBB`; malformed falls back to gray; writing back emits
  `#RRGGBB` uppercase, components clamped 0–255.
- **Dates** - day header, month/year label, week range (exclusive end → subtract a day), and plan
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
  use this route and map null to false, preserving their wording and results. The budget delete
  confirmation (`showBudgetDeleteConfirmation`) also uses it; it is a plain modal route that shell
  occupancy does not track.
  (`app/lib/ui/shell/shell_confirmation.dart`,
  `app/lib/ui/budgets/budget_detail/budget_delete_confirmation.dart`,
  `app/lib/ui/common/feedback/delete_confirmation.dart`,
  `app/lib/ui/settings/recycle_bin/recycle_bin_purge_dialog.dart`)
- **Destructive confirmation styling** - the confirm action is a filled button
  in the error token with the on-action label colour; cancel stays text.
  (`app/lib/ui/common/feedback/delete_confirmation.dart`)

## Sheet and component kit

- **AppSheet** (`app/lib/ui/common/sheets/app_sheet.dart`) is the shared sheet surface.
  `showAppSheet<T>(context, presentation:, builder:, presentationResolver:, onRouteCreated:)` pushes
  on the root Navigator, returns the popped result and exposes the exact route through its optional
  callback. Callers supply `AppSheetPresentation.phone`, `open` or `desktop`; an optional resolver
  reads live configuration, with the captured value as fallback. `AppSheetRoute` retains the resolved
  presentation, publishes it through `AppSheetAlertSlot` and reads it for its barrier. The page
  computes docked bounds from its own `MediaQuery` through `resolveShellPaneGeometry`, so the
  shell supplies no geometry.
  Open and desktop always dock in the right column, whether or not a detail is showing. Phone
  remains a bottom sheet. Docked surfaces use a transparent, dismissible full-window barrier;
  phone sheets dim the window. No centered desktop dialog exists for AppSheets; the shared
  confirmation dialogs are not AppSheets and stay centered. Docked desktop fills its safe right
  column and height, with no dialog cap, grab handle or rail reserve. Its presentation remains
  `desktop`, so Add input and picker content retain desktop behavior. Open standard sheets reserve 82 dp of right content space; the form variant leaves
  that clearance outside its surface and uses a 10 dp content inset. A phone sheet covers the shell's tab bar and its content respects the bottom safe area.
  The route keeps stable placement ancestry around the caller's keyed subtree through live resize.
  The phone height cap defaults to 0.66 of the available height; callers may set
  `phoneMaxHeightFraction`. Add grows the phone cap to 1.0 while the pad is visible or the
  keyboard inset is positive.
  `SheetPinnedLayout` pins header, footer and input when they fit; otherwise the outer scroller
  keeps the whole sheet reachable. The route clears the keyboard and docked placement consumes
  safe insets once. (`app/lib/ui/common/sheets/app_sheet_route.dart`,
  `app/lib/ui/common/sheets/sheet_pinned_layout.dart`)
- **Route-owned shell presentation** - one container-local Riverpod
  `shellSheetOccupancyProvider` holds immutable `ShellSheetOccupancy` state. `AppSheetRoute.install`
  finds the container through its nearest `UncontrolledProviderScope`, registers the route and
  releases it at `route.completed`, retaining occupancy through exit. A created route reserves
  nothing before installation. Registration is a no-op when a bare MaterialApp has no provider
  scope, preserving explicit sheet presentation.
  Each route records its actual predecessor through `didChangePrevious`, which the Navigator
  announces after a push, and `nearestNonSheetPredecessor` skips nested AppSheets. No observer or
  foreground-page classification exists. (`app/lib/ui/common/sheets/app_sheet_route.dart`)
  The state exposes installed/exiting occupancy and shell coverage, which `isCovered` derives from
  the shell's own route. `AppShell` watches `hasSheets`, `suppressesShellNavigation` and
  `isCovered` through `select`, and `BudgetsFlow` listens with `listenManual`. The notifier
  publishes state from a frame callback, coalesced, because registration happens during the
  Navigator flush. Restoration follows the next build, allowing a completion continuation to install the
  next sheet first. The shell derives open-rail suppression
  from installed routes' `showShellNavigation`; those routes render the open rail overlay. Phone
  keeps its tab bar mounted and sheets cover it. Desktop keeps one sidebar beneath the modal barrier, so tapping it dismisses the sheet
  without selecting a destination. (`app/lib/ui/shell/shell_sheet_occupancy.dart`,
  `app/lib/ui/shell/app_shell.dart`, `app/lib/ui/shell/shell_pane_host.dart`)
  Sheets dismiss through their mounted route context or captured exact route. A retained Flow's
  `navigatorContext` can refer to a different Navigator. Budgets ships this exact-route session
  pattern: `_FormSession` and `_EditSession` in `budgets_flow.dart` capture the sheet's
  `AppSheetRoute` through `onRouteCreated`, dismiss it with `pop` when current or `removeRoute`
  when covered, and end at `route.completed`. The Edit flow installs its next surface from the action
  sheet's pop-result continuation, before that route's `completed` fires, so shell occupancy stays
  continuous. Retirement removes the route after the frame ends.
  No timer or captured pane owner is involved. See [budgets.md](budgets.md).
- **Add form surface** - `AppSheetVariant.form` is used by the Add loading and loaded forms.
  In light mode its canvas backing uses `SpendWiseColors.base`; desktop form chrome docks in the right column with
  no grab handle. Standard sheets retain their existing chrome. Phone Add enables
  `dragToDismiss`; `SheetDismissPhysics` shares drag displacement between the body and enclosing
  sheet scrollers, so handle/header drags and body drags at minimum scroll offset move the sheet.
  `SheetDragDismiss` dismisses above 25% displacement or 700 dp/s downward velocity and otherwise
  springs back, immediately under reduced motion. Input focus, pad animation and Add header
  actions belong to the entry form, described in [transactions-ui.md](transactions-ui.md).
  (`app/lib/ui/common/sheets/app_sheet.dart`, `sheet_drag_dismiss.dart`,
  `app/lib/ui/transactions/entry/new_entry_chrome.dart`, `new_entry_form.dart`)
- **Sheet dismissal** - every bottom sheet dismisses by dragging down (phone, `dragToDismiss`) and
  by tapping outside, and carries no Cancel button; header actions only apply a choice (Done,
  Today, Save). `AppPickerSheet` enables `dragToDismiss` for the Add pickers. This deliberately
  differs from the approved reference frames, which draw Cancel. Dialogs (delete and purge
  confirmations) keep their Cancel. (`app/lib/ui/common/pickers/app_picker_sheet.dart`)
- **Sheet alerts** - the `AppSheet` surface owns no Riverpod state. `AppSheetRoute` owns
  alert and action `ValueNotifier`s plus the resolved presentation and docking state, exposed
  through `AppSheetAlertSlot`; `AppSheet` publishes alerts post-frame and the route disposes
  the notifiers. The route renders `SheetAlert` outside the sheet, so errors
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
  callbacks; the caller supplies the selected value/index on rebuild. `MonthBarChart` (baseline, `MonthBars` and the month axis cells, used by `TrendsChart` and
  `BudgetDetailChart`) and `DonutChart` use `selectedMark` fill with no selection stroke. Gap and blank
  months draw no bar, selected or not, and incomplete months draw like any value month. Tapping an axis
  cell selects its month even when it has no bar. `MonthBarChart` optionally draws a dashed limit line,
  the only difference between the budget chart and the Trends chart. (`app/lib/ui/common/inputs/segmented_control.dart`,
  `app/lib/ui/common/charts/month_bar_chart.dart`, `app/lib/ui/common/charts/month_bars.dart`, `app/lib/ui/common/charts/donut_chart.dart`)
- **CategoryMap** (`app/lib/ui/common/charts/category_map.dart`) uses pure squarified
  `layoutCategoryMap`; returned rectangles and selection callbacks preserve input indices
  despite sorting for layout. Labels pair the category name with its share, never a bare
  number; labels that fail the text-scaled fit check move beside the map and select the
  category when `onSelect` is supplied. In-block label text colour is `foregroundOn` of the
  block's actual fill, so a selected block (`selectedMark` fill) and an unselected one each get a
  readable label (`app/lib/ui/common/charts/category_map/category_map_block.dart`).
- **Category palette** (`app/lib/ui/theme/category_palette.dart`) - `CategoryPalette.resolve`
  takes `savedHex`, `rank`, the `ChartColours` mode and the active `SpendWiseColors`, and returns
  one chart colour. `categoryColours`: the six seeded saved hexes map to theme marks (`0xFF34C759`
  groceries, `0xFFFF9500` dining, `0xFF5856D6` transport, `0xFF007AFF` salary, `0xFF30D158`
  supermarket, `0xFF63E6BE` freshMarket); any other hex keeps its hue and saturation with
  lightness clamped to a light or dark band chosen from the surface brightness; null uses the gray
  fallback. `themeShades`: an sRGB `Color.lerp` ramp from `action` to `surface` at eight weights
  (0 to 1/2), indexed by rank modulo eight. `contrasting`: a fixed list of eight theme marks
  (groceries, supermarket, freshMarket, dining, transport, salary, fitness, housing) indexed by
  rank modulo eight. `selectedMark` is never a category colour. Nothing in production calls it
  yet; slices still colour from `colorHex`.
  `WeekStrip` leaves future days blank and draws dashed stubs for past empty days.
  (`app/lib/ui/common/charts/week_strip.dart`)
- **Sheet checks** - `app/test/support/sheet_contract.dart` provides route pumping
  with an explicit presentation, cap checks for every drawn phone sheet, and an
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
