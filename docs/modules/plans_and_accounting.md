# Module spec — Recurring Plans + Accounting

**Scope:** `RecurringPlan` / `EntryTemplate` / `RecurrenceFrequency` / `OccurrenceID`, the plan
mutators on `LedgerState` (`addPlan` / `updatePlan` / `deletePlan` / `resolvePlans` /
`removePlansReferencing` + plan validation), and the pure `Accounting` functions (balances,
net worth, analysis classification, roll-up).

**Source of truth:** every rule below was verified against the Swift code on 2026-08-08:
`../SpendWise-SwiftUI/SpendWise/Model/{RecurringPlan,RecurrenceFrequency,OccurrenceID,LedgerState}.swift`
and `Services/{Accounting,Accounting+Analysis}.swift`. This doc is written so the Dart
implementation and its tests need no reference back to Swift. Conventions (Decimal money,
String ids, sealed classes, name parity) follow the master doc `../Flutter_Port_Tech_Doc.md`.

---

## 1. RecurringPlan and EntryTemplate

### 1.1 Types

```dart
class EntryTemplate {
  Decimal amount;          // signed: expense negative, income positive
  String name;
  String? categoryID;      // default null
  String sourceID;
  String? destinationID;   // non-null => generated entries are transfers
  bool includeInAnalysis;  // default true
}

class RecurringPlan {
  final String id;
  EntryTemplate template;
  RecurrenceFrequency frequency;
  DateTime anchor;             // first occurrence, full timestamp
  DateTime? endDate;           // null = open-ended
  DateTime lastResolvedDate;   // forward-only cursor, see 1.5
}

class PlanFailure {
  final String planID;
  final DateTime occurrence;
  final Object error;          // the LedgerError thrown by entry validation
}
```

`EntryTemplate` participates in holder-reference queries: `holderIDs = {sourceID} ∪
{destinationID if present}`, `touches(ids) = holderIDs ∩ ids ≠ ∅`. Used by the
delete-account cascade (1.8).

### 1.2 Entry generation (`makeEntry`)

For plan `p` and occurrence timestamp `date`:

