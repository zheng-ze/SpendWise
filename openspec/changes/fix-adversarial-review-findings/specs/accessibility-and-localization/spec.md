## MODIFIED Requirements

### Requirement: Localization scaffolding

Localization is deferred. This is a personal-use app with a single-language user base today, and
scaffolding a localization layer with nothing yet routed through it would be dead weight carried for
no current benefit.

Strings already persisted as data SHALL NOT be retroactively rewritten regardless of when
localization lands. Entries whose names were stored in English remain as stored; they are marked
structurally so that display-time naming can take over later without rewriting stored data.

#### Scenario: Stored entry names are left alone

- **WHEN** an entry created before localization lands carries an English stored name
- **THEN** its stored name is unchanged
