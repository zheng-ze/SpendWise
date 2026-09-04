# Knowledge Base Index

One comprehensive entry per feature. Read the relevant entry before planning or changing a
feature; it records the final implementation, key files, interactions, navigation, APIs, gotchas,
and requirements from the current diff rather than requiring a scan of the whole codebase.

This index is a link list with one-line descriptions. Shared domain vocabulary lives in
`CONTEXT.md`; the behavior contracts and the decisions behind them live in the feature entries
themselves. Feature entries fold in still-current legacy material when a feature touches it.

| Feature | Entry |
|---|---|
| Domain models, `LedgerState`, lifecycle machine | [ledger-and-money-model.md](ledger-and-money-model.md) |
| Runtime hub, event bus, analysis cache, boot, banners, seeding | [ledger-runtime.md](ledger-runtime.md) |
| Persistence (Drift store, coalescing, version vectors, replay) | [persistence.md](persistence.md) |
| Recurring plans, occurrences, accounting, analysis | [recurring-plans-and-accounting.md](recurring-plans-and-accounting.md) |
| Budgets | [budgets.md](budgets.md) |
| Categories and the on-device category classifier | [categories-and-classification.md](categories-and-classification.md) |
| Transactions tab and entry form | [transactions-ui.md](transactions-ui.md) |
| Stats tab and category drill-down | [stats-and-analysis-ui.md](stats-and-analysis-ui.md) |
| Accounts tab and account/pocket forms | [accounts-ui.md](accounts-ui.md) |
| Settings: categories, recurring plans, recycle bin | [settings-ui.md](settings-ui.md) |
| Receipt OCR entry | [ocr-receipt-entry.md](ocr-receipt-entry.md) |
| UI framework (MVVM, Flow, Step, notifiers) | [ui-framework-mvvm.md](ui-framework-mvvm.md) |

## Conventions

- One file per feature, kebab-case slug. Expand an entry rather than splitting its capabilities.
- Each entry carries exactly one `Last reconciled:` marker below its title.
- Every module-interaction, gotcha, and requirement claim cites a file path, symbol name, or
  commit SHA. A claim without a source is a guess, not knowledge.
- These entries describe the shipped implementation. A plan can settle differently than it ships;
  the reconciliation marker signals possible staleness and does not guarantee every sentence is
  current.
