# 32. New account types are appended to the end of the type list, never inserted

## Status

Accepted

## Context

Adding `loan` and `overdraft` as new account types meant deciding where their int codes go. Enum
codes are what persistence actually writes to disk, matching the project's general
int-coded-enum rule. Inserting a new case in the middle of the existing list would silently change
what every already-stored code above the insertion point means — every stored "savings" code could
become "card" with no error anywhere, purely because of where the new case was inserted.

## Decision

`loan` and `overdraft` are appended at the end of `AccountType`'s case list, keeping every existing
code's meaning unchanged. This is the concrete instance of the project-wide rule that enum codes
are pinned explicitly and never rely on declaration order — this is exactly the failure mode that
rule exists to prevent.

## Consequences

Existing stored data's account-type codes remain correct after this change ships. A regression test
confirms data written with the old code set still loads with the same types after the new cases are
added. Any future account type addition must append, never insert, following this same precedent.
