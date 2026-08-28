# 59. Flows own nested Navigators; `Step` replaces `NavigationIntent` for flow-scoped navigation

## Status

Accepted

## Context

ADR-0058 gave navigation a nonce-identified `NavigationIntent` field on `ViewState`: the
ViewModel decided where to go, the View compared a nonce and performed the actual `Navigator`
call. This still left the View holding a mapping from a destination value to a concrete widget —
a `switch (intent.destination) { case BudgetDetail(id): ... }` or equivalent. The project owner
judged this residual mapping to still be navigation-flow knowledge the View shouldn't carry, and
asked for a dedicated navigation owner instead.

Two designs were evaluated and rejected before this one:

- **A single `NavigationService` injected into every ViewModel**, reached via a global
  `GlobalKey<NavigatorState>`. Rejected: this is a navigation singleton in a different shape — one
  object every ViewModel depends on to reach anywhere in the app — and consensus review found it
  weakens ViewModel testability back toward needing `ProviderContainer`/`WidgetTester`, the exact
  regression ADR-0058 was written to avoid.
- **A plain Dart `Flow` object holding a `ref.listen` subscription**, modeled directly on the iOS
  library RxFlow (RxSwiftCommunity/RxFlow — a "Reactive Flow Coordinator" framework; its `Flow`
  protocol exposes `var root: Presentable` and `func navigate(to step: Step) -> FlowContributors`,
  reacting to `Step` values emitted by child view models). Rejected: a plain Dart object has no
  framework-managed disposal hook, so nothing safely closes the listen subscription — the same
  class of lifecycle bug that broke ADR-0057's `transform` design. A retained `BuildContext` used
  to reach the `Navigator` also goes stale the moment its owning widget rebuilds or unmounts,
  risking a `Navigator.of()` call on a deactivated ancestor.

RxFlow itself avoids nesting navigation controllers because UIKit forbids nesting one
`UINavigationController` inside another — its Flows push screens onto one shared stack instead.
That constraint is UIKit-specific. Flutter's `Navigator` supports nesting as a normal, documented
pattern (Flutter's own cookbook uses it for giving each tab of a bottom-navigation bar an
independent back stack), so the Dart translation does not need to inherit RxFlow's shared-stack
shape — it can give each Flow its own nested `Navigator` instead, which turns out to solve the
`BuildContext`-staleness problem structurally rather than working around it.

## Decision

**Each Flow is a `ConsumerStatefulWidget` that owns its own nested `Navigator`**, built as a
direct child in the Flow's `build()` method, scoped with a `GlobalKey<NavigatorState>` that is a
field on that one Flow's `State` — never shared app-wide, never a singleton. Each `app/lib/ui`
feature folder being migrated (`budgets`, `accounts`, `settings`, `stats`, `transactions`) gets
its own Flow. Because `Navigator.of(context)` resolves to the nearest ancestor `Navigator`, any
code inside a Flow's own subtree reaches that Flow's `Navigator` by ordinary tree structure — no
global lookup, no retained context.

**Each Flow defines its own sealed `Step` type**, replacing `NavigationIntent` entirely — one
navigation-signal mechanism, not two:

```dart
sealed class BudgetsStep {}
class BudgetSelected extends BudgetsStep { final String id; BudgetSelected(this.id); }
class AddBudgetRequested extends BudgetsStep {}
```

A screen's ViewModel (unchanged from ADR-0058: `AsyncNotifier<ViewState>`, an abstract per-screen
interface, named methods taking only raw values) emits a `Step?` as part of its `ViewState` when
it decides navigation should happen. `Step` is a plain Dart type with no Flutter import — its
variants carry only plain data (a `String id`, not a `Widget` or `BuildContext`) — so this does
not reintroduce a Flutter dependency into the ViewModel layer. The View still never touches
navigation: it renders only `ViewState`'s data fields. The mapping from a `Step` value to a
concrete pushed screen lives entirely in the Flow.

**`Step` consumption is single-shot.** The ViewModel's interface exposes a `clearStep()` method;
the Flow calls it immediately after acting on a non-null `Step`, the same discipline ADR-0058's
nonce field enforced. (A nonce/id on `Step`, diffed by the Flow against the last-handled value, is
an accepted alternative implementation of this same contract if an explicit clear call proves
awkward in practice — the requirement is "no double-fire on an unrelated rebuild," not one
specific mechanism for it.)

