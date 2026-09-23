# Sync enrollment: backend picker

Last reconciled: 4527938ac06f12b78062169abeddae664ee01b76

## Overview

`BackendPickerScreen` and its Riverpod `BackendPickerNotifier` own the initial
hosted-versus-custom sync-backend selection UI. `BackendPickerViewModel`
exposes backend selection, endpoint input, continuation, and one-shot steps.
The notifier depends only on `BackendSelectionWriter` and
`CustomEndpointValidation`; it does not construct or call an enrollment
service, resolver, coordinator, backend, or authenticator. Source:
`app/lib/ui/sync/enrollment/backend_picker/backend_picker_screen.dart` -
`BackendPickerScreen`; `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
- `BackendPickerViewModel`, `BackendPickerNotifier`.

`BackendPickerFlow` owns the picker as a `FlowBase` root and consumes its
one-shot steps. Its required `onHostedReady` callback transfers hosted
continuation ownership to a future caller; the Flow itself adds no enrollment
route or call to `composeSyncEnrollment`. Source:
`app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart` -
`BackendPickerFlow`, `_BackendPickerFlowState.handleStep`;
`app/lib/sync/sync_enrollment_composition.dart` - `composeSyncEnrollment`.

## Key locations

- `app/lib/ui/sync/enrollment/backend_picker/backend_picker_screen.dart` -
  backend-choice screen and custom-endpoint field.
- `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
  - picker state, `BackendPickerViewModel`, notifier, and continuation steps.
- `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart` -
  `FlowBase` wrapper, picker root, and one-shot step handling.
- `app/lib/sync/backend_selection_writer.dart` - narrow durable-selection
  write seam implemented by `SyncMetadataStore`.
- `app/lib/sync/sync_enrollment_composition.dart` - Supabase-only hosted
  enrollment factory for a future hosted continuation.

## Contracts and invariants

- `BackendPickerViewModel.continueWithSelection()` persists the hosted choice
  through `BackendSelectionWriter.setBackendSelection` before emitting
  `HostedReady`. For a valid custom endpoint, it persists the validated URI
  before emitting `CustomEndpointUnavailable`. Source:
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
  - `BackendPickerNotifier.continueWithSelection`, `_persistHosted`,
  `_persistCustom`.

## Gotchas

- The `FlowBase` wrapper and continuation-step handling exist, but no app
  entry point constructs `BackendPickerFlow`; the picker remains reachable
  only through tests. `HostedReady` invokes `onHostedReady` without Flow
  navigation or composing enrollment, while `CustomEndpointUnavailable` leaves
  the picker visible with an unavailable affordance. Both steps are cleared
  after handling.
  Source: `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart`
  - `BackendPickerFlow`, `_BackendPickerFlowState.handleStep`;
  `app/test/ui/sync/enrollment/backend_picker_flow_test.dart` -
  `hosted-ready invokes the hosted callback and clears the step`,
  `custom-unavailable shows the affordance, clears the step, and never invokes
  the hosted callback`.
