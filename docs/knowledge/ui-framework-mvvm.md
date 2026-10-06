# UI Framework (MVVM)

Last reconciled: 88e6baf

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
  A responsive layout transition can temporarily keep both shell trees and Settings Flows alive;
  `enrollmentFlowOpenProvider` admits one fresh enrollment or repair route across those Flows.
  When the owner is disposed, a microtask releases the guard and reads cached Hosted Sync status.
  The surviving Flow reopens fresh enrollment unless the status is `HostedSyncReady`, bypassing tile
  eligibility through `ResumeFreshEnrollmentRequested`; repair reopens only for binding repair or
  session reauth. (`app/lib/ui/shell/app_shell.dart`, `app/lib/ui/settings/settings_flow.dart` -
  `_handOverOpenEnrollmentRoute`, `handleStep`; `app/lib/ui/shell/shell_providers.dart`)

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

## Gotchas and invariants

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
