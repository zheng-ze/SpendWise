import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_database.dart' show LedgerDatabase;
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

import '../../../support/recording_ledger_store.dart';
import '../../../sync/in_memory_secret_store.dart';
import 'sync_enrollment_flow_test.dart'
    show FakeSessionOpener, FakeSyncEnrollmentSession;

const _identifierField = Key('syncIdentifierField');
const _identifierContinue = Key('syncIdentifierContinue');
const _otpField = Key('syncOtpField');
const _otpSubmit = Key('syncOtpSubmit');
const _otpBack = Key('syncOtpBack');
const _otpNewCode = Key('syncOtpNewCode');
const _repairDone = Key('syncRepairDone');
const _resumeRetry = Key('syncResumeRetry');

final class _Harness {
  late LedgerDatabase db;
  late SyncMetadataStore metadataStore;
  late FakeSessionOpener opener;
  late InMemorySecretStore secrets;
  late ProviderContainer container;
  DateTime clock = DateTime.utc(2026, 1, 1);
  int endedCalls = 0;

  Future<void> pumpRepairFlow(
    WidgetTester tester, {
    SyncEnrollmentPhase? seedPhase,
  }) async {
    db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    metadataStore = SyncMetadataStore(db);
    if (seedPhase == SyncEnrollmentPhase.bindingAuthorizationRequired) {
      await metadataStore.enterBindingAuthorizationRequired();
    } else if (seedPhase == SyncEnrollmentPhase.sessionReauthRequired) {
      await metadataStore.enterSnapshotInProgress();
      await metadataStore.enterSessionReauthRequired();
    }
    opener = FakeSessionOpener();
    secrets = InMemorySecretStore();
    final now = clock;
    container = ProviderContainer(
      overrides: [
        appBootProvider.overrideWith(
          (ref) => AppBoot(
            createStore: () async => RecordingLedgerStore(),
            seedChanges: () => const [],
            readSyncSnapshot: () => metadataStore.snapshot(),
          ),
        ),
        ledgerDatabaseProvider.overrideWithValue(db),
        syncMetadataStoreProvider.overrideWithValue(metadataStore),
        syncEnrollmentViewModelProvider.overrideWith(
          () => SyncEnrollmentNotifier(
            sessionOpener: opener.call,
            secretStore: secrets,
            now: () => clock,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    clock = now;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SyncEnrollmentFlow(
            repairMode: true,
            onEnded: () => endedCalls++,
          ),
        ),
      ),
    );
    await pumpRepairFrames(tester);
  }

  SyncEnrollmentState get state =>
      container.read(syncEnrollmentViewModelProvider);
}

Future<void> pumpRepairFrames(WidgetTester tester) async {
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
  FakeSyncEnrollmentSession session,
) async {
  session.onEnroll = () async {
    await session.resolveOtp!(
      EnrollmentChallenge(const {'identifier': 'user@example.com'}),
    );
  };
  await submitIdentifier(tester, 'user@example.com');
  await pumpRepairFrames(tester);
}

void main() {
  group('repair identifier and OTP copy', () {
    testWidgets('identifier entry explains code replacement', (tester) async {
      final harness = _Harness();
      await harness.pumpRepairFlow(
        tester,
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );

      expect(find.text('Repair Device Access'), findsOneWidget);
      expect(
        find.text(
          'Requesting a new code replaces the previous one. '
          'Only the newest code will work.',
        ),
        findsOneWidget,
      );
      expect(find.byType(BackendPickerScreen), findsNothing);
    });

    testWidgets('OTP entry explains replacement and gates the new-code '
        'action on the cooldown', (tester) async {
      final harness = _Harness();
      await harness.pumpRepairFlow(
        tester,
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      await driveToOtpEntry(tester, harness.opener.session);

      expect(find.byKey(_otpField), findsOneWidget);
      expect(
        find.text('Requesting a new code replaces the previous one.'),
        findsOneWidget,
      );
      final gated = tester.widget<TextButton>(find.byKey(_otpNewCode));
      expect(gated.onPressed, isNull);
      expect(find.text('Send a new code in 60s'), findsOneWidget);

      harness.clock = harness.clock.add(const Duration(seconds: 61));
      await pumpRepairFrames(tester);

      final released = tester.widget<TextButton>(find.byKey(_otpNewCode));
      expect(released.onPressed, isNotNull);
      expect(find.text('Send a new code'), findsOneWidget);
    });
  });

  group('repair completion', () {
    testWidgets('repair shows progress once the OTP is accepted, with '
        'no entry action enabled', (tester) async {
      final harness = _Harness();
      await harness.pumpRepairFlow(
        tester,
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      final enrollGate = Completer<void>();
      harness.opener.session.onEnroll = () async {
        await harness.opener.session.resolveOtp!(
          EnrollmentChallenge(const {'identifier': 'user@example.com'}),
        );
        await enrollGate.future;
      };
      await submitIdentifier(tester, 'user@example.com');
      await pumpRepairFrames(tester);
      expect(find.byKey(_otpField), findsOneWidget);

      await tester.enterText(find.byKey(_otpField), '482916');
      await tester.pump();
      await tester.tap(find.byKey(_otpSubmit));
      await pumpRepairFrames(tester);

      expect(
        find.text(
          'Restoring device access. '
          'Reconciling and publishing this device. Keep the app open.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(_otpField), findsNothing);
      expect(find.byKey(_identifierField), findsNothing);
      final retry = tester.widget<FilledButton>(find.byKey(_resumeRetry));
      expect(retry.onPressed, isNull);

      enrollGate.complete();
      await pumpRepairFrames(tester);

      expect(find.text('Device access restored'), findsOneWidget);
    });

    testWidgets('identifier to OTP ends in device-access-restored '
        'completion, and Done ends the flow', (tester) async {
      final harness = _Harness();
      await harness.pumpRepairFlow(
        tester,
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      await driveToOtpEntry(tester, harness.opener.session);

      await tester.enterText(find.byKey(_otpField), '482916');
      await tester.pump();
      await tester.tap(find.byKey(_otpSubmit));
      await pumpRepairFrames(tester);

      expect(find.text('Device access restored'), findsOneWidget);
      expect(find.text('Sync writes have resumed.'), findsOneWidget);

      await tester.tap(find.byKey(_repairDone));
      await pumpRepairFrames(tester);

      expect(harness.endedCalls, 1);
    });
  });

  group('repair cancellation and routing', () {
    for (final phase in [
      SyncEnrollmentPhase.bindingAuthorizationRequired,
      SyncEnrollmentPhase.sessionReauthRequired,
    ]) {
      testWidgets('cancelling OTP from $phase preserves the durable '
          'disabled state and keeps one identifier route', (tester) async {
        final harness = _Harness();
        await harness.pumpRepairFlow(tester, seedPhase: phase);
        await driveToOtpEntry(tester, harness.opener.session);
        expect(find.byKey(_otpField), findsOneWidget);

        await tester.tap(find.byKey(_otpBack));
        await pumpRepairFrames(tester);

        expect(find.byKey(_identifierField), findsOneWidget);
        final snapshot = await harness.metadataStore.snapshot();
        expect(snapshot.phase, phase);
        expect(snapshot.writeEnabled, isFalse);
        expect(
          tester.widgetList(
            find.byType(SyncIdentifierScreen, skipOffstage: false),
          ),
          hasLength(1),
        );

        harness.clock = harness.clock.add(const Duration(seconds: 61));
        // Let the cooldown ticker rebuild past expiry before submitting.
        await tester.pump(const Duration(seconds: 2));
        harness.opener.session.onEnroll = () async {
          throw const SyncEnrollmentException(
            step: 'completeEnrollment',
            code: 'invalid_request',
            message: 'server: bad otp 482916 for user@example.com',
          );
        };
        await submitIdentifier(tester, 'user@example.com');
        await pumpRepairFrames(tester);

        expect(find.byKey(_identifierField), findsOneWidget);
        expect(
          tester.widgetList(
            find.byType(SyncIdentifierScreen, skipOffstage: false),
          ),
          hasLength(1),
        );
        final failed = harness.container.read(syncEnrollmentViewModelProvider);
        expect(failed.errorMessage, contains('not accepted'));
        expect(failed.errorMessage, isNot(contains('482916')));
        final retrySnapshot = await harness.metadataStore.snapshot();
        expect(retrySnapshot.phase, phase);
        expect(retrySnapshot.writeEnabled, isFalse);
      });
    }

    testWidgets('disposing the flow while an OTP is pending releases '
        'the guard and preserves the durable phase', (tester) async {
      final harness = _Harness();
      await harness.pumpRepairFlow(
        tester,
        seedPhase: SyncEnrollmentPhase.bindingAuthorizationRequired,
      );
      await driveToOtpEntry(tester, harness.opener.session);
      expect(
        harness.container.read(syncEnrollmentViewModelProvider).inFlight,
        isTrue,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const MaterialApp(home: Scaffold(body: Text('flow gone'))),
        ),
      );
      await pumpRepairFrames(tester);

      expect(
        harness.container.read(syncEnrollmentViewModelProvider).inFlight,
        isFalse,
      );
      expect(
        () => harness.opener.session.resolveOtp!(
          EnrollmentChallenge(const {'identifier': 'user@example.com'}),
        ),
        throwsA(isA<SyncEnrollmentOtpCancelled>()),
      );
      final snapshot = await harness.metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
      expect(snapshot.writeEnabled, isFalse);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(
            home: SyncEnrollmentFlow(
              repairMode: true,
              onEnded: () => harness.endedCalls++,
            ),
          ),
        ),
      );
      await pumpRepairFrames(tester);

      expect(find.byKey(_identifierField), findsOneWidget);
      harness.clock = harness.clock.add(const Duration(seconds: 61));
      // Let the cooldown ticker rebuild past expiry before submitting.
      await tester.pump(const Duration(seconds: 2));
      harness.opener.session.onEnroll = () async {};
      await submitIdentifier(tester, 'fresh@example.com');
      await pumpRepairFrames(tester);

      expect(harness.opener.session.enrollCalls, 2);
      expect(find.text('Device access restored'), findsOneWidget);
    });

    testWidgets('entering with the repair phase already cleared ends '
        'the flow and refreshes status', (tester) async {
      final harness = _Harness();
      await harness.pumpRepairFlow(tester);

      expect(harness.endedCalls, 1);
      final snapshot = await harness.metadataStore.snapshot();
      expect(
        harness.container.read(hostedSyncStatusProvider),
        projectHostedSyncStatus(snapshot),
      );
    });
  });
}
