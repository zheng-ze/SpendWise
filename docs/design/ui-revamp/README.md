# SpendWise UI revamp design source

This directory is the tracked source of truth for the approved Daylight / Harbour glass reference. It supersedes `.lavish/`, the gitignored working copy the reference was approved from. Later changes cite this copy, not `.lavish/`.

## Files

- `spec.md`: the approved reference brief.
- `HANDOFF.md`: generator handoff notes, newest section first.
- `generator/`: the page generator. `build.py` assembles the page; `comp.py` holds shared components; `data.py` holds seed records, sample history, every sample value and shared screen pieces; `tiles.py` holds the 14 foldables tiles, the budget forecast row and their CSS, computed from `data.py`; `extract.py` renders page text from HTML; `foldables.py` builds the foldable frames and holds their CSS; `s_*.py` build the per-area frames; `styles.py` holds page CSS; `tokens.py` holds the colour tokens.
- `inventory.json`: the earlier 177-row screen inventory the generator checks coverage against.
- `spendwise-reference.html`: the generated reference page, holding the phone, desktop and foldable frames (one shared foldable design for Samsung Galaxy Z Fold8 and Apple iPhone Duo). Do not edit it; edit the generator and rebuild.
- `frames.json`: emitted by the build, one entry per registered frame: frame id, area, covered inventory rows and phone, desktop or foldable form factor. Foldable frames have no inventory rows.

## Build

From the repository root:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 docs/design/ui-revamp/generator/build.py
```

The build works from any working directory: it reads `inventory.json` and writes `spendwise-reference.html` and `frames.json` relative to the generator directory. It asserts full inventory coverage and unique frame ids across the reference and foldable frames, asserts that the foldable phone Budgets, Accounts and Plans frames equal the reference frames, and reports 184 reference frames (173 phone, 11 desktop), 22 foldable frames (7 folded, 15 open) and 168 of 177 inventory rows. Every figure comes from `data.py`, so the frames cannot disagree.
