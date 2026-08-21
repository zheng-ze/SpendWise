# 47. Boot retry invalidates the Riverpod store provider rather than restructuring boot

## Status

Accepted

## Context

An adversarial review found that a failed database open could never be recovered from without
restarting the whole process. `storeProvider` is a plain (non-`autoDispose`) Riverpod provider,
deliberately cached for the container's lifetime — correct for the normal case of one store
instance backing the whole app. But it wraps one `LazyDatabase`, whose internal open-delegate future
caches the *first* open attempt permanently: on error it completes that future with the error but
never clears it, so retry kept replaying the same poisoned future forever, even after the user fixed
whatever caused the original failure.

## Decision

`AppBoot.retry()` calls `ref.invalidate(storeProvider)` (and `ref.invalidate(databaseConnectionProvider)`,
since the poisoned `LazyDatabase` closure captured the old connection future too) before calling
`start()` again. Riverpod disposes the old provider value and rebuilds fresh on the next read,
constructing a brand-new `LazyDatabase` with a clean internal state.

**Alternative considered:** make `DriftLedgerStore`/`LazyDatabase` retryable internally, by clearing
the cached open-delegate on error. Rejected — that means wrapping or forking Drift's own
`LazyDatabase` implementation, more code and more risk than invalidating a Riverpod provider, for
the same outcome.

## Consequences

A user who fixes the underlying condition (frees disk space, grants permission) and taps retry now
gets a genuinely fresh attempt, not a replay of the original failure. Any future provider that
wraps a resource with its own internal failure-caching (as `LazyDatabase` does) needs the same
invalidate-before-retry treatment at its own retry call site — this fix does not generalize
automatically to a new resource added later.
