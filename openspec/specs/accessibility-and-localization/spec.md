# accessibility-and-localization Specification

## Purpose
Defines the two commitments V1 made and never delivered: an app usable without sight, and one whose
text can be translated.

Both are specified as requirements rather than polish, because treating them as polish is how they
were skipped the first time.

## Requirements

### Requirement: Semantics on custom widgets

Every custom widget SHALL expose semantics. Widgets built from painted geometry rather than standard
controls SHALL NOT be left unlabelled.

The donut SHALL offer a text alternative conveying what it shows — each bucket, its amount and its
share — since a screen reader cannot interpret the drawing.

#### Scenario: Donut without sight

- **WHEN** the stats screen is read by a screen reader
- **THEN** the composition of the chart is available as text

### Requirement: Reachable actions

Actions available only through gesture SHALL also be reachable by assistive technology. The expanding
action button, the two-column picker and every swipe action SHALL carry labels or custom actions.

#### Scenario: Deleting without swiping

- **WHEN** a row's delete is offered only as a swipe
- **THEN** it is also exposed as a custom action

### Requirement: Localization scaffolding

The app SHALL be set up for localization, with user-facing strings declared through it rather than
written inline, and every shared format routed through the localization layer.

Strings already persisted as data SHALL NOT be retroactively rewritten. Entries whose names were
stored in English remain as stored; they are marked structurally so that display-time naming can
take over later without rewriting stored data.

#### Scenario: Stored entry names are left alone

- **WHEN** an entry created before this change carries an English stored name
- **THEN** its stored name is unchanged
