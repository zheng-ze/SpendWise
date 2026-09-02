# UI Framework (MVVM)

Last reconciled: 2026-09-02

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
- `app/lib/ui/format/` — `money_format.dart`, `amount_color.dart`, `amount_input.dart`,
  `color_hex.dart`, `date_format.dart`, `amount_parse.dart`, `account_type_format.dart`.
- Per-screen: `transactions/transactions_view_model.dart`, `stats/`, `accounts/`, `budgets/`,
  `settings/`.

## Architecture rules

- **View** imports no domain or persistence code, calls named methods on its ViewModel taking only
  raw unparsed values (a `String`, a `bool`), and depends on the ViewModel's abstract interface
  type, never the concrete class. It never parses, validates, or interprets a value; that is the
  ViewModel's job. (`docs/adr/0058`, `docs/adr/0057`)
- **ViewModel** implements a per-screen abstract interface, owns all state for exactly one View, and
  is exposed by a thin Riverpod provider that is not the ViewModel. A screen that loads data uses
  `AsyncNotifier<ViewState>`, so the View renders via `AsyncValue.when(data:, loading:, error:)`.
  (`docs/adr/0058`)
- **Flow** is a `ConsumerStatefulWidget` owning one feature folder's nested `Navigator` scoped with
  a local `GlobalKey<NavigatorState>`; it watches ViewModels for a `Step` via `ref.listenManual` and
  maps each `Step` to a push/pop. The View never touches navigation. (`docs/adr/0059`)
- **Step** is a sealed per-Flow type carrying only plain data (e.g. `BudgetSelected(String id)`), no
  `Widget` or `BuildContext`; consumption is single-shot — the Flow clears it via `clearStep()` after
  acting. Replaces the earlier `NavigationIntent` field.
- **One ViewModel per View**; shared presentation widgets own no ViewModel because they never read
  Riverpod state (zero `ConsumerWidget`/`WidgetRef` usage).
- **AppShell** gets no ViewModel: its only state is a flat width-to-bool layout computation, no
  async loading, no domain import. It mounts one Flow per destination, with no shell-level navigator.
  (issue #39)

## Notifier conventions

Every ViewModel backed by the app's single `Ledger` uses the `LedgerBackedNotifier` mixin rather
than repeating its ledger accessor and state-update helper. A ViewModel with no `Ledger` dependency,
or one needing a different state-update shape, has no obligation to use it.

A ViewModel that wraps a plain `ChangeNotifier` service (for example `AnalysisCache`) inside
`build()` must await that service's async work there, not fire it and forget it; starting the work
without awaiting lets the service's listener write fresher state before Riverpod installs `build()`'s
value, which then overwrites it. (`docs/adr/0059`, issue #38)

## Formatting rules

- **Currency** — one shared `formatCurrency(Decimal)` helper renders `$3,200.00`; the single-currency
  assumption is deliberate, so a future multi-currency change is one edit.
- **Amount sign** — magnitude absolute; income `+$X` blue, expense `-$X` red, transfer `$X` unsigned
  gray. Net-amount color: `> 0` blue, `< 0` red, `== 0` gray.
- **Amount input** — sanitizer strips to digits and one `.`, max 2 fraction digits, dropped not
  rounded; only the balance field allows a leading `-`.
- **colorHex** — parses `#RRGGBB` or `RRGGBB`; malformed falls back to gray; writing back emits
  `#RRGGBB` uppercase, components clamped 0–255.
- **Dates** — day header, month/year label, week range (exclusive end → subtract a day), and plan
  next-occurrence formats; percentages via `.percent`.
- **Neutral vs semantic color** — neutral label text uses theme `onSurface`; semantic blue/red/gray
  use theme-aware shades, never fixed hex.

## Gotchas and invariants

- "The View never decides what an input means" is a documented convention reviewed like any other
  convention violation, not tool-enforced. (`docs/adr/0058`)
- The `updateState()` dispose guard is what a picker callback needs when its result arrives after the
  sheet that launched it is gone. (`ledger_backed_notifier.dart`)
- A `double` in the domain is a defect; the UI formatting layer uses `Decimal` via the format
  helpers.

## Requirements

- A View imports neither `package:domain/` nor persistence and depends on its ViewModel's abstract
  interface. (`docs/adr/0058`)
- One ViewModel per View; screens that load data use `AsyncNotifier<ViewState>`. (`docs/adr/0058`)
- A Flow owns one feature folder's nested navigator scoped with a local `GlobalKey`; the View never
  navigates. (`docs/adr/0059`)
- `Step` is sealed plain data, single-shot consumed and cleared by the Flow. (`docs/adr/0059`)
- ViewModels backed by `Ledger` use the `LedgerBackedNotifier` mixin. (`ledger_backed_notifier.dart`)
