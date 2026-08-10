# Add the release targets

## Why

Everything before this proves the app is correct; nothing proves it *runs*. The whole point of the
port is reaching platforms the SwiftUI app could never reach, and that claim is untested until the
app has actually launched on each of them.

There is also no end-to-end coverage to inherit. The Swift project's UI test target was an empty
template, so every integration test here is new rather than ported.

## What Changes

- Bring up Android and iOS first, on real devices rather than simulators only, then macOS, then web,
  then Windows.
- Add one integration test per platform that boots the app and exercises a basic interaction, so a
  platform that stops launching fails a test rather than being discovered by hand.
- Add a per-platform smoke checklist covering the things automated tests do not reach — the web
  database backend, app lifecycle transitions, and window behavior on desktop.
- Capture screenshots into the docs directory.
- Write the repository README, which does not yet exist.

Not **BREAKING**: no behavior changes. This is verification and packaging.

## Capabilities

### New Capabilities

- `platform-release`: what "runs on a platform" means concretely — the boot smoke coverage, the
  per-platform checks, and the ordering in which platforms are brought up.

### Modified Capabilities

None.

## Impact

- New integration tests under `app/integration_test/`.
- Platform configuration under `app/android/`, `app/ios/`, `app/macos/`, `app/web/`, `app/windows/`.
- Screenshots into `docs/`, and a new `README.md`.
- New dev dependency on `app/`: `integration_test` from the SDK.
- No change to `packages/domain/` or to any app behavior. A change forced by a platform is a defect
  found, and should be fixed as its own commit rather than folded into this one.
