# SpendWise UI revamp design source

This directory is the tracked source of truth for the approved Daylight / Harbour glass reference. It supersedes `.lavish/`, the gitignored working copy the reference was approved from. Later changes cite this copy, not `.lavish/`.

## Files

- `spec.md`: the approved reference brief.
- `HANDOFF.md`: generator handoff notes, newest section first.
- `generator/`: the page generator. `build.py` assembles the page; `comp.py` holds shared components; `data.py` holds seed records, sample history and shared screen pieces; `extract.py` renders page text from HTML; `s_*.py` build the per-area frames; `styles.py` holds page CSS; `tokens.py` holds the colour tokens.
- `inventory.json`: the earlier 177-row screen inventory the generator checks coverage against.
- `spendwise-reference.html`: the generated reference page. Do not edit it; edit the generator and rebuild.
- `frames.json`: emitted by the build, one entry per registered frame: frame id, area, covered inventory rows and phone or desktop form factor.

## Build

From the repository root:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 docs/design/ui-revamp/generator/build.py
```

The build works from any working directory: it reads `inventory.json` and writes `spendwise-reference.html` and `frames.json` relative to the generator directory. It asserts full inventory coverage and unique frame ids, then reports 184 frames (173 phone, 11 desktop) and 168 of 177 inventory rows.
