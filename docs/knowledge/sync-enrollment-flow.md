# Sync enrollment: hosted Flow

Last reconciled: eb968bbc7b012181c453c54afb1f74a7ef4e0b3c

## Overview

`SyncEnrollmentFlow` owns first-device hosted-enrollment presentation. It nests
`BackendPickerFlow` at its root, receives hosted selection, and maps
`SyncEnrollmentNotifier` steps to identifier, OTP, resume, and completion
routes. The notifier owns session opening, durable-phase-aware retry, and the
single in-flight enroll-and-publish operation. Source:
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
`SyncEnrollmentFlow`, `_SyncEnrollmentFlowState`;
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
`SyncEnrollmentNotifier`, `SyncEnrollmentState`.

## Key locations

- `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  nested navigator, picker root, and step-to-route mapping.
- `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - Flow state, session operation, OTP resolver, and retry policy.
- `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart` -
  identifier, OTP, resume, completion, and error screens.
- `app/lib/sync/sync_enrollment_session.dart` - narrow adapter over
  `composeSyncEnrollment`'s ready graph.
- `app/test/ui/sync/enrollment/sync_enrollment_flow_test.dart` - Flow route,
  cancellation, retry, operation-lock, and bounded-publication coverage.
- `app/test/ui/sync/enrollment/sync_enrollment_hosted_e2e_test.dart` - hosted
  graph integration through the Flow.

## Interactions

`BackendPickerFlow` persists hosted selection, then invokes the enclosing
Flow's callback. `SyncEnrollmentNotifier.hostedReady()` emits identifier entry.
Identifier submission opens one `SyncEnrollmentSession` with a resolver that
emits OTP entry and awaits its `Completer`; the session adapter delegates
`enroll()` and `publishSnapshot()` to the composed service and publisher.
Source: `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart` -
`BackendPickerFlow`; `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart`
- `SyncEnrollmentFlow.buildRoot`; `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
- `SyncEnrollmentNotifier.hostedReady`, `_enrollFromIdentifier`;
`app/lib/sync/sync_enrollment_session.dart` - `openSyncEnrollmentSession`,
`_ComposedSyncEnrollmentSession`.

On retry, the notifier reads `SyncMetadataStore.snapshot().phase`. It returns
to identifier entry only from `notEnrolled`; every later phase shows resume and
calls `_resumeWithoutCredentials()`. That method reuses the held session or
opens one with an OTP resolver that throws, because resumed enrollment must not
request a new OTP. Source:
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
`SyncEnrollmentNotifier.retry`, `_resumeWithoutCredentials`,
`_reopenForResume`, `_rejectUnexpectedOtp`;
`app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService._advance`,
`SyncEnrollmentService._stepNotEnrolled`.

## Contracts and invariants

- `state.inFlight` guards the whole enrollment and publication operation.
  `submitIdentifier()` and `retry()` no-op while it is true and clear it in
  `finally`. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier.submitIdentifier`, `SyncEnrollmentNotifier.retry`.
- OTP cancellation is typed. System back and the OTP app-bar back both call
  `cancelOtp()`, which completes the pending resolver with
  `SyncEnrollmentOtpCancelled`; enrollment returns to identifier entry with a
  cancelled, non-error state. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart` -
  `SyncOtpScreen`; `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier.cancelOtp`, `_enterCancelled`.
- After `enroll()` returns at durable `gateEnabled`, publication retries a
  pending outcome at most three times, with one-second delays. Exhaustion
  routes a typed `SyncEnrollmentException(step: 'publishSnapshot',
  code: 'snapshotPending')` through phase-aware failure handling; it does not
  roll back the durable phase. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier._publishUntilPublished`, `_failPhaseAware`;
  `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepReconciliationComplete`.
- `_publishUntilPublished()` handles both `StateError` and `Exception` so a
  backend push failure from `SyncCoordinator.pushCollection` becomes a
  phase-aware Flow error. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier._publishUntilPublished`;
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.pushCollection`.

## Entry points and flows

- `ShowProgressResume` first pops to the Flow root, then pushes resume. Repeated
  failures therefore keep one resume route. `ShowEnrollmentCompleted` removes
  every earlier route, so Back delegates to `FlowBase.goBack()` and then
  `onEnded` instead of returning to stale enrollment screens. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState.handleStep`; `app/lib/ui/common/flow_base.dart` -
  `FlowBaseState.goBack`.

## Gotchas

- `SyncEnrollmentFlow` is the first production caller of the hosted
  composition, but no `AppBoot`, lifecycle, scheduler, or shell path constructs
  the Flow. It remains unavailable in the installed application until a higher
  composition layer mounts it. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
  `SyncEnrollmentNotifier._opener`; `app/lib/boot/app_boot.dart` - `AppBoot`.
