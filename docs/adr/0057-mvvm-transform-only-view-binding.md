# 57. Views bind through a single `transform` call, never through named ViewModel methods

## Status

Superseded by ADR-0058

**Superseded**: a consensus check run before any code was written against this ADR found its
core premise broken under Riverpod's real lifecycle — `transform` cannot run exactly once, since
`autoDispose`, `family` parameter changes, and `ref.watch` dependency changes all recreate the
ViewModel and re-run `build()`. See ADR-0058 for the replacement design and the full list of
issues that led to the change.

## Context

The `app/lib/ui` MVVM migration (wayfinder map: "Migrate app/lib/ui to strict MVVM", issue #30)
first settled that Views must not import `package:domain/` or call the Model directly. A follow-up
question came up during that map's charting: should a View call named methods on its ViewModel for
each interaction — `viewModel.onSaveTapped()`, `viewModel.onNameChanged(text)` — or should the
View↔ViewModel contact point itself be standardized so the View never chooses which method
corresponds to which interaction?

Named per-interaction methods push a decision onto the View: it has to know that a save button
maps to `onSaveTapped` and a name field maps to `onNameChanged`. That is a piece of application
knowledge living in the View, which is exactly the kind of decision this migration intends to keep
out of the View layer.

ReactiveSwift's `BindingViewModel`/`Transform` convention solves the equivalent problem on iOS: the
view controller owns every control and its live signal, hands the whole bundle to the view model in
one call, and the view model's transform function does all the wiring internally. The view
controller never names a view-model method per control.

## Decision

**Every ViewModel exposes exactly one binding entry point**, shaped as:

```dart
Output transform(Input input)
```

- **`Input`** is a plain data class the View constructs once, holding one field per interactive
  element on the View — a `Stream<T>` for anything with a payload (text changes, selections) and a
  `Stream<void>` for anything without one (button taps). The View owns every stream's source
  (`TextEditingController`-backed streams, tap-event streams from buttons) and passes them into
  `Input` unparsed and unvalidated — parsing and validation are decisions, so they happen inside
  `transform`, not before it.
- **`transform`** runs exactly once, at ViewModel construction/build time. Internally, it
  subscribes each `Input` stream to a private method on the ViewModel (`_onNameChanged`,
  `_onSaveTapped`) — the ViewModel decides which stream maps to which behavior; the View supplies
  only the raw streams; the View never calls a private method or any method named after a specific
  interaction.
- **`Output`** is a plain data class of `ValueListenable<T>` (or one `ValueListenable<ViewState>`)
  the View listens to for rendering. This is the read side, deliberately asymmetric from `Input`'s
  `Stream`-based write side: reads are "what is the current value," which `ValueListenable` already
  models; writes are "something happened," which `Stream` already models.
- **The View never calls a named action method on its ViewModel.** The View's only contact with its
  ViewModel is constructing `Input`, calling `transform` once, and listening to the returned
  `Output`. A ViewModel that needs a new interaction wired up changes its own `Input` shape and its
  own `transform` body; it never grows a new public method for the View to call.
- **The View owns every stream's lifecycle** (creating and closing `StreamController`s the same way
  it already must for `TextEditingController`s), matching ReactiveSwift's "the view controller holds
  all references" convention. The ViewModel never retains a reference to anything View-owned beyond
  the streams passed into `transform`.
- **Disposal is provider-owned, not View-called.** The wrapping Riverpod provider's own
  `ref.onDispose` cancels the ViewModel's internal subscriptions when the provider itself is torn
  down. The View never calls a `dispose()` method on the ViewModel — the View's only job stays
  "construct `Input`, call `transform`, watch `Output`."

## Consequences

Every ViewModel's public surface is exactly two members: `transform` and whatever `Output` it
returns. There is no set of named action methods to keep in sync with the View's widget tree, so a
View cannot call the wrong method or forget to wire one up — an unwired interaction simply has no
corresponding `Input` field and fails to compile once the View tries to pass it through.

This pushes real design work onto `Input`'s shape: every interactive element a View has must be
represented as a stream field, including fire-once actions with no natural payload (`Stream<void>`
for taps). A ViewModel with many interactive elements gets a correspondingly large `Input` class;
this is treated as an acceptable, visible cost of the pattern rather than something to work around
with an escape hatch, since an escape hatch (a stray public method) is the exact thing this decision
rules out.

Testing a ViewModel now means constructing a fake `Input` (streams the test controls directly),
calling `transform` once, pushing values through the input streams, and asserting on `Output`'s
listenables — closer to testing a pure function than to testing an object with a public API surface
in the traditional sense. No widget pump or `ProviderContainer` is needed, consistent with the
ViewModel's plain-Dart, framework-free requirement already recorded in `CONTEXT.md`.

The `budgets/` proof migration (issue #33) is the first ViewModel to actually build this shape; if
it turns up a case `transform`/`Input`/`Output` can't express cleanly, that gap gets folded back
into this ADR and `CONTEXT.md`'s MVVM vocabulary before the migration ticket closes.
