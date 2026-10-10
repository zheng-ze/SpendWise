# Sync enrollment: hosted Flow

Last reconciled: 0d906b7

## Overview

`SyncEnrollmentFlow` owns hosted-enrollment and device-access repair presentation. Fresh enrollment
enters fresh mode and resets the retained picker state before showing `BackendPickerFlow` at its root;
repair mode starts at identifier entry. The Flow maps
`SyncEnrollmentNotifier` steps to identifier, OTP, resume, and completion
routes. The notifier owns session opening, durable-phase-aware retry, and
the UI operation guard and cancellation. Source:
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
`SyncEnrollmentFlow`, `_SyncEnrollmentFlowState`;
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
`SyncEnrollmentNotifier`, `SyncEnrollmentState`.

## Key locations

- `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  nested navigator, mode-specific root, and step-to-route mapping.
- `app/lib/ui/settings/settings_flow.dart` - Settings fresh and repair entries and status refresh
  on return.
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
Fresh enrollment passes its `onEnded` callback to the nested picker Flow, so
back at the picker root can end the enclosing enrollment Flow.

On fresh entry, the Flow awaits `SyncEnrollmentNotifier.enterFreshMode()` and
only for `FreshEntryResult.applied` awaits `BackendPickerViewModel.resetForFreshEntry()`.
Until both settle, the
root shows a progress indicator and "Finishing the previous attempt. This
usually takes a few seconds." Back can end the Flow when `onEnded` is supplied
and no backend selection save is in flight. A `superseded` result skips picker
reset and mounting. A `timedOut` result replaces the loading root with
"Still finishing the previous attempt. You can keep waiting or go back."
and a `Try again` button (`syncFreshRetryWait`), retaining the Back arrow
(`syncPickerBack`) when `onEnded` is supplied. Retry restores the loading root
and starts a new fresh-entry wait. The picker mounts only after an applied
entry and picker reset complete and the Flow is still mounted, preventing a
stale picker step from advancing the route. Source:
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
`_SyncEnrollmentFlowState._enterFresh`, `_retryFreshWait`, `buildRoot`, `goBack`.

Settings opens fresh mode from its Hosted Sync tile for no selection or setup pending; see
`settings-ui.md` for entry eligibility and route ownership. Device-access repair opens explicit
repair mode, bypassing the picker. On repair entry, the notifier
re-reads the durable enrollment phase; if repair has cleared or metadata cannot be read, the Flow
refreshes Hosted Sync status and returns to Settings without opening OTP.

Identifier submission opens one `SyncEnrollmentSession` with a resolver that
emits OTP entry and awaits its `Completer`. Fresh enrollment invokes this
resolver for the device-binding OTP after E2E-key preparation. The session
adapter delegates `enroll()` and `publishSnapshot()` to the composed service
and publisher.
Source: `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart` -
`BackendPickerFlow`; `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart`
- `SyncEnrollmentFlow.buildRoot`; `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
- `SyncEnrollmentNotifier.hostedReady`, `_enrollFromIdentifier`;
`app/lib/sync/sync_enrollment_session.dart` - `openSyncEnrollmentSession`,
`_ComposedSyncEnrollmentSession`.

