# Sync enrollment: backend picker

Last reconciled: 0d906b7

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

- Fresh `SyncEnrollmentFlow` first awaits `SyncEnrollmentNotifier.enterFreshMode()`
  to settle prior enrollment work, then only for `FreshEntryResult.applied` awaits
  `BackendPickerViewModel.resetForFreshEntry()` before mounting `BackendPickerFlow`.
  During both waits, the root shows a progress indicator and "Finishing the
  previous attempt. This usually takes a few seconds." Back can end the Flow
  when `onEnded` is supplied and no selection save is in flight. A `superseded`
  result skips picker reset and mounting. The prior-enrollment wait has a
  30-second `freshWaitTimeout`; `timedOut` leaves enrollment and picker state
  intact and does not cancel pending work. The root offers `Try again`
  (`syncFreshRetryWait`) and the Back arrow (`syncPickerBack`, when `onEnded`
  is supplied). Retry starts a new wait with a new entry id; late settlement
  alone does not mount the picker. The timeout does not bound the picker-save
  wait in `resetForFreshEntry()`. The Flow checks that it is still mounted after
  each wait. The picker reset waits for an active selection
  save to settle, then restores the default hosted choice, empty endpoint,
  and no pending step. This prevents a late step from advancing a newly
  mounted picker. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState._enterFresh`, `_retryFreshWait`, `buildRoot`, `goBack`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
  `FreshEntryResult`, `SyncEnrollmentNotifier.enterFreshMode`, `freshWaitTimeout`;
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart` -
  `BackendPickerNotifier.resetForFreshEntry`.
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
- The picker's Back arrow is an `IconButton` keyed `syncPickerBack` with a
  `BackButtonIcon`; `onPressed` is null while `saving` is true. A `BackButton`
  would fall back to `maybePop` with a null callback, so it cannot enforce this
  disabled state. `BackendPickerFlow.goBack()` and `SyncEnrollmentFlow.goBack()`
  also ignore back navigation while saving, including system back at the picker
  root. The save cannot be cancelled, so the Flow waits for it to settle before
  allowing exit. Back works again after a save failure clears `saving`. Source:
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_screen.dart` -
  `_BackendPickerScreenState.build`;
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart` -
  `_BackendPickerFlowState.goBack`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState.goBack`;
  `app/test/ui/sync/enrollment/sync_enrollment_flow_test.dart` -
  `picker Back ends the flow again after a save failure`.
- `BackendPickerViewModel.continueWithSelection()` persists the hosted choice
  through `BackendSelectionWriter.setBackendSelection` before emitting
  `HostedReady`. For a valid custom endpoint, it persists the validated URI
  before emitting `CustomEndpointUnavailable`. Source:
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
  - `BackendPickerNotifier.continueWithSelection`, `_persistHosted`,
  `_persistCustom`.

## Gotchas

- The Settings Hosted sync tile opens fresh `SyncEnrollmentFlow(repairMode: false)` with
  `BackendPickerFlow` as its root only for `HostedSyncNoSelection` and
  `HostedSyncSetupPending`. Each fresh route, including a resumed fresh-enrollment route,
  enters fresh mode and resets the keep-alive picker view model to its default hosted choice,
  empty endpoint, and no pending step after prior enrollment work settles. In
  `HostedSyncSetupPending`, continuing with Hosted persists the same Supabase backend
  selection before opening identifier entry; this write updates backend selection fields and
  leaves enrollment phase and device-binding state intact. Device-access repair still opens
  repair mode at identifier entry and bypasses the picker. `HostedReady` invokes its callback
  without the picker composing enrollment, while `CustomEndpointUnavailable` leaves the
  picker visible with an unavailable affordance. Both steps are cleared after handling.
  Source: `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart`
  - `BackendPickerFlow`, `_BackendPickerFlowState.handleStep`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState._enterFresh`, `SyncEnrollmentFlow.buildRoot`;
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart` -
  `BackendPickerNotifier.resetForFreshEntry`, `_persistHosted`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
  `SyncEnrollmentNotifier.enterFreshMode`, `hostedReady`;
  `app/lib/ui/settings/settings_root_screen.dart` - `_HostedSyncSection`;
  `app/lib/ui/settings/settings_flow.dart` - `_openFreshFlow`, `_openRepairFlow`,
  `_pushEnrollmentRoute`; `app/lib/sync/sync_metadata_store.dart` -
  `SyncMetadataStore.setBackendSelection`;
  `app/test/ui/sync/enrollment/backend_picker_flow_test.dart` -
  `hosted-ready invokes the hosted callback and clears the step`,
  `custom-unavailable shows the affordance, clears the step, and never invokes
  the hosted callback`.
