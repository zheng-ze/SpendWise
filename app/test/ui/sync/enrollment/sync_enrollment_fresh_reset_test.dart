import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/sync_coordinator.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

import '../../../support/recording_ledger_store.dart';
import 'sync_enrollment_flow_test.dart' show FakeSessionOpener, pumpFlowFrames;
import '../../../sync/in_memory_secret_store.dart';

const _identifierField = Key('syncIdentifierField');
const _otpField = Key('syncOtpField');
const _otpSubmit = Key('syncOtpSubmit');
const _freshDone = Key('syncFreshDone');

final class _Harness {
  late LedgerDatabase db;
  late SyncMetadataStore metadataStore;
  late FakeSessionOpener opener;
  late InMemorySecretStore secrets;
  late ProviderContainer container;
  DateTime clock = DateTime.utc(2026, 1, 1);

  void build() {
    db = LedgerDatabase(NativeDatabase.memory());
    metadataStore = SyncMetadataStore(db);
    opener = FakeSessionOpener();
    secrets = InMemorySecretStore();
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
  }

  void dispose() {
    container.dispose();
    db.close();
  }

  SyncEnrollmentNotifier get notifier =>
      container.read(syncEnrollmentViewModelProvider.notifier);

  SyncEnrollmentState get state =>
      container.read(syncEnrollmentViewModelProvider);
}

final class _RecordingWriter implements BackendSelectionWriter {
  final List<({SyncBackendKind backend, String? endpoint})> calls = [];

  @override
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) async {
    calls.add((backend: backend, endpoint: endpoint));
  }
}

Future<void> _submitIdentifier(WidgetTester tester, String identifier) async {
  await tester.enterText(find.byKey(_identifierField), identifier);
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pump();
}