| Entry field | Value |
|---|---|
| `id` | `OccurrenceID.make(p.id, date)` — deterministic, see §3 |
| `date` | `date` as-is (occurrences keep the anchor's time-of-day) |
| `amount, name, categoryID, sourceID, destinationID, includeInAnalysis` | copied from template |
| `lifecycle` | active |

The generated entry then goes through the **normal entry validator** (`validated(entry)`),
which can rewrite it: a transfer template with negative amount is normalized to positive
amount with source/destination swapped. The deterministic `id` is preserved through that
rewrite.

### 1.3 `occurrences(after: from, upTo: to)` — exact boundary semantics

The k-th occurrence is **always computed from the anchor**, never by stepping from the
previous occurrence: `occurrence(k) = anchor + frequency.step(k)` (see §2). Algorithm:

```
ceiling = endDate == null ? to : min(endDate, to)
if (ceiling < anchor) return []            // includes the backward-clock case
result = []
for k = 0, 1, 2, ...:
    d = anchor + step(k)
    if d > ceiling: break                  // ceiling is INCLUSIVE (d == ceiling emits)
    if d > from: result.add(d)             // from is EXCLUSIVE (d == from is skipped)
return result
```

Contract summary:

| Boundary | Rule |
|---|---|
| `from` | strictly after: occurrence exactly equal to `from` is **not** emitted |
| `to` | inclusive: occurrence exactly equal to `to` **is** emitted |
| `endDate` | inclusive: an occurrence landing exactly on `endDate` is the plan's last emission |
| ceiling | `min(endDate, to)` when `endDate` set, else `to` |
| `to < anchor` | empty list (also covers a clock that moved backward past the cursor) |
| anchor itself | emitted iff `anchor > from` (k = 0 is a real occurrence) |

Dates are compared as instants. All plan date math runs on a fixed calendar (§3.3 decision:
UTC), injected, never `DateTime.now()` inside the domain.

### 1.4 `nextOccurrence(onOrAfter: reference)`

First `anchor + step(k)` (k = 0, 1, 2, …) with `date >= reference` — note **on-or-after**,
unlike `occurrences` which is strictly-after. Returns `null` if that date would exceed
`endDate` (an occurrence exactly equal to `endDate` is still returned). Used by UI ("next
charge on …"), not by resolution.

### 1.5 `lastResolvedDate` — forward-only cursor

- The seed value is the caller's choice; the domain only requires `lastResolvedDate <
  endDate` at write time (1.7). The established convention (used by every Swift test) is
  seeding it to the anchor, which means **the anchor occurrence itself is never emitted**
  (strictly-after semantics): a plan seeded `lastResolvedDate = anchor` starts emitting at
  anchor + 1 step. To have the anchor occurrence emitted, seed the cursor before the anchor.
- `resolvePlans` is the only code that advances it, and it always advances it to `now`
  (never backward, never to the last occurrence).
- A stale cursor is harmless: replaying `occurrences(after: cursor, upTo: now)` with an old
  cursor re-derives only occurrences whose deterministic entry ids already exist, and those
  are skipped (1.6). This is why a plan with nothing due is not re-persisted.

### 1.6 `resolvePlans(now, calendar)` — the mutator

Signature (on `LedgerState`):

```dart
({List<LedgerChange> changes, List<PlanFailure> failures})
    resolvePlans({required DateTime now, required CalendarLike calendar})
```

For **each** plan (iteration order unspecified — tests must not depend on cross-plan order):

1. `due = plan.occurrences(after: plan.lastResolvedDate, upTo: now)`.
2. For each due date, in chronological order:
   - Build the entry via `makeEntry` (deterministic id).
   - **If an entry with that id already exists → skip silently.** (Dedupe before validation:
     an occurrence already materialised — locally or via future sync — is neither duplicated
     nor reported as a failure.)
   - Run full entry validation (`validated`). On success: insert entry, append
     `LedgerChange.upsertEntry(entry)`. On error: append
     `PlanFailure(planID, occurrence, error)` and **continue with the remaining
     occurrences** — one bad occurrence does not abort the plan or the batch.
3. Advance a copy of the plan: `advanced.lastResolvedDate = now`.
4. Retirement / persistence decision:
   - `advanced.isExhausted(asOf: now)` → **retire**: remove the plan from `plans`, append
     `LedgerChange.deletePlan(planID)`. No `upsertPlan` is emitted even if step 2 just
     emitted entries (the final occurrences and the retirement land in one batch).
   - else if `due` is non-empty → store `advanced` and append
     `LedgerChange.upsertPlan(advanced)`.
   - else (**nothing due, not exhausted**) → the plan is left completely untouched: the
     in-memory cursor keeps its old value and **no change is emitted, so the plan is not
     re-persisted**. Safe because of 1.5: replay from the stale cursor is a no-op.

Behavioral consequences that MUST hold (they are tested):

- Calling `resolvePlans` twice with the same `now` creates no duplicate entries.
- A resolve with nothing due returns `changes == []` (not even a plan upsert).
- **Failures are report-once, not retried.** When `due` is non-empty, the cursor advances to
  `now` even if some (or all) occurrences failed validation. A failed occurrence is behind
  the cursor afterward and will never be attempted again. The `PlanFailure` list is the only
  record — the caller (Ledger → error banner) must surface it, never drop it.
- `PlanFailure` is only for **validation** failures (e.g. template pointing at an archived
  holder or category, category kind mismatch). A plan simply reaching its `endDate` is
  silent and expected — retirement, not failure.

### 1.7 `isExhausted(asOf: now)` and plan validation

```
isExhausted(now) = endDate != null && endDate < now && lastResolvedDate >= endDate
```

Both strict/inclusive choices matter: at `now == endDate` the plan is *not yet* exhausted
(a same-instant occurrence may still be due); once the cursor has reached `endDate` and time
has passed it, the plan can never emit again.

`validate(plan)` — run by `addPlan` and `updatePlan`, throwing `LedgerError`:

| Check | Error |
|---|---|
| `template.sourceID` exists in `moneySources` | `unknownHolder(id)` |
| `template.sourceID` lifecycle is active | `inactiveReference(id)` |
| `template.destinationID` (if set) exists | `unknownHolder(id)` |
| `template.destinationID` (if set) active | `inactiveReference(id)` |
| `template.categoryID` (if set) exists in `categories` | `unknownCategory(id)` |
| `template.categoryID` (if set) lifecycle `== active` | `inactiveReference(id)` |
| `endDate != null && lastResolvedDate >= endDate` | `exhaustedPlan(plan.id)` — an already-exhausted plan cannot be written |

Note what plan validation does **not** check: category kind vs. amount sign, zero amount,
self-transfer. Those are entry-validator concerns and surface later as `PlanFailure`s at
resolve time. Port this asymmetry as-is.

Mutators:

- `addPlan(plan)` — throws `idCollision(id)` if the id exists, else validate, insert, return
  `[upsertPlan(plan)]`.
- `updatePlan(plan)` — throws `unknownPlan(id)` if absent, else validate, replace, return
  `[upsertPlan(plan)]`.
- `deletePlan(id)` — **hard delete, no lifecycle**: absent id returns `[]` (no throw);
  otherwise remove and return `[deletePlan(id)]`. Plans are regenerable config, not history —
  they never enter the recycle bin.

### 1.8 Cascade: `removePlansReferencing(ids) -> List<String>`

Private helper: removes every plan whose `template.touches(ids)` and returns the removed ids.
Called from **exactly one place**: `deleteAccount(id)`, with
`scope = {accountID} ∪ account.subPocketIDs`; the caller maps the result to
`deletePlan` changes appended to the archive batch.

Deliberate asymmetries (verified, port as-is):

- `deletePocket` (archiving a pocket directly) does **not** remove plans referencing it.
- `deleteCategory` does **not** remove plans referencing the category.
- In both cases the plan survives and its next `resolvePlans` emits
  `PlanFailure(inactiveReference)` per due occurrence — the user-visible signal to fix or
  delete the plan.

---

## 2. RecurrenceFrequency stepping

```dart
enum RecurrenceFrequency { weekly, biweekly, monthly, quarterly, yearly }
// persisted as int: weekly=0, biweekly=1, monthly=2, quarterly=3, yearly=4
```

The k-th stride, applied to the **anchor** (never iteratively):

| Frequency | `step(k)` (Swift `DateComponents`) | Dart equivalent |
|---|---|---|
| weekly | `day: 7k` | add `7k` calendar days |
| biweekly | `day: 14k` | add `14k` calendar days |
| monthly | `month: k` | `addMonthsClamped(anchor, k)` |
| quarterly | `month: 3k` | `addMonthsClamped(anchor, 3k)` |
| yearly | `year: k` | `addMonthsClamped(anchor, 12k)` |

Time-of-day is preserved by every step (occurrences inherit the anchor's clock time; only
occurrence *identity* collapses to a day, §3).

### 2.1 The month-end clamping contract (CRITICAL)

Foundation's `calendar.date(byAdding: .month)` clamps the day to the target month's length
(Jan 31 + 1 month → Feb 28, or Feb 29 in a leap year). **Dart's `DateTime` does the
opposite** — `DateTime(2026, 2, 31)` silently rolls over to March 3. Never construct
stepped dates with raw component arithmetic.

Required helper (pure Dart, in `domain`):

```dart
/// Adds [months] to [date], clamping the day-of-month to the target month's
/// length. Preserves time-of-day. Total months = date.month + months is
/// normalized into (year, month) without day rollover.
DateTime addMonthsClamped(DateTime date, int months);
```

Behavior:

1. Compute target `(year, month)` by pure month arithmetic (handle negative months too).
2. `day = min(date.day, daysInMonth(targetYear, targetMonth))`.
3. Rebuild with the original hour/minute/second (and the calendar's timezone, §3.3).

Because stepping is always anchor-relative, **the day component "recovers" after a short
month**: Jan 31 monthly → Feb 28 → Mar 31 → Apr 30. An iterative implementation
(Feb 28 + 1 month = Mar 28) is WRONG and the matrix below catches it.

Same helper must also be used for card `statementCut` math (master doc §1 defect 3) — one
clamp implementation, two call sites.

### 2.2 `addMonthsClamped` test matrix (all required)

| Input | +months | Expected | Proves |
|---|---|---|---|
| 2026-01-31 | 1 | 2026-02-28 | 31 → short non-leap Feb |
| 2024-01-31 | 1 | 2024-02-29 | 31 → leap Feb |
| 2026-01-31 | 2 | 2026-03-31 | day recovers after clamp (anchor-relative) |
| 2026-01-31 | 3 | 2026-04-30 | 31 → 30-day month (quarterly k=1 shape) |
| 2026-01-30 | 1 | 2026-02-28 | 30 → non-leap Feb |
| 2024-01-30 | 1 | 2024-02-29 | 30 → leap Feb |
| 2026-01-29 | 1 | 2026-02-28 | 29 → non-leap Feb |
| 2024-01-29 | 1 | 2024-02-29 | 29 fits exactly in leap Feb (no clamp) |
| 2026-01-28 | 1 | 2026-02-28 | 28 never clamps |
| 2026-03-31 | 1 | 2026-04-30 | 31 → April |
| 2026-12-31 | 1 | 2027-01-31 | year rollover, no clamp |
| 2024-02-29 | 12 | 2025-02-28 | yearly from leap day → non-leap year |
| 2024-02-29 | 48 | 2028-02-29 | yearly leap day → leap year (recovers) |
| 2026-10-31 | 1 | 2026-11-30 | 31 → November |

Plus the plan-level test already in the Swift suite: monthly anchor 2026-01-31,
`occurrences(after: 2026-01-31, upTo: 2026-02-28)` → exactly `[2026-02-28]`.

Weekly/biweekly need no clamping (day addition never overflows a month, it just carries),
but keep them on calendar-day arithmetic in the same timezone so a future DST-affected zone
choice cannot shift the time-of-day.

---

## 3. OccurrenceID — deterministic entry ids

Purpose: two devices resolving the same (plan, day) occurrence must mint the **same** entry
id, so a future sync merge converges on one entry instead of duplicating it. The namespace
is a fixed public app constant — convergence comes from the shared planID, not from secrecy.

### 3.1 Exact algorithm (must match Swift byte-for-byte)

```
NAMESPACE = 8B9E0C42-5F3A-4D71-9C2E-1A6B7F0D3E85   (a UUID, used as raw 16 bytes)

make(planID, occurrenceDay, calendar):
  day     = calendar.startOfDay(occurrenceDay)             // §3.3: UTC
  seconds = round(day - 2001-01-01T00:00:00Z) as integer   // Apple "reference date" epoch,
                                                           // NOT the Unix epoch
  name    = "<planID uppercase canonical uuid string>|<seconds>"
            // e.g. "11111111-2222-3333-4444-555555555555|794016000"
  digest  = SHA1( namespace_bytes(16) ++ utf8(name) )
  bytes   = digest[0..15]                                  // first 16 of the 20 SHA-1 bytes
  bytes[6] = (bytes[6] & 0x0F) | 0x50                      // version 5
  bytes[8] = (bytes[8] & 0x3F) | 0x80                      // RFC 4122 variant
  return UUID(bytes)
```

This is standard RFC 4122 UUIDv5, so Dart's `Uuid().v5(namespace, name)` implements the
hashing correctly — the port's obligations are the **inputs**:

1. Namespace exactly `8B9E0C42-5F3A-4D71-9C2E-1A6B7F0D3E85`.
2. planID rendered **uppercase** in the name (Swift `uuidString` is uppercase; Dart uuids are
   lowercase strings — `planID.toUpperCase()` at this one boundary). Everywhere else in the
   port ids stay lowercase (master doc §5 hazard 5); this name string is the sole exception.
3. Seconds since **2001-01-01T00:00:00Z** (Apple reference date), integral, of the start of
   day. Unix-epoch seconds minus `978307200`.
4. The literal `|` separator, no whitespace.
5. The resulting id, when stored/compared as a Dart string, is lowercased like every other id.

### 3.2 Pin test (required, exact values verified by running the Swift implementation)

```dart
test('OccurrenceID matches the Swift implementation byte-for-byte', () {
  final id = OccurrenceID.make(
    planID: '11111111-2222-3333-4444-555555555555',
    occurrenceDay: DateTime.utc(2026, 3, 1),        // any time within the UTC day
  );
  // name string must be "11111111-2222-3333-4444-555555555555|794016000"
  expect(id, 'cca271e1-a2dc-56cf-9462-a710c0c21922');
});
```

Derivation of the pinned values: 2026-03-01T00:00:00Z is 794,016,000 seconds after
2001-01-01T00:00:00Z; SHA-1 over namespace bytes + that name, masked per §3.1, yields
`CCA271E1-A2DC-56CF-9462-A710C0C21922` (verified against both the Swift `OccurrenceID` code
and an independent RFC 4122 implementation on 2026-08-08).

Also port the behavioral tests: same inputs → same id; two timestamps within the same day →
same id (intra-day jitter collapses); different day → different id; different plan → different id.

### 3.3 Timezone decision (RECORDED, required by master doc §5 hazard 3)

`startOfDay` is timezone-dependent: local midnight in SGT is a different instant (and a
different `seconds` value) than UTC midnight, producing a different id for the "same" day.
The Swift app fed whatever calendar the caller supplied (tests: UTC; production: the device
calendar), so a timezone move could in principle re-mint ids.

**Decision for the Dart port: all plan/occurrence date math is UTC.** Anchors and occurrence
timestamps are handled as UTC instants; `startOfDay` = `DateTime.utc(d.year, d.month, d.day)`
on the UTC representation of the occurrence instant. Consequences:

- Ids are stable under device timezone changes and identical across all six platforms.
- The §3.2 pin test doubles as the normalization test; add one more: an occurrence instant of
  `2026-03-01T20:00:00Z` and `2026-03-01T00:00:00Z` produce the same id, and
  `2026-02-28T23:59:59Z` does not.
- Migration caveat (accepted): data exported from a native app whose ids were minted with a
  non-UTC device calendar would carry different ids for the same logical occurrences. The
  algorithm is byte-compatible; day-boundary normalization is what must agree. If a Realbyte
  or native-app import ever ships, imported entries keep their imported ids verbatim — no
  re-derivation — so this never corrupts data.

---

## 4. Accounting — pure balance functions

All functions are pure and static (`Accounting` namespace class in Dart). Money is `Decimal`
throughout. Balances are always derived from the full entry log, never stored.

### 4.1 `applies(entry, sourceIDs) -> bool` — the gating primitive

```
if entry.sourceID not in sourceIDs: false
if entry.destinationID == null:     true
else:                               entry.destinationID in sourceIDs
```

A transfer counts **only when BOTH endpoints are in the set**. `sourceIDs` as passed by the
production callers (`netWorth`, `analysisItems`) is the **existence set** — every key of
`moneySources`, including archived and referenceOnly holders. It is *not* the active set.
The thing that un-applies an entry is a holder being tombstoned (removed from the map
entirely): the two `deleted…UnappliesTransferToSurvivor` tests pass a set missing one
endpoint and expect the survivor's balance to spring back.

### 4.2 `balance(of: sourceID, entries, sourceIDs) -> Decimal`

Sum over entries passing `applies`, per-entry delta:

| Entry kind | Condition | Delta |
|---|---|---|
| transfer (`destinationID != null`) | `destinationID == sourceID` | `+amount` |
| transfer | `sourceID == sourceID` | `-amount` |
| transfer | neither endpoint is this holder | `0` |
| income/expense | `sourceID == sourceID` | `+amount` (amount is signed: expense entries are negative) |
| income/expense | other holder | `0` |

(Transfer amounts are always positive after entry normalization; self-transfer is
impossible by validation, so the two transfer branches never both match.)

### 4.3 `accountTotal(account, entries, sourceIDs, activePockets) -> Decimal`

`balance(account.id)` plus `balance(pocketID)` for every `pocketID` in
`account.subPocketIDs ∩ activePockets`. Archived pockets stay in `subPocketIDs` (so they
can be restored) but their balance drops out of the parent total via the `activePockets`
filter. Funding a pocket from its own parent is total-neutral (internal transfer nets to
zero at the account level); spending *from* the pocket reduces the total.

### 4.4 `netWorth(ledger) -> NetWorth{asset, liability}`

```
sourceIDs     = all moneySources keys        (existence set, incl. archived)
activePockets = ledger.activeSources         (lifecycle == active only)
for each moneySource that is an ACCOUNT:
    skip unless account.lifecycle == active AND account.includeInNetWorth
    total = accountTotal(account, entries, sourceIDs, activePockets)
    total < 0  → liability += -total         (liability is a POSITIVE magnitude)
    total >= 0 → asset += total              (zero contributes nothing, to the asset side)
```

Rules that the tests pin:

- Split is **by sign of the computed total, not by account type** — an overdrawn card is a
  liability because its total is negative, not because it is a card.
- Pockets are never counted at top level; their money enters via the parent's
  `accountTotal` (money set aside in a pocket still belongs to the account).
- `includeInNetWorth == false` accounts are skipped entirely.
- Archived accounts are skipped (active gate), but they remain in `sourceIDs`, so transfers
  into them still apply to the *counterparty's* history consistently.
- Account-to-account transfers are net-worth-neutral.
- Empty ledger → `asset == 0 && liability == 0`.

---

## 5. Analysis classification

### 5.1 `AnalysisItem`

```dart
class AnalysisItem {
  final String? bucketID;   // leaf category id, or null = the "Uncategorized" bucket
  final Decimal amount;     // ALWAYS positive (see classify)
  final DateTime date;
  final CategoryKind kind;  // income | expense
}
```

### 5.2 `analysisItems(ledger) -> List<AnalysisItem>` — the single gated pass

One pass over all entries, `sourceIDs` = all `moneySources` keys, mapping each entry through
`classify` and dropping nulls. This is the expensive, window-independent computation — it is
what `AnalysisCache` caches; consumers filter the result cheaply (5.4). Output order is
unspecified (map-values iteration); tests must sort or use set semantics.

### 5.3 `classify(entry, sourceIDs, ledger) -> AnalysisItem?`

```
1. gate: applies(entry, sourceIDs) AND entry.includeInAnalysis, else null
2. switch entry.kind:
   transfer:
     destination holder exists AND holder.incomingTransfersAsExpenses == true
       → AnalysisItem(bucketID: null, amount: entry.amount (as stored, positive),
                      date: entry.date, kind: expense)
     else → null            // plain transfers never reach analysis
   income | expense:
     resolution = resolveCategory(entry, ledger)      // sealed, below
     Excluded        → null                            // dropped entirely
     Uncategorized   → item with bucketID: null
     Category(id)    → item with bucketID: id
     kind = entry.kind mapped to CategoryKind   // decided by the sign of the STORED, SIGNED
                                                // amount (Swift's expectedCategoryKind)
     amount = abs(entry.amount)                 // computed separately, after kind
```

Entry kind recap (defined on `Entry`): `destinationID != null` → transfer; otherwise sign of
amount decides (`< 0` expense, else income; zero amounts cannot exist — validation rejects
them).

`incomingTransfersAsExpenses` is a per-holder flag readable on both accounts and pockets.
The treat-as-expense item keeps the transfer's stored (positive) amount and carries **no
category** — see §7 for the recorded future change.

### 5.4 Category resolution — sealed result (replaces Swift's `UUID??`)

Swift encodes this as a double optional: `nil` = excluded, `.some(nil)` = Uncategorized,
`.some(id)` = that category. Per the master doc, Dart models it explicitly:

```dart
sealed class CategoryResolution {}
class Excluded      extends CategoryResolution {}          // drop the entry from analysis
class Uncategorized extends CategoryResolution {}          // bucketID: null
class InCategory    extends CategoryResolution { final String id; }
```

Resolution rules, in order:

| Condition | Result |
|---|---|
| `entry.categoryID == null` | `Uncategorized` |
| categoryID set but **not present** in `ledger.categories` (tombstoned away) | `Uncategorized` (graceful fallback, never a crash) |
| `category.includeInAnalysis == false` | `Excluded` |
| `category.parentID` set, parent present, `parent.includeInAnalysis == false` | `Excluded` (parent gate overrides child's own true flag) |
| otherwise | `InCategory(categoryID)` |

Note the lifecycle nuance: an **archived** category (still in the map) is not special-cased —
its entries still bucket under its id (`archivedCategoryStillBucketsUnderItsID`). Only true
absence from the map falls back to Uncategorized.

### 5.5 Filtering, totals, fraction

List helpers (extension methods on `List<AnalysisItem>` in Dart):

```dart
List<AnalysisItem> filtered({CategoryKind? kind, Set<String?>? buckets, DateRange? interval});
Decimal total({CategoryKind? kind, Set<String?>? buckets, DateRange? interval});
```

- Each null parameter means "no constraint".
- `buckets` is a set of **nullable** ids so the Uncategorized bucket (`null`) is selectable
  alongside real category ids.
- `interval` uses half-open **`[start, end)`** semantics (`start <= item.date < end`) — the
  ruled convention for ALL window filters in the Dart port (master doc §5 hazard 8). This is a
  **FLAGGED SANCTIONED DEVIATION** from Swift: Foundation's `DateInterval.contains` was
  inclusive of both endpoints, so an entry timestamped exactly on a month boundary could
  double-count in both windows — a latent bug, never observed because real entries do not land
  on exact boundary instants. Swift behavior for reference: `start <= item.date <= end`.
  Required boundary test: an entry exactly at the month-end instant appears in exactly one
  window.
- `total` = sum of `amount` over `filtered` (starts at zero).

```dart
double fraction(Decimal amount, Decimal over) // over <= 0 → 0.0, else (amount/over).toDouble()
```

Presentation-only (pie slice angles); the guard covers both empty and pathological negative
totals.

### 5.6 Roll-up to main buckets

```dart
String? mainBucketID(String? leafID, LedgerState state)
// leafID null, or not present in state.categories → null (Uncategorized stays its own bucket)
// otherwise → category.parentID ?? leafID           (child folds into parent; a parent or
//                                                    root category is its own main bucket)

Map<String?, Decimal> rollUp(List<AnalysisItem> items, LedgerState state)
// groups item.amount sums by mainBucketID(item.bucketID); null is a legal key
```

Pinned behaviors: parent-direct spend and child spend fold into one parent bucket
(`sums[parent] == direct + child`); drill-down math is done by bucket-set totals
(`total(buckets: {parent, child})` vs `total(buckets: {child})`); uncategorized forms its
own `null`-keyed bucket.

---

## 6. Test inventory for Dart parity

Port every test below (same scenario, same name adapted to Dart casing). Domain package,
`package:test`. Helper parity: a UTC calendar fixture, `date(y, m, d)` builder, and small
`account/pocket/category/txn/transfer` factories as in the Swift files.

### 6.1 From `RecurringPlanTests.swift`

**Occurrence generation (9):**

| Test | Pins |
|---|---|
| monthlyEmitsOneOccurrencePerMonth | 15 Jan anchor, resolve to 15 Apr → [15 Feb, 15 Mar, 15 Apr] |
| monthlyFromJan31ClampsToFeb | Jan 31 anchor, upTo Feb 28 → [Feb 28] (THE clamp test — write first) |
| biweeklyStridesFourteenDays | Jan 1 anchor, upTo Feb 1 → [Jan 15, Jan 29] |
| quarterlyStridesThreeMonths | Jan 1 anchor, upTo Dec 31 → [Apr 1, Jul 1, Oct 1] |
| endDateCapsOccurrences | endDate Mar 1, upTo Dec 1 → [Feb 1, Mar 1] (endDate occurrence emitted) |
| backwardClockEmitsNothing | upTo before the cursor → [] |
| nextOccurrenceReturnsAnchorWhenReferenceIsBefore | onOrAfter is on-or-after; anchor is k=0 |
| nextOccurrenceSkipsPastOccurrences | Jan 10 anchor, ref Mar 15 → Apr 10 |
| nextOccurrenceIsNilAfterEndDate | ref past endDate → null |

**OccurrenceID (4):** sameInputsProduceSameID, intraDayJitterDoesNotSplitID (+20 h same day),
differentDatesProduceDifferentIDs, differentPlansProduceDifferentIDs.

**resolvePlans (7):**

| Test | Pins |
|---|---|
| resolveMaterialisesEntriesAndAdvancesCursor | 3 upsertEntry changes, cursor == now |
| secondResolveEmitsNoDuplicateEntries | entry count stable across re-resolve |
| generatedEntryIDIsDeterministic | `entries[OccurrenceID.make(planID, day)]` exists |
| deletingHolderCascadesToPlan | deleteAccount removes plan, emits deletePlan |
| exhaustedPlanIsRetiredAfterItsFinalOccurrence | 2 entries + deletePlan, NO upsertPlan, failures empty |
| planWithNothingDueIsNotRePersisted | changes == [] |
| addingAnAlreadyExhaustedPlanIsRejected | addPlan throws exhaustedPlan |

### 6.2 From `AccountingTests.swift` (16)

Balance/gating: balanceNetsSignedTransactions, transactionOnlyAffectsItsOwnHolder,
transferMovesBetweenHolders, deletedHolderUnappliesTransferToSurvivor,
deletedSourceUnappliesTransferToSurvivor.

Account totals/pockets: fundingPocketMovesOwnCashButNotAccountTotal,
spendingFromPocketReducesPocketAndTotal, pocketToPocketAcrossAccountsMovesBothTotals,
multiplePocketsSumIntoAccountTotal, archivedPocketDropsOutOfAccountTotal.

Net worth: netWorthSplitsBySignNotType, netWorthExcludesFlaggedAccount,
netWorthCountsPocketBalances, netWorthExcludesArchivedAccount,
accountToAccountTransferIsZeroSumForNetWorth, emptyLedgerNetWorthIsZero.

### 6.3 From `AccountingAnalysisTests.swift` (17)

Classification gates: normalExpenseProducesItemWithAbsoluteAmount, incomeProducesNoExpenseItem,
plainTransferProducesNoExpenseItem, transferIntoTreatAsExpenseHolderProducesItem,
excludedFromAnalysisEntryProducesNoItem, categoryExcludedFromAnalysisHidesItsExpenses,
parentExcludedFromAnalysisHidesChildExpenses, uncategorizedExpenseIsIncluded,
archivedCategoryStillBucketsUnderItsID, unresolvableCategoryRendersAsUncategorized.

Income totals: incomeSumsPositiveNonTransferEntries, incomeIgnoresTransfersAndExcludedEntries.

Kind tagging: analysisItemsTagExpenseAndIncomeSeparately,
analysisItemsIncomeHonorsAnalysisExclusion.

Roll-up: rollUpFoldsSubcategoriesIntoParent, rollUpBucketsTotalsPerChildAndDirect,
rollUpUncategorizedFormsOwnBucket.

### 6.4 New Dart-only tests (this module's port additions)

1. The full `addMonthsClamped` matrix (§2.2) — 14 cases.
2. The OccurrenceID pin test (§3.2) with the exact triple, plus the UTC-boundary test (§3.3).
3. A resolvePlans failure test: plan whose category was archived after `addPlan` → resolve
   returns a `PlanFailure` per due occurrence, emits no entry for the failed occurrences,
   still advances/persists the cursor (report-once semantics, 1.6). The Swift suite covers
   failure *shape* only implicitly; pin it explicitly in Dart.
4. Anchor-relative stepping guard: monthly anchor Jan 31, `occurrences(after: Jan 31,
   upTo: Apr 30)` → [Feb 28, Mar 31, Apr 30] — fails if stepping is iterative.

---

## 7. Known gap — do NOT silently build during the port

**Treat-as-expense transfer bucketing is unfinished by design** (master doc §1 defect 7).

Current behavior — port exactly this: a transfer into a holder with
`incomingTransfersAsExpenses == true` classifies as an expense `AnalysisItem` with
`bucketID: null`, i.e. it lands in the **Uncategorized** bucket of the stats donut
(`transferIntoTreatAsExpenseHolderProducesItem` pins `bucketID == nil`).

Recorded future decision (locked, from the Realbyte-parity analysis): these items should
bucket by the **destination account's TYPE** (e.g. all transfers into investment-type
accounts form an "Investments" analysis bucket) — by account type, **not** by holder name,
and the treat-as-expense toggle should be restricted to eligible account types (incl. loan
and overdraft cases).

Rules for this module:

- Phase 2 ports `classify` with `bucketID: null` for these items, byte-identical to Swift,
  and the parity test asserts it.
- The account-type bucketing ships as a **feature in Phase 6**, with its own tests and a
  revision to this spec — never as an "improvement" slipped into the port. A port diff that
  changes this behavior is a defect.
