# SpendWise UI revamp design source

This directory is the source of truth for the approved Daylight structure and Harbour glass appearance. Each screen or significant state has one frame. Every phone, desktop and foldable frame follows the **App theme** control at the top of the page. Review each frame in Light and Dark using that control. The separate **Page background** control changes only the surrounding reference page.

## Files

- `spec.md` defines the reference's design, data and verification contracts.
- `HANDOFF.md` describes the current composition, sample data, coverage and review limits.
- `generator/` contains the source. `build.py` assembles the page; `comp.py` defines shared components; `data.py` contains seed records, labelled sample history and shared screen content; `tiles.py` builds data-derived widgets and forecast rows; `foldables.py` builds foldable frames; `s_*.py` build each screen area; `tokens.py` defines both palettes; `styles.py` defines shared CSS. `extract.py` extracts page text from HTML.
- `inventory.json` is the 177-row screen inventory checked by the build.
- `spendwise-reference.html` is the generated reference. Edit the generator, then rebuild this file.
- `frames.json` is the generated manifest. Each entry records a unique frame id, area, covered inventory rows and form factor. Foldable entries have no inventory rows.

## Build and review

From the repository root, run:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 docs/design/ui-revamp/generator/build.py
```

The build resolves inputs and outputs relative to the generator. It regenerates both output files, checks inventory coverage and unique frame ids, and checks that the folded Budgets, Accounts and Plans bodies match their phone reference bodies.

The reference contains 205 registered frames: 173 phone, 11 desktop and 21 foldable frames (7 folded and 14 open). It covers 168 of 177 inventory rows; nine states are deliberately omitted. Widget and component specimens do not increase the registered frame count.

There are no fixed-theme screen copies or side-by-side theme section. Borders, dividers, outlines, raised surfaces, chart accents and category colours use shared theme tokens. Static checks do not establish visual correctness. The coordinator reviews every frame by toggling App theme, including the History day groups and Overview entry rows.
