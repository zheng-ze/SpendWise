# Categories & Classification

Last reconciled: 2026-09-02

## Feature overview

Two things share this feature. The **category model** is a domain value: a labeled income or
expense with one level of nesting, a color, an icon, and a per-category analysis-inclusion flag
gated by its parent. The **category classifier** is an online Naive Bayes model, pre-implementation,
that suggests a category for a new entry from its free-text name and learns per-device from the
user's accept/correct/ignore signals.

## Key files

- `packages/domain/lib/src/entries/transaction_category.dart` — the `TransactionCategory` model.
- `packages/domain/lib/src/entries/category_kind.dart`, `category_resolution.dart` — the kind enum
  and the sealed analysis-resolution result.
- `packages/domain/lib/src/ledger_state/ledger_state_categories.dart` — category mutators and
  validation on `LedgerState`.
- The classifier has no Swift precursor and no implementation source yet; the design below is the
  intended first implementation.

## Category model

A category stores `id`, `name`, `kind` (income/expense, pinned codes), `colorHex` (stored verbatim
so color survives icon-set changes), `includeInAnalysis`, a final `parentID` (one nesting level,
enforced by validator + invariant 5), an SF Symbol `symbol` (opaque to the domain, mapped to a
Material icon by the UI), and `lifecycle`. Validation, in order when a parent is present: parent
exists, parent has no parent (`categoryTooDeep`), and parent kind equals child kind
(`categoryKindMismatch`). A non-active parent is permitted here — opposite to `addPocket` — because
a category's parent is only a naming ancestor and the purge cascade sweeps children regardless of
lifecycle. See `ledger-and-money-model.md` for the lifecycle machine.

Analysis inclusion is parent-gated: a category is `Excluded` from analysis when its own
`includeInAnalysis` is false, or when its present parent's is false.

## Category mutators — `ledger_state_categories.dart`

- **`updateCategory` locks the kind.** It throws `CategoryKindMismatch` when `kind` differs — kind
  is fixed at creation (a who-wants-a-different-kind creates a new category), because a swap would
  strand entries whose sign it contradicts and children that inherit it. It throws `UnknownCategory`
  for a missing id.
- **A subcategory cannot be reparented.** A category with children throws `CategoryTooDeep` on
  `updateCategory`.
- **Reparenting re-judges the abandoned parent.** When `updateCategory` moves the category's
  `parentID`, the parent it drops is re-judged via `_sweepCategory(droppedParent)` (tombstoning it
  if now unreferenced). A same-parent edit drops nothing.
- **`_validateParent`** permits an archived parent, rejects a `referenceOnly` parent
  (`InactiveReference`), rejects a parent that itself has a parent and a self-parent
  (`CategoryTooDeep`), and requires matching kind (`CategoryKindMismatch`).
- **`deleteCategory` / `restoreCategory`** move the tree with `_moveCategoryTree` and do **not**
  cascade plans, so restoring a category does not resurrect a plan that named it.

## Category classifier (online Naive Bayes)

**Model** — one multinomial Naive Bayes per `CategoryKind`, trained independently, per-device,
starting from nothing. `ledger-and-money-model.md` notes the classifier reads `LedgerState` via
`categories`/`CategoryKind` but never writes it and never appears in a `LedgerChange`; a bug can
never corrupt ledger state.

**Tokenization** — lowercase, split on non-alphanumerics, drop tokens under 2 characters, emit
every unigram plus every adjacent bigram (a merchant phrase carries signal its words do not).

**Online update — `observe(name, categoryId)`** — tokenize, increment each token's count and
`totalTokens` by 1, increment `docCount` by 1. One call is O(tokens) and touches only the target
category; a single correction is reflected in the next prediction.

**Prediction — `predict(name)`** — for each active category of the matching kind, compute the
log-likelihood with Laplace (add-one) smoothing, convert to normalized posteriors via softmax, and
return the list sorted descending. When every category has zero documents the degenerates to a
uniform distribution, so cold start falls out of the formula rather than needing a branch.

**Confidence-gated suggestion** — top posterior ≥ 0.6 auto-fills the category (overridable, itself a
training signal); below 0.6 with a non-uniform distribution shows the top 2–3 as chips; a uniform
distribution prompts to create a new category. The 0.6 threshold is a starting point to tune against
real usage.

**Training signals** — an unchanged save is a strong positive; opening the picker and choosing a
different category is an explicit correction logged on the picked category; no interaction is no
signal. A correction is not weighted higher in scoring but is the higher-value case to log.

**Persistence** — each category's `tokenCounts`, `totalTokens`, and `docCount` serialize and store
per-device through the Drift layer, keyed by category id; `observe` updates the blob incrementally,
never rebuilding from a full retraining pass.

## Gotchas and invariants

- The classifier has no invariants of its own to check against `LedgerState.assertInvariants` and
  never emits a `LedgerChange`
- Cold start is the third (no-match) branch, not a special case; a keyword table can be layered in
  later as optional UX polish
- No cloud OCR, no cross-user learning, no embeddings — these are classifier non-goals too, but
  specifically the classifier trains only on this device for this user.

## Requirements

- One Naive Bayes model per `CategoryKind`, trained per-device, updated online so a single
  correction changes the next prediction.
- Suggestion is confidence-gated at 0.6, with a chip tier and a cold-start create prompt.
- Model state persists per-device incrementally through the Drift layer.
- The classifier reads `LedgerState` only; it never mutates it or emits a change.
- `updateCategory` locks `kind` (`CategoryKindMismatch`), forbids reparenting a subcategory
  (`CategoryTooDeep`), and re-judges a dropped parent via `_sweepCategory`.
  (`ledger_state_categories.dart`)
- `deleteCategory` / `restoreCategory` move the category tree and do not cascade plans.
  (`ledger_state_categories.dart`)
