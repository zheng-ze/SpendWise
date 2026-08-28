<title>SpendWise domain context</title>

# SpendWise domain context

A glossary of this codebase's vocabulary, plus an index pointing at where decisions and behavior
contracts live. This file stays lean on purpose: it defines terms once, precisely, and points
elsewhere for the "why" (`docs/adr/`) and the "what" (`docs/specs/`). It does not inline either.

## Glossary

**Ledger / `LedgerState`** — the whole in-memory ledger: money sources, entries, categories and
plans, held in id-keyed tables. The single source of truth the app mutates and persists.

**Money source** — an account or a pocket; the two share one id space and one table
(`moneySources`) because most rules (lifecycle, reference counting) apply identically to both.

**Account** — a money source with a type (cash, checking, savings, card, prepaid, investment,
insurance, loan, overdraft, other) and its own list of pocket ids.

**Pocket** (`SubPocket`) — a money source owned by exactly one account, linked from the parent's
side (`Account.subPocketIDs`), never the child's. See ADR-0002 for why the link points that way.

**Entry** — a single recorded transaction: an amount, a kind (income, expense or transfer), a
source and (for transfers) a destination money source, an optional category, a date, and an
analysis-inclusion flag.

**Transaction category** (`TransactionCategory`) — a label for spending or income, with a kind
(income or expense) and an optional parent category. Nesting is capped at two levels.

**Category resolution** (`CategoryResolution`) — the sealed result of asking what category an
entry belongs to for analysis purposes: excluded from analysis entirely, included but
Uncategorized, or included under a specific category. See ADR-0007.

**Recurring plan** (`RecurringPlan`) — a template entry plus a recurrence rule, which
`resolvePlans` expands into real entries as their due dates arrive. Distinct from a budget: a plan
produces facts (entries); a budget is pure configuration.

**Occurrence** — one due date of a recurring plan, identified by a deterministic
`OccurrenceID` (UUIDv5 over the plan id and the due date). See ADR-0004.

**Budget** — a monthly spending cap on one category (or on every category, if its `categoryID` is
null), configured as an append-only timeline of `LimitEvent`s rather than a single mutable field.
See ADR-0038.

**LimitEvent** — one entry in a budget's timeline: either a `default` (changes the ongoing limit
from a month forward) or an `override` (pins exactly one month). See ADR-0038.

**Lifecycle state** (`LifecycleState`) — where a row sits in its life: `active`, `archived`
(user-hidden but still referenced), `referenceOnly` (unreferenced and pending purge), or
`tombstoned` (gone, kept only as a deletion marker for sync). See `docs/adr/` for the archival-vs-
deletion split on plans (ADR-0006) and the rule that only delete/restore/purge may move a row
between these states (ADR-0049).

**LedgerChange** — the sealed vocabulary of what a mutation changed: an upsert of an account, a
pocket, a category or an entry, or a deletion of a money source, a category or an entry. See
ADR-0001.

**LedgerError** — the sealed vocabulary of why a mutation was rejected (id collision, unknown
row, zero amount, category kind mismatch, inactive reference, and so on). See ADR-0001.

**Analysis item** (`AnalysisItem`) — one entry's contribution to income/expense analysis, after
resolving its category and applying transfer/treat-as-expense reclassification. Computed by
`Accounting.analysisItems`, never stored.

**Treat-as-expense** — a per-account flag marking the account as money leaving the user's control
(a loan, an overdraft), so a transfer into it counts as spending rather than an internal move. See
ADR-0033.

**Version vector** — a per-row counter-per-device used to order and compare writes for a future
sync engine. Lives only in the persistence layer, never in `packages/domain`. See ADR-0018.

**Invariant** — a rule `LedgerState` checks after every mutation in debug builds
(`assertInvariants`), backstopping illegal states that closed maps and dedicated removers are
meant to make unreachable in the first place. See `docs/specs/ledger-invariants.md`.

## Domain rules with no real alternative (not ADR material)

These are flat conventions applied throughout `packages/domain/`, not decisions with a rejected
alternative — so they live here, not in `docs/adr/`.

- **Money is `Decimal`, never `double`.** A `double` anywhere in `packages/domain/lib/` is a
  defect.
- **IDs are lowercase uuid strings**, normalized at every construction boundary.
- **Int-coded enums carry an explicit `code` field**, never `enum.index` — persistence writes
  these codes, and `enum.index` shifts silently if a variant is ever reordered.
- **Mutators validate, mutate, then return `List<LedgerChange>`.** Every mutation on `LedgerState`
  keeps this contract.

## UI-layer vocabulary (MVVM)

`app/lib/ui` is migrating to strict MVVM. These terms apply only to that layer, not to
`packages/domain`.

**View** — a Flutter widget. Holds no business logic and imports neither `package:domain/` nor any
persistence or data-layer code. Calls named methods on its ViewModel, each taking only raw,
unparsed values — a `String` from a text field, a `bool` from a toggle. It never parses,
validates, or otherwise interprets a value before passing it; that is the ViewModel's job. The
View depends on its ViewModel's abstract interface type, never the concrete class. See ADR-0058.

