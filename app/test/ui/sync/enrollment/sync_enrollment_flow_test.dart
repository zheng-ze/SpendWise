import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/sync_coordinator.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_enrollment_session.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

const _identifierField = Key('syncIdentifierField');
const _identifierContinue = Key('syncIdentifierContinue');
const _otpField = Key('syncOtpField');
const _otpSubmit = Key('syncOtpSubmit');
const _otpBack = Key('syncOtpBack');
const _resumeRetry = Key('syncResumeRetry');

final class FakeBackendSelectionWriter implements BackendSelectionWriter {
  final List<({SyncBackendKind backend, String? endpoint})> calls = [];

  @override
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) async {
    calls.add((backend: backend, endpoint: endpoint));
  }
}

final class FakeSyncEnrollmentSession implements SyncEnrollmentSession {
  Future<void> Function()? onEnroll;
  Future<EnrollmentSnapshotPublishResult> Function()? onPublish;
  Future<String> Function(EnrollmentChallenge challenge)? resolveOtp;

  int enrollCalls = 0;
  int publishCalls = 0;
  int resolveOtpCalls = 0;

  @override
  Future<void> enroll() async {
    enrollCalls++;
    await onEnroll?.call();
  }

  @override
  Future<EnrollmentSnapshotPublishResult> publishSnapshot() async {
    publishCalls++;
    final handler = onPublish;
    if (handler == null) return const EnrollmentSnapshotPublished();
    return handler();
  }
}

final class FakeSessionOpener {
  FakeSyncEnrollmentSession session = FakeSyncEnrollmentSession();
  SyncEnrollmentSessionResult? nextResult;
  Object? errorOnOpen;

  int openCalls = 0;
  final List<String> identifiers = [];

  Future<SyncEnrollmentSessionResult> call({
    required String identifier,
    required Future<String> Function(EnrollmentChallenge challenge) resolveOtp,
  }) async {
    openCalls++;
    identifiers.add(identifier);
    final error = errorOnOpen;
    if (error != null) throw error;
    session.resolveOtp = (challenge) {
      session.resolveOtpCalls++;
      return resolveOtp(challenge);
    };
    return nextResult ?? SyncEnrollmentSessionReady(session);
  }
}

Future<
  ({
    ProviderContainer container,
    FakeBackendSelectionWriter writer,
    FakeSessionOpener opener,
    SyncMetadataStore metadataStore,
  })
>
pumpEnrollmentFlow(
  WidgetTester tester, {
  FakeSessionOpener? opener,
  VoidCallback? onEnded,
}) async {
  final db = LedgerDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final writer = FakeBackendSelectionWriter();
  final sessionOpener = opener ?? FakeSessionOpener();
  final container = ProviderContainer(
    overrides: [
      ledgerDatabaseProvider.overrideWithValue(db),
      syncMetadataStoreProvider.overrideWithValue(SyncMetadataStore(db)),
      backendPickerViewModelProvider.overrideWith(
        () => BackendPickerNotifier(writer: writer),
      ),
      syncEnrollmentViewModelProvider.overrideWith(
        () => SyncEnrollmentNotifier(sessionOpener: sessionOpener.call),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: SyncEnrollmentFlow(onEnded: onEnded)),
    ),
  );
  await pumpFlowFrames(tester);
  return (
    container: container,
    writer: writer,
    opener: sessionOpener,
    metadataStore: SyncMetadataStore(db),
  );
}

Future<void> continueWithHosted(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await pumpFlowFrames(tester);
}

