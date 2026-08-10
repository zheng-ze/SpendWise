# event-bus Specification

## Purpose
Defines how committed ledger changes reach the parts of the app that react to them, so that a
mutation and its consequences — persistence, cached analysis, UI refresh — cannot drift apart.

Delivery is synchronous and ordered because the alternative is a persistence layer applying an old
write over a newer one.

## ADDED Requirements
### Requirement: Ordered atomic delivery

The bus SHALL deliver each published batch to every attached subscriber in publish order, and SHALL
deliver a batch as a single unit — never split into individual changes, never merged with another
batch.

A cascade that produces several changes SHALL therefore land on a subscriber all at once, so that no
subscriber can observe a half-applied cascade.

#### Scenario: Later publish wins

- **WHEN** two batches touching the same target are published in sequence
- **THEN** every subscriber observes them in that same sequence

#### Scenario: Cascade lands atomically

- **WHEN** one mutation produces several changes
- **THEN** subscribers receive them as one batch rather than several

### Requirement: Fan-out and subscription cut

Every attached subscriber SHALL receive every batch published while it is attached. A subscriber
SHALL NOT receive batches published before it attached, and SHALL stop receiving batches once it
cancels.

Because attachment is the cut, every runtime subscriber SHALL attach during boot, before any
mutation is possible.

#### Scenario: All subscribers see a batch

- **WHEN** several subscribers are attached and a batch is published
- **THEN** each receives it

#### Scenario: Cancelled subscriber stops receiving

- **WHEN** a subscriber cancels and a further batch is published
- **THEN** it receives nothing

### Requirement: Empty batch suppression

Publishing an empty list of changes SHALL deliver nothing to any subscriber, so that a mutation
which changed nothing does not wake persistence or invalidate a cache.

#### Scenario: Nothing changed

- **WHEN** an empty batch is published
- **THEN** no subscriber is notified

### Requirement: Non-reentrancy

A subscriber's handler SHALL NOT mutate the ledger. Handlers run inside the publishing call, so a
mutation from a handler would reenter a mutation already in progress.

Handlers are limited to enqueuing work or bumping a counter.

#### Scenario: Handler attempts a mutation

- **WHEN** a subscriber tries to mutate the ledger from its handler
- **THEN** the attempt fails loudly rather than corrupting the in-progress mutation
