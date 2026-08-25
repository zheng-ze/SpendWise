# 4. Occurrence ids are UUIDv5 over a lowercase-normalized plan id

## Status

Accepted

## Context

A recurring plan needs a stable, deterministic id per occurrence (one per due date) so the same
occurrence is recognized across resolutions rather than re-minted. The `uuid` package already
used elsewhere in the domain exposes `v5` (SHA-1-based), so no new dependency was needed. Swift
built the UUIDv5 name string from `planID.uuidString`, which Foundation renders **uppercase**, and
measured the date in seconds from 2001-01-01 UTC (the Foundation reference date, not the Unix
epoch).

Every id in this domain is normalized to lowercase at every construction boundary (see the
lowercase-id-normalization rule), specifically so that no id's identity depends on the case it
happened to be written in.

## Decision

The plan id goes into the UUIDv5 name string in lowercase normalized form, not the uppercase form
Swift's `uuidString` produces. The name string is still measured in seconds from 2001-01-01 UTC,
matching Swift's reference point.

Because a UUIDv5 name is hashed bytewise, lowercase and uppercase of the same id are different
names. Occurrence ids are this app's own identity scheme: nothing requires them to match ids
produced by any other system for the same plan and day, so there was no byte-for-byte conformance
target to preserve. Uppercasing the plan id to match Swift's `uuidString` convention would mean
reintroducing an uppercase id at exactly the boundary the lowercase-normalization rule exists to
close.

## Consequences

Every future change to occurrence-id derivation must keep the plan id normalized to lowercase on
the way into the UUIDv5 name, regardless of how the rest of the derivation evolves.