Future<void> pumpFlowFrames(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> submitIdentifier(WidgetTester tester, String identifier) async {
  await tester.enterText(find.byKey(_identifierField), identifier);
  await tester.pump();
  await tester.tap(find.byKey(_identifierContinue));
  await tester.pump();
}

Future<void> driveToOtpEntry(
  WidgetTester tester,
  FakeSyncEnrollmentSession session, {
  String identifier = 'user@example.com',
}) async {
  session.onEnroll = () async {
    await session.resolveOtp!(
      EnrollmentChallenge(const {'identifier': 'user@example.com'}),
    );
  };
  await submitIdentifier(tester, identifier);
  await pumpFlowFrames(tester);
}

void main() {
  testWidgets('hosted selection persists and advances to identifier entry', (
    tester,
  ) async {
    final harness = await pumpEnrollmentFlow(tester);

    await continueWithHosted(tester);

    expect(harness.writer.calls, hasLength(1));
    expect(harness.writer.calls.single.backend, SyncBackendKind.supabase);
    expect(find.byKey(_identifierField), findsOneWidget);
  });

  testWidgets('identifier then OTP completes enrollment and publication', (
    tester,
  ) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    String? seenOtp;
    harness.opener.session.onEnroll = () async {
      seenOtp = await harness.opener.session.resolveOtp!(
        EnrollmentChallenge(const {'identifier': 'user@example.com'}),
      );
    };

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);

    expect(harness.opener.identifiers, ['user@example.com']);
    expect(find.byKey(_otpField), findsOneWidget);

    await tester.enterText(find.byKey(_otpField), '482916');
    await tester.pump();
    await tester.tap(find.byKey(_otpSubmit));
    await pumpFlowFrames(tester);

    expect(seenOtp, '482916');
    expect(harness.opener.session.enrollCalls, 1);
    expect(harness.opener.session.publishCalls, 1);
    expect(find.text('Sync enrollment complete'), findsOneWidget);
  });

  testWidgets('a second action while an operation is active is ignored', (
    tester,
  ) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    final gate = Completer<void>();
    harness.opener.session.onEnroll = () => gate.future;
    final viewModel = harness.container.read(
      syncEnrollmentViewModelProvider.notifier,
    );

    await submitIdentifier(tester, 'user@example.com');
    viewModel.submitIdentifier('second@example.com');
    await viewModel.retry();
    await tester.pump();

    expect(harness.opener.session.enrollCalls, 1);
    expect(harness.opener.openCalls, 1);

    gate.complete();
    await pumpFlowFrames(tester);

    expect(find.text('Sync enrollment complete'), findsOneWidget);
    expect(harness.opener.session.enrollCalls, 1);
  });

  testWidgets('backing out of OTP cancels, clears the guard, '
      'and accepts a fresh submission', (tester) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    await driveToOtpEntry(tester, harness.opener.session);
    expect(find.byKey(_otpField), findsOneWidget);

    await tester.tap(find.byKey(_otpBack));
    await pumpFlowFrames(tester);

    final cancelledState = harness.container.read(
      syncEnrollmentViewModelProvider,
    );
    expect(cancelledState.cancelled, isTrue);
    expect(cancelledState.inFlight, isFalse);
    expect(cancelledState.errorMessage, isNull);
    expect(find.byKey(_identifierField), findsOneWidget);
    expect(harness.opener.session.enrollCalls, 1);

    harness.opener.session.onEnroll = () async {};
    await submitIdentifier(tester, 'fresh@example.com');
    await pumpFlowFrames(tester);

    expect(harness.opener.session.enrollCalls, 2);
    expect(harness.opener.identifiers.last, 'fresh@example.com');
    expect(find.text('Sync enrollment complete'), findsOneWidget);
  });

  testWidgets('a typed failure before credential persistence '
      'is an ordinary error retried from identifier entry', (tester) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    harness.opener.session.onEnroll = () async {
      throw const SyncEnrollmentException(
        step: 'completeEnrollment',
        code: 'invalid_otp',
      );
    };

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);

    expect(find.byKey(_identifierField), findsOneWidget);
    expect(find.byKey(_resumeRetry), findsNothing);
    final failed = harness.container.read(syncEnrollmentViewModelProvider);
    expect(failed.errorMessage, isNotNull);
    expect(failed.inFlight, isFalse);
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.notEnrolled,
    );

    harness.opener.session.onEnroll = () async {};
    await tester.tap(find.byKey(_identifierContinue));
    await pumpFlowFrames(tester);

    expect(find.text('Sync enrollment complete'), findsOneWidget);
  });

  testWidgets('a post-credential failure retries from the resume screen '
      'without re-collecting identifier or OTP', (tester) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    await harness.metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.credentialAcquired,
    );
    harness.opener.session.onEnroll = () async {
      throw const SyncEnrollmentException(
        step: 'reconcileBegin',
        code: 'unavailable',
      );
    };

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);

    expect(find.byKey(_resumeRetry), findsOneWidget);
    expect(find.byKey(_otpField), findsNothing);
    expect(harness.opener.session.resolveOtpCalls, 0);

    harness.opener.session.onEnroll = () async {};
    await tester.tap(find.byKey(_resumeRetry));
    await pumpFlowFrames(tester);

    expect(harness.opener.openCalls, 1);
    expect(harness.opener.session.enrollCalls, 2);
    expect(harness.opener.session.resolveOtpCalls, 0);
    expect(find.text('Sync enrollment complete'), findsOneWidget);
  });

  testWidgets('completion waits until the publisher reports published', (
    tester,
  ) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    final results = <EnrollmentSnapshotPublishResult>[
      const EnrollmentSnapshotPending(
        collection: SyncCollection.entries,
        result: PushDeferred(),
      ),
      const EnrollmentSnapshotPublished(),
    ];
    var publishIndex = 0;
    harness.opener.session.onEnroll = () async {
      await harness.opener.session.resolveOtp!(
        EnrollmentChallenge(const {'identifier': 'user@example.com'}),
      );
    };
    harness.opener.session.onPublish = () async => results[publishIndex++];

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);
    await tester.enterText(find.byKey(_otpField), '482916');
    await tester.pump();
    await tester.tap(find.byKey(_otpSubmit));
    await pumpFlowFrames(tester);

    expect(harness.opener.session.publishCalls, 2);
    expect(find.text('Sync enrollment complete'), findsOneWidget);
  });

  testWidgets('a not-ready composition surfaces an ordinary error '
      'without enrolling', (tester) async {
    final opener = FakeSessionOpener()
      ..nextResult = const SyncEnrollmentSessionNotReady(
        ledgerReady: false,
        persistenceReady: true,
      );
    final harness = await pumpEnrollmentFlow(tester, opener: opener);
    await continueWithHosted(tester);

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);

    final state = harness.container.read(syncEnrollmentViewModelProvider);
    expect(state.errorMessage, isNotNull);
    expect(find.byKey(_identifierField), findsOneWidget);
    expect(harness.opener.session.enrollCalls, 0);
    expect(harness.opener.session.publishCalls, 0);
  });

  testWidgets('custom selection keeps its unavailable affordance '
      'and never opens hosted enrollment', (tester) async {
    final harness = await pumpEnrollmentFlow(tester);
    final picker = harness.container.read(
      backendPickerViewModelProvider.notifier,
    );

    picker.selectBackend(SyncBackendKind.custom);
    picker.updateEndpoint('https://sync.example.com/sync');
    await picker.continueWithSelection();
    await tester.pump();

    expect(harness.writer.calls, hasLength(1));
    expect(harness.writer.calls.single.backend, SyncBackendKind.custom);
    expect(find.text('Custom servers are not yet available.'), findsOneWidget);
    expect(find.byKey(_identifierField), findsNothing);
    expect(harness.opener.openCalls, 0);
  });

  testWidgets('a persistently pending publisher gives up bounded and '
      'surfaces a retryable resume error', (tester) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    await harness.metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.credentialAcquired,
    );
    harness.opener.session.onEnroll = () async {};
    harness.opener.session.onPublish = () async =>
        const EnrollmentSnapshotPending(
          collection: SyncCollection.entries,
          result: PushDeferred(),
        );

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);

    expect(
      harness.opener.session.publishCalls,
      SyncEnrollmentNotifier.maxPublishAttempts,
    );
    final state = harness.container.read(syncEnrollmentViewModelProvider);
    expect(state.inFlight, isFalse);
    expect(state.errorMessage, isNotNull);
    expect(find.byKey(_resumeRetry), findsOneWidget);
    expect(find.text('Sync enrollment complete'), findsNothing);

    final callsAfterGivingUp = harness.opener.session.publishCalls;
    await pumpFlowFrames(tester);
    expect(harness.opener.session.publishCalls, callsAfterGivingUp);
  });

  testWidgets('repeated failures accumulate exactly one resume route', (
    tester,
  ) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    await harness.metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.credentialAcquired,
    );
    harness.opener.session.onEnroll = () async {
      throw const SyncEnrollmentException(
        step: 'reconcileBegin',
        code: 'unavailable',
      );
    };

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);
    expect(find.byType(SyncEnrollmentResumeScreen), findsOneWidget);

    await tester.tap(find.byKey(_resumeRetry));
    await pumpFlowFrames(tester);

    expect(find.byType(SyncEnrollmentResumeScreen), findsOneWidget);
    expect(find.byKey(_identifierField), findsNothing);
    expect(find.byKey(_otpField), findsNothing);
    expect(
      harness.container.read(syncEnrollmentViewModelProvider).errorMessage,
      isNotNull,
    );
  });

  testWidgets('back from completion ends the flow without stale screens', (
    tester,
  ) async {
    var endedCalls = 0;
    final harness = await pumpEnrollmentFlow(
      tester,
      onEnded: () => endedCalls++,
    );
    await continueWithHosted(tester);
    harness.opener.session.onEnroll = () async {};
    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);

    expect(find.text('Sync enrollment complete'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await pumpFlowFrames(tester);

    expect(endedCalls, 1);
    expect(find.byKey(_identifierField), findsNothing);
    expect(find.byKey(_otpField), findsNothing);
    expect(find.byKey(_resumeRetry), findsNothing);
    expect(find.byType(BackendPickerScreen), findsNothing);
  });

  testWidgets('back is blocked while identifier submission is in flight '
      'and allowed again after failure', (tester) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    final gate = Completer<void>();
    harness.opener.session.onEnroll = () async {
      await gate.future;
      throw const SyncEnrollmentException(
        step: 'beginEnrollment',
        code: 'unavailable',
      );
    };

    await submitIdentifier(tester, 'user@example.com');
    await tester.pump();
    expect(
      harness.container.read(syncEnrollmentViewModelProvider).inFlight,
      isTrue,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(_identifierField), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(
      find.byKey(_identifierField),
      findsOneWidget,
      reason: 'the AppBar back affordance cannot pop while back is gated',
    );
    expect(find.byType(BackendPickerScreen), findsNothing);

    gate.complete();
    await pumpFlowFrames(tester);
    expect(
      harness.container.read(syncEnrollmentViewModelProvider).inFlight,
      isFalse,
    );
    expect(find.byKey(_identifierField), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await pumpFlowFrames(tester);
    expect(find.byType(BackendPickerScreen), findsOneWidget);
    expect(find.byKey(_identifierField), findsNothing);
  });

  testWidgets('an opener-level throw on identifier submission surfaces '
      'an ordinary in-flow error', (tester) async {
    final opener = FakeSessionOpener()
      ..errorOnOpen = const SyncCoordinatorWiringException();
    final harness = await pumpEnrollmentFlow(tester, opener: opener);
    await continueWithHosted(tester);

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);

    final state = harness.container.read(syncEnrollmentViewModelProvider);
    expect(state.errorMessage, isNotNull);
    expect(state.inFlight, isFalse);
    expect(find.byKey(_identifierField), findsOneWidget);
  });

  testWidgets('an opener-level throw on retry surfaces an ordinary '
      'in-flow error on the resume screen', (tester) async {
    final opener = FakeSessionOpener()
      ..errorOnOpen = const SyncCoordinatorWiringException();
    final harness = await pumpEnrollmentFlow(tester, opener: opener);
    await continueWithHosted(tester);
    await harness.metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.credentialAcquired,
    );

    await submitIdentifier(tester, 'user@example.com');
    await pumpFlowFrames(tester);
    expect(find.byKey(_resumeRetry), findsOneWidget);

    await tester.tap(find.byKey(_resumeRetry));
    await pumpFlowFrames(tester);

    final state = harness.container.read(syncEnrollmentViewModelProvider);
    expect(state.errorMessage, isNotNull);
    expect(state.inFlight, isFalse);
    expect(find.byKey(_resumeRetry), findsOneWidget);
    expect(harness.opener.openCalls, 2);
  });

  testWidgets('disposing the flow while an OTP is pending unlocks '
      'the notifier for a fresh submission', (tester) async {
    final harness = await pumpEnrollmentFlow(tester);
    await continueWithHosted(tester);
    await driveToOtpEntry(tester, harness.opener.session);
    expect(
      harness.container.read(syncEnrollmentViewModelProvider).inFlight,
      isTrue,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const MaterialApp(home: Scaffold(body: Text('flow host gone'))),
      ),
    );
    await pumpFlowFrames(tester);
    expect(
      harness.container.read(syncEnrollmentViewModelProvider).inFlight,
      isFalse,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const MaterialApp(home: SyncEnrollmentFlow()),
      ),
    );
    await pumpFlowFrames(tester);

    harness.opener.session.onEnroll = () async {};
    await continueWithHosted(tester);
    await submitIdentifier(tester, 'fresh@example.com');
    await pumpFlowFrames(tester);

    expect(harness.opener.session.enrollCalls, 2);
    expect(find.text('Sync enrollment complete'), findsOneWidget);
  });
}