On retry, the notifier reads `SyncMetadataStore.snapshot().phase`.
`notEnrolled`, `bindingAuthorizationRequired`, and `sessionReauthRequired`
return to identifier entry. Submitting the identifier opens a session with a
live OTP resolver, including after notifier recreation. Other durable phases
show resume and call `_resumeWithoutCredentials()`, reusing the held session
or reopening one with an OTP-rejecting resolver. Source:
`app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
`SyncEnrollmentNotifier.retry`, `_enrollFromIdentifier`,
`_resumeWithoutCredentials`, `_reopenForResume`, `_rejectUnexpectedOtp`;
`app/lib/sync/sync_enrollment_service.dart` - `SyncEnrollmentService._advance`,
`SyncEnrollmentService._stepBindingAuthorizationRequired`,
`SyncEnrollmentService._stepSessionReauthRequired`.

## Contracts and invariants

- `enterFreshMode()` returns `Future<FreshEntryResult>` and waits for in-flight operations,
  pending `enroll()` calls, tracked `submitIdentifier()`, `retry()`, and
  `enterRepairMode()` settlements, and abandoned repair-proof publication.
  These settlements include any trailing Hosted Sync status refresh, so clearing
  `state.inFlight` alone does not permit the reset. Repair ownership remains
  intact during the wait so a late repair enrollment can publish its proof.
  An applied entry clears repair phase, repair copy, errors,
  cancellation, OTP wait, and pending steps, while preserving the entered
  identifier and code-request cooldown. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `FreshEntryResult`, `SyncEnrollmentNotifier.enterFreshMode`, `_pendingSettlements`,
  `_submitAfterIdentifier`, `_retryAfterStart`, `_enrollFromIdentifier`,
  `_publishAbandonedRepairProof`.
- Every fresh or repair mode entry claims a new `_modeSequence` id;
  `cancelPendingOperation()` also advances it when the Flow is disposed. A
  waiting fresh entry returns `FreshEntryResult.superseded` without resetting
  if the notifier is unmounted or its id has been superseded by cancellation
  or a newer fresh or repair entry. The Flow also skips picker reset and mounting
  for this result.
  Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier.enterFreshMode`, `_enterRepairMode`,
  `cancelPendingOperation`, `_modeSequence`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState._enterFresh`.
- The prior-enrollment settlement wait is bounded by `freshWaitTimeout`
  (30 seconds). Timeout returns `FreshEntryResult.timedOut` without resetting
  enrollment or picker state or cancelling the pending operation. Its eventual
  settlement does not automatically reset or mount the picker. `Try again`
  calls `enterFreshMode()` under a new entry id and can time out again; only an
  applied retry permits the picker reset and mount. The timeout does not bound
  the subsequent picker-save settlement in `resetForFreshEntry()`. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
  `SyncEnrollmentNotifier.enterFreshMode`, `_settlePriorOperation`, `freshWaitTimeout`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState._enterFresh`, `_retryFreshWait`.
- Picker Back and system back cannot end the Flow while a backend selection
  save is in flight. The save cannot be cancelled; leaving early could persist
  a choice from an abandoned enrollment. Both the nested picker and enclosing
  enrollment Flow guard `goBack()` using picker `saving` state. Source:
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart` -
  `_BackendPickerFlowState.goBack`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState.goBack`.
- `state.inFlight` blocks duplicate submissions during an active Flow operation.
  `submitIdentifier()` and `retry()` no-op while it is true. Flow disposal
  cancels the current operation, releases the guard after widget finalization
  even when no OTP resolver exists yet, and ignores late results from that
  operation, except that a repair whose `enroll()` completes after disposal
  still publishes a stored write proof without emitting steps
  (`_publishAbandonedRepairProof`); a new submit or retry waits for it because
  sessions share one proof key. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier.cancelPendingOperation`,
  `SyncEnrollmentNotifier._openSession`.
- OTP cancellation is typed. System back and the OTP app-bar back both call
  `cancelOtp()`, which completes the pending resolver with
  `SyncEnrollmentOtpCancelled`; enrollment returns to identifier entry with a
  cancelled, non-error state. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart` -
  `SyncOtpScreen`; `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier.cancelOtp`, `_enterCancelled`.
- For fresh enrollment, after `enroll()` returns at durable `gateEnabled`,
  publication retries a pending outcome at most three times, with one-second
  delays. Exhaustion routes a typed `SyncEnrollmentException(step: 'publishSnapshot',
  code: 'snapshotPending')` through phase-aware failure handling; it does not
  roll back the durable phase. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier._publishUntilPublished`, `_failPhaseAware`;
  `app/lib/sync/sync_enrollment_service.dart` -
  `SyncEnrollmentService._stepReconciliationComplete`.
- `_publishUntilPublished()` catches publication failures, so a backend push
  failure from `SyncCoordinator.pushCollection` becomes a
  phase-aware Flow error. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier._publishUntilPublished`;
  `app/lib/sync/sync_coordinator.dart` - `SyncCoordinator.pushCollection`.
