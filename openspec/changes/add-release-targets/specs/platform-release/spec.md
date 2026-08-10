# platform-release Specification

## Purpose
Defines what it means for the app to run on a platform, so that "supported" is a verified claim rather
than an assumption.

## ADDED Requirements
### Requirement: Supported platforms

The app SHALL run on Android, iOS, macOS, web and Windows.

Mobile platforms SHALL be brought up first and verified on real hardware, not only on simulators,
since the behavior most likely to differ — lifecycle transitions and storage — is the behavior
simulators reproduce least faithfully.

#### Scenario: Mobile verified on hardware

- **WHEN** Android and iOS are signed off
- **THEN** each has been run on a real device

### Requirement: Boot smoke coverage

Each platform SHALL carry an automated test that launches the app and exercises a basic interaction,
so that a platform which stops launching fails a test rather than being noticed by hand.

#### Scenario: A platform stops launching

- **WHEN** a change breaks startup on one platform
- **THEN** that platform's smoke test fails

### Requirement: Per-platform verification

Each platform SHALL be verified against a checklist covering what automated tests do not reach:
that data persists across a restart, that the app survives being backgrounded and resumed, and that
window or display behavior is correct where the platform has one.

Web SHALL additionally be verified to persist data through its own database backend, which differs
from the native one.

#### Scenario: Data survives a restart

- **WHEN** the app is closed and reopened on any supported platform
- **THEN** previously entered data is still present

#### Scenario: Web persistence

- **WHEN** the app runs on web
- **THEN** data persists across a page reload

### Requirement: A platform failure is a defect

Where a platform reveals a problem, it SHALL be recorded and fixed as a defect in its own right rather
than worked around inside the release work.

#### Scenario: Platform-specific bug found

- **WHEN** bringing up a platform surfaces incorrect behavior
- **THEN** it is fixed as its own change rather than patched over during release verification