**ViewModel** — a concrete class implementing an abstract interface declared per screen (for
example, `abstract class BudgetDetailViewModel { Future<void> saveBudget(String rawAmount); }`).
Owns all state and behavior for exactly one View — one screen, or a well-defined section of one. A
thin Riverpod provider wraps each ViewModel for lifecycle and dependency injection only; the
provider is not the ViewModel, it exposes one. Any ViewModel backing a screen that loads data uses
`AsyncNotifier<ViewState>` as its base, so the View renders via `AsyncValue.when(data:, loading:,
error:)` rather than a hand-rolled loading/error representation. "The View never decides what an
input means" is a documented convention here, not tool-enforced — reviewed the same way any other
convention violation is caught.

Every ViewModel backed by the app's single `Ledger` uses the `LedgerBackedNotifier` mixin
(`app/lib/ui/common/ledger_backed_notifier.dart`) rather than repeating its own ledger accessor and
state-update helper. The mixin gives a notifier a `ledger` getter that throws if the ledger is not
ready yet, and an `updateState()` method that applies a transform to the current `ViewState` and
no-ops if the provider has already been disposed — the guard a picker callback needs when its
result arrives after the sheet that launched it is gone. Issue #30 left "should ViewModels share a
base class?" open pending real examples; issue #36 answered it once `AccountsNotifier`,
`AccountFormNotifier`, `SourceEditFormNotifier`, `TransactionsNotifier`, and `EntryFormNotifier` all
turned out to need the same two pieces of boilerplate. A ViewModel with no `Ledger` dependency, or
one needing a genuinely different state-update shape, has no obligation to use this mixin.

**Flow** — a `ConsumerStatefulWidget` that owns one feature folder's own nested `Navigator` (its
own independent route stack), scoped with a `GlobalKey<NavigatorState>` local to that Flow's
State — never shared app-wide. A Flow watches its screens' ViewModels for a `Step` via
`ref.listenManual` and maps each `Step` to a push/pop on its own `Navigator`. The View never
touches navigation; the mapping from `Step` to a concrete pushed screen lives entirely in the
Flow. See ADR-0059.

**Step** — a sealed Dart type declared per Flow (for example, `sealed class BudgetsStep {}` with
a variant `BudgetSelected(String id)`), carrying only plain data, never a `Widget` or
`BuildContext`. A ViewModel emits a `Step?` as part of its `ViewState` when it needs a UI action it
must not decide for itself: a pushed screen, or a launched modal (a picker sheet, `showDatePicker`)
whose raw outcome the Flow reports back to the ViewModel through a named method (for example,
`applyPickedParent(String? id)`). Either way `Step` stays plain data with no Flutter import, so this
does not reintroduce a Flutter dependency into the ViewModel. `Step` consumption is single-shot —
the Flow clears it via the ViewModel's `clearStep()` after acting on it, whether that action was a
push or a modal launch. Replaces the earlier `NavigationIntent` field. See ADR-0059.

A shared presentation widget (in `ui/common` or `ui/format`) is not a View in this sense and owns
no ViewModel of its own: it takes plain values and callbacks as constructor parameters, supplied by
whichever screen's ViewModel is using it. "One ViewModel per View" holds because these shared
widgets never read Riverpod state directly — confirmed by their having zero `ConsumerWidget`,
`ConsumerStatefulWidget`, or `WidgetRef` usage as of this migration's start.

**Model** — `packages/domain` (unchanged, already framework-free) plus the data layer: persistence
today, and any future networking.

## Index

- **`docs/adr/`** — architecture decisions: a decision, the alternative that was rejected, and the
  consequence. Read the ones touching the area you're about to work in before changing it.
- **`docs/specs/`** — behavior contracts (Given/When/Then requirements) for every capability, one
  file per capability. This is where "what must the code do" lives; ADRs hold "why it's built this
  way," not the contract itself.
  - Domain core: `ledger-state.md`, `ledger-mutations.md`, `ledger-lifecycle.md`,
    `ledger-plans.md`, `ledger-invariants.md`, `ledger-accounting.md`, `ledger-analysis.md`,
    `budgets.md`, `data-persistence.md`.
  - Runtime: `ledger-runtime.md`, `event-bus.md`, `analysis-cache.md`, `app-boot.md`.
  - UI: `ui-foundation.md`, `app-shell.md`, `transactions-screen.md`, `entry-form.md`,
    `ocr-receipt-entry.md`, `accounts-screen.md`, `holder-forms.md`, `stats-screen.md`,
    `category-detail.md`, `category-management.md`, `plan-management.md`, `recycle-bin.md`,
    `budgets-ui.md`, `treat-as-expense-buckets.md`, `transfer-scope-display.md`,
    `accessibility-and-localization.md`.
- **`docs/agents/domain.md`** — how an agent should consume this file and `docs/adr/` before
  exploring the codebase.
- **`docs/agents/issue-tracker.md`** — how work items and open questions are tracked (GitHub
  issues via `gh`).
