# Add the app shell and UI foundation

## Why

Phase 3 built the boot phase machine and banner state as runtime objects, but nothing renders them —
the app still shows a bare `main.dart`. There is no shell to hang screens off, and none of the
formatting, iconography or shared widgets every screen needs.

This is the first change of Phase 5, and it exists separately from the four screen changes because
those all depend on it. Currency formatting, the amount sanitizer, the symbol map and the shared
components are written once here; a screen change that had to invent its own would guarantee drift.

The master doc's sequencing rule gates this on Phase 3 being green.

## What Changes

- Add the adaptive shell: a bottom navigation bar on compact widths and a navigation rail on wide
  ones, with four destinations — Transactions, Stats, Accounts, Settings — each keeping its own
  navigation stack across tab switches.
- Add the boot chrome: a spinner while loading, a retry screen on failure, and the shell when ready.
- Add the banner overlay, driven by the Phase 3 banner state, with plan errors taking precedence over
  save state. It persists while the state is non-clear rather than being a transient snackbar.
- Add shared formatting: currency, the amount sign and color rules, the net-amount color rule, hex
  color parsing with a gray fallback, the plain amount format, the date and percentage formats.
- Add the amount input sanitizer as a pure function plus a text input formatter.
- Add the symbol map from stored SF Symbol names to Material icons, covering the chrome symbols and
  the roughly ninety category catalog names, with a fallback for unknown strings.
- Add the shared components every screen reuses: the two-tab bar, the month/year selector, the
  column-text row, the amount field, the category icon chip, the two-column picker sheet, the form
  scaffold and the error section.

Not **BREAKING**: additive. No domain, runtime or persistence behavior changes.

## Capabilities

### New Capabilities

- `app-shell`: the adaptive navigation shell, per-tab navigation stacks, boot chrome, and the banner
  overlay's presentation rules.
- `ui-foundation`: the formatting, color, iconography and input-sanitizing rules every screen shares.

### Modified Capabilities

None.

## Impact

- New code in `app/lib/ui/shell/`, `app/lib/ui/common/`, and `app/lib/ui/format/`.
- New tests in `app/test/ui/`, including a test asserting every category catalog symbol resolves.
- New dependency on `app/`: `intl`. Adaptive layout and navigation use framework primitives.
- No change to `packages/domain/`, the runtime, or persistence.
- Two V1 behaviors deliberately not copied (`design.md`): view-model lifetime tied to widget
  identity, and hardcoded black text that breaks in dark mode.
