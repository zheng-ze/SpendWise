# Sync enrollment: backend picker

Last reconciled: 1d19e85

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

`BackendPickerFlow` owns the picker as the fresh-enrollment `FlowBase` root and consumes its
one-shot steps. Its required `onHostedReady` callback transfers hosted
continuation ownership to `SyncEnrollmentFlow`, which opens the hosted session;
the picker itself adds no enrollment route or call to `composeSyncEnrollment`.
Source:
`app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart` -
`BackendPickerFlow`, `_BackendPickerFlowState.handleStep`;
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
`SyncEnrollmentFlow.buildRoot`;
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
- `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  enclosing hosted-enrollment Flow and `onHostedReady` consumer.

## Contracts and invariants

- `BackendPickerFlow` passes `goBack` to the picker's leading Back button only
  when it has an `onEnded` callback. Fresh `SyncEnrollmentFlow` forwards its
  `onEnded` callback to the nested picker, so Back at the picker root invokes
  that callback. A standalone picker without `onEnded` has no Back button.
  Source: `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart` -
  `_BackendPickerFlowState.buildRoot`;
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_screen.dart` -
  `_BackendPickerScreenState.build`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState.buildRoot`;
  `app/lib/ui/common/flow_base.dart` - `FlowBaseState.showsOwnBackButton`,
  `FlowBaseState.goBack`.
- `BackendPickerViewModel.continueWithSelection()` persists the hosted choice
  through `BackendSelectionWriter.setBackendSelection` before emitting
  `HostedReady`. For a valid custom endpoint, it persists the validated URI
  before emitting `CustomEndpointUnavailable`. Source:
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
  - `BackendPickerNotifier.continueWithSelection`, `_persistHosted`,
  `_persistCustom`.

## Gotchas

- Fresh `SyncEnrollmentFlow` constructs `BackendPickerFlow` as its root. The installed Settings
  entry opens repair mode at identifier entry and bypasses the picker; fresh enrollment has no
  installed-app entry point. `HostedReady` invokes its callback without the picker composing
  enrollment, while `CustomEndpointUnavailable` leaves the picker visible with an
  unavailable affordance. Both steps are cleared after handling.
  Source: `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart`
  - `BackendPickerFlow`, `_BackendPickerFlowState.handleStep`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `SyncEnrollmentFlow.buildRoot`; `app/lib/boot/app_boot.dart` - `AppBoot`;
  `app/test/ui/sync/enrollment/backend_picker_flow_test.dart` -
  `hosted-ready invokes the hosted callback and clears the step`,
  `custom-unavailable shows the affordance, clears the step, and never invokes
  the hosted callback`.