void main() {
  group('enterFreshMode', () {
    test(
      'clears repair-only state while preserving identifier and cooldown',
      () async {
        final harness = _Harness();
        harness.build();
        addTearDown(harness.dispose);
        await harness.metadataStore.enterBindingAuthorizationRequired();
        await harness.notifier.enterRepairMode();
        expect(harness.state.repairMode, isTrue);
        harness.opener.session.onEnroll = () async {
          await harness.opener.session.resolveOtp!(
            EnrollmentChallenge(const {'identifier': 'user@example.com'}),
          );
        };
        final pending = harness.notifier.submitIdentifier('user@example.com');
        for (var i = 0; i < 100 && !harness.state.otpWaiting; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(harness.state.otpWaiting, isTrue);
        harness.notifier.cancelOtp();
        await pending;
        expect(harness.state.identifier, 'user@example.com');
        expect(harness.state.codeCooldownEndsAt, isNotNull);

        harness.notifier.enterFreshMode();

        final state = harness.state;
        expect(state.repairMode, isFalse);
        expect(state.repairPhase, isNull);
        expect(state.explainCodeReplacement, isFalse);
        expect(state.step, isNull);
        expect(state.errorMessage, isNull);
        expect(state.cancelled, isFalse);
        expect(state.otpWaiting, isFalse);
        expect(state.inFlight, isFalse);
        expect(state.identifier, 'user@example.com');
        expect(state.codeCooldownEndsAt, isNotNull);
      },
    );

    test('leaves a live operation untouched', () async {
      final harness = _Harness();
      harness.build();
      addTearDown(harness.dispose);
      await harness.metadataStore.enterBindingAuthorizationRequired();
      await harness.notifier.enterRepairMode();
      final gate = Completer<void>();
      harness.opener.session.onEnroll = () => gate.future;
      final pending = harness.notifier.submitIdentifier('user@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(harness.state.inFlight, isTrue);

      harness.notifier.enterFreshMode();

      expect(harness.state.inFlight, isTrue);
      expect(harness.state.repairMode, isTrue);
      expect(harness.state.explainCodeReplacement, isTrue);
      expect(harness.state.identifier, 'user@example.com');

      gate.complete();
      await pending;
      expect(harness.state.inFlight, isFalse);
      expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    });
  });

  group('repair then fresh in one container', () {
    testWidgets('fresh entry restores fresh semantics', (tester) async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final metadataStore = SyncMetadataStore(db);
      await metadataStore.enterBindingAuthorizationRequired();
      final opener = FakeSessionOpener();
      final secrets = InMemorySecretStore();
      final writer = _RecordingWriter();
      var clock = DateTime.utc(2026, 1, 1);
      final container = ProviderContainer(
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
          backendPickerViewModelProvider.overrideWith(
            () => BackendPickerNotifier(writer: writer),
          ),
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SyncEnrollmentFlow(repairMode: true)),
        ),
      );
      await pumpFlowFrames(tester);
      expect(find.text('Repair Device Access'), findsOneWidget);

      await secrets.write(syncWriteProofSecretKey, 'proof-1');
      opener.session.onEnroll = () async {
        await opener.session.resolveOtp!(
          EnrollmentChallenge(const {'identifier': 'user@example.com'}),
        );
      };
      opener.session.onPublish = () async => const EnrollmentSnapshotPending(
        collection: SyncCollection.entries,
        result: PushDeferred(),
      );
      await _submitIdentifier(tester, 'user@example.com');
      await pumpFlowFrames(tester);
      expect(find.byKey(_otpField), findsOneWidget);

      await tester.enterText(find.byKey(_otpField), '482916');
      await tester.pump();
      await tester.tap(find.byKey(_otpSubmit));
      await pumpFlowFrames(tester);

      expect(
        container.read(syncEnrollmentViewModelProvider).errorMessage,
        contains('pending'),
      );

      container
          .read(backendPickerViewModelProvider.notifier)
          .selectBackend(SyncBackendKind.custom);
      container
          .read(backendPickerViewModelProvider.notifier)
          .updateEndpoint('https://sync.example.com/sync');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Text('flow host gone')),
          ),
        ),
      );
      await pumpFlowFrames(tester);

      var endedCalls = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SyncEnrollmentFlow(onEnded: () => endedCalls++),
          ),
        ),
      );
      await pumpFlowFrames(tester);

      expect(find.text('Choose sync backend'), findsOneWidget);
      expect(find.text('Server URL'), findsNothing);
      final pickerState = container.read(backendPickerViewModelProvider);
      expect(pickerState.selectedBackend, SyncBackendKind.supabase);
      expect(pickerState.endpoint, isEmpty);

      await tester.tap(find.text('Continue'));
      await pumpFlowFrames(tester);

      expect(find.text('Hosted sync sign-in'), findsOneWidget);
      expect(find.text('Repair Device Access'), findsNothing);
      expect(
        find.text(
          'Requesting a new code replaces the previous one. '
          'Only the newest code will work.',
        ),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(find.byKey(_identifierField)).controller?.text,
        'user@example.com',
      );

      clock = clock.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 2));
      opener.session.onEnroll = () async {
        await opener.session.resolveOtp!(
          EnrollmentChallenge(const {'identifier': 'user@example.com'}),
        );
      };
      opener.session.onPublish = null;
      await _submitIdentifier(tester, 'user@example.com');
      await pumpFlowFrames(tester);

      expect(find.byKey(_otpField), findsOneWidget);
      expect(
        find.text('Requesting a new code replaces the previous one.'),
        findsNothing,
      );

      await tester.enterText(find.byKey(_otpField), '482916');
      await tester.pump();
      await tester.tap(find.byKey(_otpSubmit));
      await pumpFlowFrames(tester);

      expect(find.text('Sync enrollment complete'), findsOneWidget);
      expect(find.byKey(_freshDone), findsOneWidget);
      expect(writer.calls.single.backend, SyncBackendKind.supabase);

      await tester.tap(find.byKey(_freshDone));
      await pumpFlowFrames(tester);
      expect(endedCalls, 1);
    });
  });
}
