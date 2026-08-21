# 9. Net worth splits assets from liabilities by sign, not by account type

## Status

Accepted

## Context

Computing net worth needs to decide, per account, whether its balance counts as an asset or a
liability. Account type looked like the obvious signal (a savings account is an asset, a credit
card is a liability), but that mapping breaks in exactly the cases that matter most: an overdrawn
debit account is a liability despite its "asset" type, and a credit card sitting in credit is an
asset despite its "liability" type.

## Decision

Net worth splits every account by the sign of its balance, never by consulting `AccountType`. A
zero balance is grouped with the asset branch — arithmetically identical to excluding it, since it
contributes nothing to either side either way.

## Consequences

An account's contribution to net worth can flip sides across its own history purely by its balance
crossing zero, with no change to its type — this is the desired behavior, not a special case to
guard against. Any future net-worth-adjacent calculation must resist the temptation to special-case
by `AccountType`; the sign of the balance is the only signal that is correct in every case checked
so far.