**The Flow watches its children's `Step` via `ref.listenManual`, called in `initState`**, not
`ref.listen` and not `build()`. Riverpod's own documentation names `ref.listenManual` as the
sanctioned primitive for listening outside `build()` — plain `ref.listen` is a `build()`-only API.
The returned subscription is closed in the Flow's `dispose()`. This is what closes the "who
disposes the listener" gap that broke the plain-Dart-object version of this design:
`ConsumerStatefulWidget.dispose()` is a real, framework-managed lifecycle hook, not a
manually-tracked resource a caller might forget.

**Every Flow wraps its nested `Navigator` in a `PopScope`** that delegates to that Flow's own
`NavigatorState.maybePop()` before letting a pop reach the root `Navigator`. This is mandatory,
not a per-Flow judgment call: Flutter's default back-button/back-gesture behavior resolves to the
root `Navigator`, which would otherwise pop an entire Flow instead of one screen inside it.

**Parent-to-child-flow completion uses an `onEnded` callback passed to the Flow widget at
construction**, not one Flow watching another Flow's provider:

```dart
BudgetsFlow(onEnded: () => /* pop this Flow, resume the parent */)
```

Plain widget composition, not a reactive stream — this is the Dart equivalent of RxFlow's
`.end(withStepForParentFlow:)`, expressed the way Flutter already expects a child to tell its
parent something happened (the same shape as any `on...` callback prop). Watching a sibling or
child Flow's provider directly was considered and rejected: it leaks that Flow's scope into a
place that shouldn't need to know about it.

**Global overlays** (a dialog or snackbar that must appear above a Flow, not scoped inside it) use
`Navigator.of(context, rootNavigator: true)` or an app-level `OverlayPortal` at the `MaterialApp`
level — never a nested Flow `Navigator`. This is noted as the boundary rule; it has not been
deeply designed beyond that, since no folder migrated so far has needed it.

## Consequences

**Testing splits along a real boundary, not a compromise.** ViewModels stay unit-testable with
plain `dart test`, unchanged from ADR-0058. Flow navigation logic — which `Step` maps to which
pushed screen, `PopScope` behavior, `onEnded` wiring — is tested with `WidgetTester`/
`ProviderScope` widget tests instead, because a Flow is a widget by Flutter's own requirement
(only a widget can host a `Navigator`). This is accepted as the correct place for that test to
live, not treated as a gap to close later.

**Nested navigation is a real cost, not a free abstraction.** Every Flow needs its own `PopScope`
wired correctly or the system back button breaks that Flow's internal navigation. Deep linking
into a Flow's interior and state restoration across nested `Navigator`s are open questions this
ADR does not resolve — no folder migrated so far needs either, and this app has no router package
today. Whichever folder's migration first needs deep linking or restoration should reopen this
ADR rather than solve it ad hoc for one Flow.

**`Step` types live with their Flow, and ViewModels depend on them, not the reverse.** All screens
inside `BudgetsFlow` emit variants of `BudgetsStep`; that type lives in the `budgets/` flow code,
and the screens' ViewModels import it. A ViewModel never depends on Flutter or on the Flow widget
itself — only on the plain-Dart `Step` type its own screen can emit.

