# 10. Self-transfers are legal, and the treat-as-expense flag reads symmetrically

## Status

Accepted

## Context

The Swift original threw a `selfTransfer` error whenever a transfer's destination equaled its
source, and its treat-as-expense reclassification (`incomingTransfersAsExpenses`) read the flag
only off the transfer's destination, emitting at most one expense item. Real banking behavior
contradicts the first rule directly: a Singapore PayNow transfer to yourself deducts from an
account and credits the same account, appears on the bank statement, and has to be recordable in
this app. This was ruled during Phase 2 at the user's direction — a deliberate product behavior
change, not a porting defect and not deferred Phase 6 parity work.

## Decision

Two changes, both deliberate deviations from the Swift original:

1. The `selfTransfer` validation throw is removed, and the `SelfTransfer` error case is deleted
   outright (it only ever fed `toString()`, nothing persists it).
2. `classify` reads the treat-as-expense flag off **both ends** of a transfer independently: a
   transfer **in** to a flagged holder is an expense, a transfer **out of** one is income. Each
   leg reads the flag off its own end, so both, one, or neither may fire — there is deliberately no
   special-cased `sourceID == destinationID` branch, since the two-sided read already produces the
   right answer (a self-transfer between accounts with the same flag setting nets to zero,
   matching the zero it already nets to in `balance`).

`classify` returns `List<AnalysisItem>` instead of a nullable single item specifically to allow the
flagged-to-flagged case: a transfer between two flagged holders emits an expense on the destination
leg and an income on the source leg — two genuine items on two different holders, which a nullable
single item cannot express.

Account-type bucketing for these treat-as-expense transfers stays deferred to a later phase;
`bucketID` remains null on both legs until that phase resolves it.

## Consequences

A self-transfer between two ordinary accounts is fully legal and analyzes as a wash. A self-transfer
into or out of a treat-as-expense holder can produce a genuine income or expense item even though
no money left the user's control — this is intentional, since the flag's whole purpose is to treat
money moved to that kind of holder as spent. Any future analysis code touching transfers must read
the treat-as-expense flag per-leg, never assume a transfer produces at most one item.
