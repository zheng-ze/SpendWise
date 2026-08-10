# transactions-screen Specification

## MODIFIED Requirements
### Requirement: Section totals

A day section's income SHALL be the sum of its income rows and its expenses the positive magnitude of
its expense rows. Transfers SHALL count toward neither.

Which entries qualify SHALL follow the recorded totals ruling, so that this screen and the stats
screen agree by construction rather than by coincidence. The two SHALL apply the same gates, or the
divergence SHALL be recorded as intentional and stated where a user can see it — the earlier phases
deliberately left this open and routed the calculation through a single call site so the ruling is a
one-line change.

#### Scenario: Transfer is excluded from totals

- **WHEN** a day contains a transfer
- **THEN** it contributes to neither income nor expenses

#### Scenario: Entry excluded from analysis

- **WHEN** an entry is flagged out of analysis
- **THEN** it does not contribute to its section's totals

#### Scenario: Screens agree or say why

- **WHEN** the same month is viewed on the transactions screen and the stats screen
- **THEN** the totals match, or the difference is one the app states rather than one the user must
  discover
