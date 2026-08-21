# 18. A version vector that fails to decode is an error, never an empty vector

## Status

Accepted

## Context

Swift's mapper decoded a stored version vector with `?? VersionVector()` — a corrupt blob silently
became an empty vector. This reads as harmless today because nothing consumes version vectors yet.
It is not harmless: an empty vector claims a row has no write history at all, so once a future sync
engine exists, that row would lose every causal relationship it ever had and would merge as though
it were brand new — silent, undiscoverable-until-too-late data loss.

This is different from an unrecognized *enum* code (account type, lifecycle, category kind,
frequency), where falling back to a documented default is a real, lossless scenario: a row written
by a newer app version can legitimately carry an enum value this version doesn't know about yet,
and defaulting it is forward-compatible. A corrupt version vector is never a legitimate forward-
compatibility case — it is corruption.

## Decision

Version-vector decode failure raises a real, catchable error (`VersionVectorDecodeError`) rather
than substituting an empty vector. Enum decode failure keeps its documented-default fallback,
unchanged.

**Amended by task 7.9 of `add-drift-store` (not implemented as originally planned):** the decode
call was placed only on the *write* path (`_bumpedVersion`, called when a row is next upserted or
tombstoned), not on `load()`. Loading a stored ledger never decodes a row's version vector at all,
since nothing reads vectors until a sync engine exists to consume them, and the boot-retry screen
has no way to repair a corrupt blob — a load that throws on a corrupt vector would produce an
unfixable retry loop rather than a working app. This was a deliberate, user-ruled scope narrowing,
recorded in `openspec/changes/add-drift-store/tasks.md` (now retired along with the rest of
`openspec/`; see `docs/specs/data-persistence.md` for the current spec text and
[GitHub issue tracking the remaining gap](https://github.com/zheng-ze/SpendWise/issues) — the
`_runCycle` catch-all that this interacts with is filed as its own issue, not fixed here).

## Consequences

A corrupt version-vector blob does not block loading the app at all; the app boots and runs
normally against that row. The corruption instead surfaces the next time that specific row is
written — the write throws `VersionVectorDecodeError` at that point, not before. This means a row
that is never written again after becoming corrupt can sit silently corrupt indefinitely with no
user-visible signal; this residual gap, and the closely related "retries forever behind a banner
promising recovery that can't come" defect in the store's error handling, are both intentionally
left to the future sync-engine change rather than fixed here. Any future change to the
version-vector codec must preserve "decode failure is an error," and any change moving the decode
call onto the load path must first resolve how a load-time failure should be surfaced to a user who
cannot fix a corrupt blob from the retry screen.