The `budgets/` proof migration (issue #33) is the first Flow built against this design. Any gap it
surfaces — the `PopScope` pattern, the `onEnded` contract, or the single-shot `Step` mechanism —
gets folded back into this ADR and `CONTEXT.md`'s MVVM vocabulary before that ticket closes.

## Amendment (issue #36): `Step` also covers a launched modal, not only a pushed screen

The `accounts`/`transactions` migration (issue #36) needed a `Step` variant for a picker bottom
sheet (choosing a parent account, a transfer destination, a category) and for `showDatePicker`.
Neither is a `Navigator` push: both are a modal launched over the current screen, and the modal's
raw result — a picked id, a picked date, or nothing if the user backed out — has to reach the
ViewModel that asked for it.

This ADR's original wording ("the Flow's job is mapping a `Step` value to a push/pop on its own
`Navigator`") did not cover that case. `Step`'s actual purpose is broader than push/pop: it is any
UI action a ViewModel needs but must not decide for itself, because deciding it would require a
`BuildContext` or a Flutter API the ViewModel is not allowed to import. A launched modal fits that
purpose exactly as well as a pushed screen does, so this ADR now states the contract at that
broader level instead of only its push/pop instance.

**A `Step` variant maps to one of two Flow actions**: a `Navigator` push or pop, or launching a
modal (a picker sheet, `showDatePicker`) and reporting its raw outcome back to the ViewModel
through a named method (for example, `applyPickedParent(String? id)`, `applyPickedDate(DateTime?
date)`). Both cases keep the same single-shot discipline: the Flow calls `clearStep()` once it has
acted on the `Step`, whether that action was a push or a modal launch. A ViewModel never launches a
modal itself; only the Flow reaches for a `BuildContext` and a Flutter picker API, exactly as it
already was the only place reaching for `Navigator`.

This widening is now the standing pattern, not a one-off exception scoped to `accounts`/
`transactions`. Any Flow that needs a picker or a native dialog follows the same shape: a request-
side `Step` variant, a named apply method on the ViewModel receiving the raw result, and
`clearStep()` afterward.

## Amendment (issue #38): a wrapped `ChangeNotifier` can race `build()`'s own state install

The `stats`/`budgets` migration (issue #38) surfaced a lifecycle hazard distinct from the
`ref.watch`-outside-`build()` rule ADR-0058 already covers. Several ViewModels in this migration
wrap `AnalysisCache` (`app/lib/ledger/analysis_cache.dart`), a plain `ChangeNotifier`, the same way
earlier ViewModels wrap `Ledger`: `build()` calls `addListener` on it and registers `ref.onDispose`
to remove that listener, so any later change the cache reports updates `ViewState` through the
listener callback.

The hazard: if `build()` kicks off the cache's own async work without awaiting it (a fire-and-forget
`cache.refresh(ledgerState)` call, matching the pattern `AnalysisCache.refresh()` itself already
uses internally), the cache's `ChangeNotifier` can fire and the listener callback can call
`state = AsyncData(...)` with fresh data *before* Riverpod finishes installing `build()`'s own
returned `Future` as the notifier's state. When that ordering happens, Riverpod's own state-install
step runs second and silently overwrites the listener's fresher write with the stale value
`build()` returned — no error, no test failure signal beyond a wrong value in `state.value`, because
reading `state.value` from inside the listener callback itself still shows the correct data at the
moment it runs.

**The fix: `build()` must `await` the wrapped service's own async work**, not fire-and-forget it,
so `build()`'s returned `Future` already carries the populated result and there is no window for
Riverpod's install step to run after a listener's write:

```dart
@override
Future<StatsRootViewState> build() async {
  final currentLedger = ledger;
  currentLedger.addListener(_onLedgerChanged);
  ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));

  final cache = _cache; // ref.read, never ref.watch — see ADR-0058
  cache.addListener(_onCacheChanged);
  ref.onDispose(() => cache.removeListener(_onCacheChanged));

  await cache.refresh(currentLedger.state); // awaited, not fire-and-forget
  return _buildState(currentLedger, cache);
}
```

`AnalysisCache.refresh()` changed from `void` (internally fire-and-forget) to `Future<void>` for
exactly this reason: a `build()` method that wraps it now has something to `await`. A listener
callback that calls `refresh()` itself keeps firing-and-forgetting via `unawaited(...)`, since that
callback runs outside `build()` and has no `Future` to hand back to Riverpod.

**A second, related ordering trap**: any `late`-seeded field a listener callback reads (for example,
a screen's initially-selected month or scope) must be assigned *before* the `await` on the wrapped
service's async work, not after. The service's completion can call the listener callback
synchronously mid-`await`, and a field assigned only after that `await` is not yet set when the
callback runs — surfacing as a `LateInitializationError` rather than a silent race, which is at
least easier to diagnose but still avoidable by ordering the seed assignments first.

This amendment governs any future ViewModel wrapping a `ChangeNotifier`-based cache or service the
same way `AnalysisCache` is wrapped here (as of this migration: `StatsRootNotifier`,
`CategoryDetailNotifier`, `BudgetDetailNotifier`) — not only `AnalysisCache` itself. The general
rule: a `ChangeNotifier` dependency's own async work must be awaited inside `build()`, never started
and left running past `build()`'s return.
