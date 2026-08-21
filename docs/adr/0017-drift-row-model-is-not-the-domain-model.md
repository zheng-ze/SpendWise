# 17. The Drift row model is a separate shape from the domain model

## Status

Accepted

## Context

The persistence schema needs to store domain objects, but a storage row and a domain type serve
different purposes: the row also needs to carry sync machinery (a version vector, a lifecycle
code) the domain knows nothing about, and the two shapes drift apart over time for good reasons.

## Decision

The Drift tables mirror the row shape one-for-one, not the Dart domain types. They are a genuinely
separate model: flattened plan templates (an `EntryTemplate`'s fields become plain columns on the
plan row), integer lifecycle codes, money stored as text, and an encoded version-vector blob. The
mappers in `app/lib/persistence/` are the only place the two models meet.

## Consequences

This is what keeps `packages/domain/` free of persistence concerns and lets the schema carry sync
machinery the domain never has to model. It also means every new domain field that needs
persisting requires an explicit mapper update — there is no automatic serialization keeping the two
shapes in sync, which is the intended cost of keeping them independently evolvable.
