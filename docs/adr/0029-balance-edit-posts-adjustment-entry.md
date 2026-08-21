# 29. Editing a holder's balance posts an adjustment entry; it never rewrites history

## Status

Accepted

## Context

A user can edit an account or pocket's balance directly from its edit form. The most direct
implementation would set the stored balance field to the new value. But the stored entry log is
the source of truth for every derived balance in this domain — nothing stores a balance as a bare
field — and directly rewriting a balance would disagree with the entry log the moment anything ever
replayed that holder's history, breaking replay consistency permanently.

## Decision

Editing a balance never touches stored entries directly. It posts one new adjustment entry for the
difference between the old and new balance, excluded from analysis (matching how "Opening balance"
entries are also excluded). If the edited value equals the current balance, no entry is posted at
all — a zero-value adjustment entry would be invisible in the UI while still being wrong data, so
this no-delta case has its own explicit test.

## Consequences

A holder's balance history stays fully reconstructable by replaying its entries at any time, with no
special-cased "balance was directly set here" gap. Any future feature that wants to change a
holder's apparent balance must post an entry to do it, never write to a balance field directly — the
entry log is the only source of truth this domain has for money.
