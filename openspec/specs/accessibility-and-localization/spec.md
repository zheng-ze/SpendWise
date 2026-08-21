# accessibility-and-localization Specification

## Purpose
Defines the commitment V1 made and never delivered: an app usable without sight.

Specified as a requirement rather than polish, because treating it as polish is how it was skipped
the first time.

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