- Repair-mode completion checks `syncWriteProofSecretKey` in the same
  `SecretStore` passed to the hosted session. It runs bounded snapshot
  publication only when the proof is present, including on resume retries;
  otherwise it completes after `enroll()`. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier._completeRepairIfProofPresent`,
  `SyncEnrollmentNotifier._opener`.
- After identifier submission or credential-less resume settles, the notifier
  asks `AppBoot.refreshSyncStatus()` to re-read durable Hosted Sync status,
  even when Flow disposal cancelled the operation. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier.submitIdentifier`, `SyncEnrollmentNotifier.retry`.

## Entry points and flows

- Settings opens `SyncEnrollmentFlow(repairMode: false)` from the Hosted Sync tile for
  `HostedSyncNoSelection` and `HostedSyncSetupPending`. The picker-root Back control, system back,
  and completion Done can end the Flow; Settings refreshes Hosted Sync status after it closes.
  Source: `app/lib/ui/settings/settings_flow.dart` - `_openFreshFlow`, `_pushEnrollmentRoute`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState.goBack`.
- Settings opens `SyncEnrollmentFlow(repairMode: true)` only for binding repair and session reauth.
  Identifier and OTP screens explain that requesting a new code replaces the previous one. Both
  display the live cooldown countdown; the OTP screen enables a new request only while one resolver
  awaits input and the cooldown has expired. After OTP acceptance, repair moves to the resume screen
  while reconciliation and any required publication run. Completion shows `Device access restored`;
  Done returns to Settings, which refreshes Hosted Sync status. Source:
  `app/lib/ui/settings/settings_root_screen.dart` - `_HostedSyncSection`;
  `app/lib/ui/settings/settings_flow.dart` - `_SettingsFlowState._openRepairFlow`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
  `SyncEnrollmentNotifier.enterRepairMode`, `submitOtp`, `requestNewCode`.
- `ShowProgressResume` first pops to the Flow root, then pushes resume. Repeated
  failures therefore keep one resume route. `ShowEnrollmentCompleted` removes
  every earlier route, so Back delegates to `FlowBaseState.goBack()` and then
  `onEnded` instead of returning to stale enrollment screens. Fresh completion's
  Done button emits `DismissEnrollmentFlow`; repair Done emits its subtype
  `DismissRepairFlow`. Both use the enclosing Flow's `goBack()` to end it.
  Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart` -
  `_SyncEnrollmentFlowState.handleStep`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart` -
  `SyncEnrollmentCompletionScreen`;
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart` -
  `SyncEnrollmentNotifier.dismissFlow`, `DismissRepairFlow`;
  `app/lib/ui/common/flow_base.dart` -
  `FlowBaseState.goBack`.

## Gotchas

- The submitted email identifier and code-request cooldown live only in
  notifier memory. After restart, repair asks for the identifier again.
  A code challenge starts a 60-second cooldown on new requests; a longer
  server `retryAfter` extends it. Wait copy is capped at 15 minutes, while
  the longer cooldown remains enforced. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier.enterRepairMode`, `_noteCodeRequested`,
  `_extendCooldownFrom`, `_cooldownCopy`.
- Failure messages use fixed code-to-copy mapping and generic fallback copy;
  they never display exception or server text. Source:
  `app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart`
  - `SyncEnrollmentNotifier._failureCopy`, `_copyForCode`.
- Settings rechecks tile eligibility for `StartHostedEnrollmentRequested`; an ineligible request
  is consumed without opening the Flow. If an AppShell layout switch disposes the Settings Flow
  owning a fresh route, a microtask releases `enrollmentFlowOpenProvider` and emits
  `ResumeFreshEnrollmentRequested` unless the cached Hosted Sync status is `HostedSyncReady`.
  The surviving Settings Flow opens a fresh route through the shared guard without rechecking tile
  eligibility, including when enrollment has reached binding authorization. Repair handover requests
  repair again only for binding-repair or session-reauth status. Source: `app/lib/ui/settings/settings_flow.dart` -
  `_SettingsFlowState._openFreshFlow`, `_settleAtDispose`, `handleStep`,
  `_pushEnrollmentRoute`.
- A repair banner tap opens Settings and requests repair only when `enrollmentFlowOpenProvider`
  is false. An open fresh route awaiting binding authorization therefore remains the single route. Source: `app/lib/ui/shell/status_banner.dart` -
  `_RepairBanner.build`; `app/lib/ui/settings/settings_flow.dart` - `_pushEnrollmentRoute`.
