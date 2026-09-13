# SpendWise Review Rules

SpendWise is a cross-platform personal finance application. Reviews should prioritize correctness, regressions, data integrity, security, and behavioral edge cases over style or subjective refactoring preferences.

## Review priorities

Prioritize findings in roughly this order:

1. Incorrect financial behavior
2. Data loss or persistence corruption
3. Sync divergence or conflict-resolution errors
4. Security or privacy issues
5. Platform-specific regressions
6. Broken user flows or state-management bugs
7. Missing important tests
8. Maintainability issues that create a concrete correctness risk

Do not spend review comments on formatting or lint issues already handled by automated tooling.

Do not recommend speculative abstractions or large refactors unless they solve a concrete problem introduced or exposed by the PR.

## Financial and domain correctness

- Never introduce binary floating-point arithmetic for monetary values.
- Preserve decimal precision through calculations, persistence, serialization, and UI conversion.
- Accounting and balance calculations should live in shared domain logic rather than being independently reimplemented in UI code.
- Review changes to balances, transfers, budgets, recurring payments, credit limits, and account totals for accounting correctness.
- Preserve the semantic distinction between `null`, zero, an empty user input, and an explicitly supplied value where relevant.
- Domain invariants should be enforced at the appropriate domain boundary rather than only through UI validation.
- Editing an entity must preserve fields that the edit operation does not intentionally modify.
- Non-applicable fields should be normalized or rejected rather than silently retained in invalid states.

## Persistence and data integrity

- Treat persisted financial data as durable and important.
- Changes to persisted models, Drift tables, serialization, or mappings must preserve all relevant fields during create, read, update, and round-trip operations.
- Flag mappings that silently omit newly added fields.
- Generated files such as `*.g.dart` must not be manually edited.
- Generated code should remain reproducible from committed source definitions.
- Once schema migrations exist, any incompatible schema change must include an appropriate migration and migration tests.
- Avoid behavior that depends on a fresh database if existing databases may need to continue working.

## Sync correctness

Sync correctness is more important than implementation simplicity.

Review sync-related changes for:

- eventual convergence between replicas
- idempotency
- deterministic conflict resolution
- duplicate operation delivery
- retries
- stale clients
- out-of-order delivery
- concurrent edits
- concurrent create/update/delete operations
- version-vector correctness
- serialization compatibility
- partial failures

Given the same valid set of operations, replicas should not end in different states merely because operations arrived in a different order.

Do not allow UI code to independently reproduce sync or conflict-resolution logic that belongs in the sync/domain layer.

## Security and privacy

Treat financial data, synchronization data, credentials, and tokens as sensitive.

Flag:

- committed secrets or credentials
- hard-coded production tokens
- insecure storage of credentials
- accidental logging of sensitive information
- weakened encryption or authentication
- unsafe handling of untrusted remote data
- trust in server responses without appropriate validation
- changes that could expose financial data across users or devices

Build-time configuration values must not require production secrets to be committed to the repository.

## OCR and receipt processing

OCR output must be treated as untrusted and uncertain input.

- Extraction failures should degrade gracefully.
- Do not silently create incorrect financial records from low-confidence OCR output.
- Heuristics should not assume English terminology unless explicitly scoped as an English-only fallback.
- Parsing should tolerate missing, duplicated, or incorrectly recognized fields.
- Changes should avoid reducing existing extraction behavior without corresponding tests.
- User confirmation should remain possible where extracted values are uncertain.

## UI and state management

- Business rules should not be reimplemented inside widgets.
- View models/controllers should not silently discard persisted state.
- Async operations must handle stale state, disposal, and failure paths appropriately.
- Loading, error, empty, and retry states should remain coherent.
- Avoid changes where displayed financial values disagree with domain-calculated values.
- Editing and creation flows should behave consistently unless there is an intentional difference.

## Cross-platform behavior

SpendWise targets:

- Android
- iOS
- macOS
- Windows

Flag changes that unnecessarily assume one platform.

For plugin, filesystem, permissions, database, OCR, secure-storage, or native-integration changes, check whether the implementation remains valid across supported platforms.

Platform-specific implementations are acceptable when required, but common behavior should remain consistent.

## Testing expectations

Request tests when a PR changes behavior that could regress without being obvious.

Prioritize tests for:

- financial calculations
- domain invariants
- persistence round trips
- sync convergence and conflict handling
- serialization
- edit flows that must preserve existing values
- security-sensitive behavior
- OCR parsing and extraction edge cases

Do not request tests purely to increase coverage percentage.

Prefer tests that protect meaningful behavior over implementation-detail tests.

## Generated and mechanical changes

Avoid reviewing generated files as though they were handwritten source.

Generally ignore:

- `*.g.dart`
- `*.freezed.dart`
- build output
- generated platform files unless the PR intentionally changes their source configuration

When generated output changes unexpectedly, review the source definition or dependency/toolchain change responsible for it.

## Review quality

Every review comment should identify a concrete risk, incorrect behavior, regression, security issue, or maintainability problem with practical consequences.

Prefer a small number of high-confidence findings over many speculative comments.

When uncertain whether something is actually incorrect, explain the uncertainty instead of presenting speculation as a definite bug.

Do not suggest changing code merely because an alternative style or architecture is also valid.

When the implementation is correct, do not invent issues for the sake of producing review comments.