# app-boot Specification

## Purpose
Defines how the app comes up: the phases it moves through, the order its parts are wired in, what
happens on first launch, and how background failures are surfaced.

The wiring order is the mechanism that guarantees no mutation escapes persistence, so it is a
behavior contract rather than an implementation detail.

## Requirements

### Requirement: Boot phases

The app SHALL be in exactly one of three phases: loading, ready, or failed. There SHALL be no
partially-ready phase — any failure during startup SHALL land in failed, carrying the error.

The failed phase SHALL offer a retry that returns to loading and re-runs the whole startup sequence
from the beginning.

#### Scenario: Startup failure

- **WHEN** any startup step fails
- **THEN** the app enters the failed phase with the error and offers retry

#### Scenario: Retry restarts cleanly

- **WHEN** the user retries after a failure
- **THEN** startup runs again from its first step

### Requirement: Subscriber-before-mutator wiring

Startup SHALL attach the persistence subscriber to the event bus **before** the mutation hub is
created, so that every batch the hub can ever publish has a persistence subscriber already attached.

The store's error handler SHALL be wired before seeding, so that a failure while saving the seed is
surfaced like any other save failure.

#### Scenario: No mutation escapes persistence

- **WHEN** the very first mutation is published
- **THEN** persistence is already subscribed and receives it

#### Scenario: Seed save failure is visible

- **WHEN** saving the first-launch seed fails
- **THEN** the failure surfaces through the save banner

### Requirement: First-launch seeding

Seeding SHALL be gated on a persisted "has seeded" flag, never on the ledger being empty, so that a
user who deletes all their data is not re-seeded.

On first launch the flag SHALL be set before the seed is enqueued, and the seed SHALL be flushed to
disk before state is loaded. A crash mid-seed therefore leaves a partial seed rather than causing a
double seed on the next launch.

The seed SHALL be built through the same mutation API user data goes through, and SHALL fail loudly
in debug rather than silently dropping rejected rows.

#### Scenario: User empties their ledger

- **WHEN** a user deletes everything and restarts the app
- **THEN** the sample data is not restored

#### Scenario: Seed rejected by validation

- **WHEN** a seed row fails validation in a debug build
- **THEN** the failure is raised rather than silently skipped

### Requirement: Lifecycle hooks

The app SHALL resolve recurring plans when it becomes active, and SHALL flush pending writes when it
leaves the foreground. Both SHALL act only while the app is ready.

Because the platform does not report an initial activation, plans SHALL also be resolved once
explicitly on entering the ready phase.

Flushing on backgrounding is the durability moment: pending debounced writes SHALL reach disk before
the process can be killed.

#### Scenario: Cold start resolves plans

- **WHEN** the app finishes starting up
- **THEN** due plan occurrences are resolved without waiting for a later foregrounding

#### Scenario: Backgrounding flushes

- **WHEN** the app leaves the foreground with writes pending
- **THEN** those writes are flushed

### Requirement: Error banners

The app SHALL surface save failures and plan-resolution failures in a single banner slot, with the
plan-error message taking precedence while both are active.

A plan-error message SHALL be phrased by the number of **distinct plans** that failed, not the number
of failed occurrences, and SHALL auto-dismiss after a short delay. A new failure arriving before that
delay elapses SHALL cancel the pending dismissal and restart it, so that a newer message is never
cleared by an older one's timer.

#### Scenario: Two occurrences of one plan fail

- **WHEN** a single plan fails on two occurrences
- **THEN** the message refers to one plan

#### Scenario: Re-fire restarts dismissal

- **WHEN** a second plan failure arrives before the first message has dismissed
- **THEN** the pending dismissal is cancelled and the newer message gets a full display window
