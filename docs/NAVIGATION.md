# Where to look

Planning lives in `CONTEXT.md` and `docs/knowledge/`. Read in this order.

1. `CONTEXT.md` — the domain glossary and an index pointing at every knowledge entry. Start here
   for vocabulary and for what exists.
2. `docs/knowledge/INDEX.md`, then the relevant entry under `docs/knowledge/` — one file per
   feature, each holding both the behavior contract ("what the code must do") and the rationale
   behind it ("why it works this way"), including past decisions and the alternatives they
   rejected. Read the entry for the area you're about to work in before changing it, and check its
   `Last reconciled:` marker for possible staleness.
3. `docs/ARCHITECTURE.md` — the architecture and behavior spec for the app as a whole: the feature
   surface, the stack decisions and their rationale, the layer-by-layer architecture, the domain
   and implementation rules, and the roadmap. Read this for the wide-angle view that ties together
   the narrower knowledge entries.

## Current planning system

This repo used to plan work through OpenSpec (`openspec/`), which has been retired. `CONTEXT.md`
plus `docs/knowledge/` replace it entirely: `CONTEXT.md` is the glossary and index, knowledge
entries hold both the behavior contracts and the decisions behind them. Open work items — the
equivalent of what used to be an OpenSpec change's `tasks.md` — are tracked as GitHub issues; see
`docs/agents/issue-tracker.md`.

An earlier native prototype defined the app's behavior through parity, reached at the end of the
port (everything through `add-drift-store`). **Work past that point (starting with the budgets
feature) is greenfield design, not a port** — design from domain and product reasoning and this
repo's own conventions. The knowledge entries reflect this split: decisions up through the
persistence layer are mostly translation calls (where a straight port of the earlier prototype's
behavior would have been wrong, and what replaced it); decisions from the budgets feature onward
are original product and architecture calls with no earlier equivalent to check against.
