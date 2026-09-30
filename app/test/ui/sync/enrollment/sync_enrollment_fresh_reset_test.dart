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
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
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
const _pickerBack = Key('syncPickerBack');

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
  Completer<void>? gate;
  final List<({SyncBackendKind backend, String? endpoint})> calls = [];

  @override
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) async {
    calls.add((backend: backend, endpoint: endpoint));
    final pending = gate;
    if (pending != null) await pending.future;
  }
}

Future<void> _pumpFreshFlow(
  WidgetTester tester,
  ProviderContainer container, {
  VoidCallback? onEnded,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: SyncEnrollmentFlow(onEnded: onEnded)),
    ),
  );
  await pumpFlowFrames(tester);
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

    test('a live operation settles before the reset applies', () async {
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

      final freshEntry = harness.notifier.enterFreshMode();
      expect(harness.state.repairMode, isTrue);

      gate.complete();
      await pending;
      await freshEntry;

      final state = harness.state;
      expect(state.inFlight, isFalse);
      expect(state.repairMode, isFalse);
      expect(state.repairPhase, isNull);
      expect(state.explainCodeReplacement, isFalse);
      expect(state.step, isNull);
      expect(state.identifier, 'user@example.com');
    });

    test('an older completion cannot release a newer pending enroll', () async {
      final harness = _Harness();
      harness.build();
      addTearDown(harness.dispose);
      await harness.metadataStore.enterBindingAuthorizationRequired();
      await harness.notifier.enterRepairMode();
      await harness.secrets.write(syncWriteProofSecretKey, 'proof-1');
      var enrollCalls = 0;
      final gateA = Completer<void>();
      final gateB = Completer<void>();
      harness.opener.session.onEnroll = () async {
        enrollCalls++;
        if (enrollCalls == 1) {
          await gateA.future;
        } else {
          await gateB.future;
        }
      };

      final pendingA = harness.notifier.submitIdentifier('user@example.com');
      for (var i = 0; i < 100 && enrollCalls < 1; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(enrollCalls, 1);

      harness.notifier.cancelPendingOperation();
      for (var i = 0; i < 100 && harness.state.inFlight; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final pendingB = harness.notifier.submitIdentifier('user@example.com');
      for (var i = 0; i < 100 && enrollCalls < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(enrollCalls, 2);
      expect(harness.state.inFlight, isTrue);

      harness.notifier.cancelPendingOperation();
      for (var i = 0; i < 100 && harness.state.inFlight; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      var freshApplied = false;
      final freshEntry = harness.notifier.enterFreshMode().then((_) {
        freshApplied = true;
      });
      expect(harness.state.repairMode, isTrue);
      expect(freshApplied, isFalse);

      gateA.complete();
      await pendingA;
      expect(harness.opener.session.publishCalls, 1);
      expect(freshApplied, isFalse);
      expect(harness.state.repairMode, isTrue);

      gateB.complete();
      await pendingB;
      await freshEntry;

      expect(freshApplied, isTrue);
      expect(harness.state.repairMode, isFalse);
      expect(harness.state.repairPhase, isNull);
      expect(harness.state.explainCodeReplacement, isFalse);
      expect(harness.opener.session.publishCalls, 2);
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

    testWidgets('a cancelled repair enroll publishes its proof before fresh '
        'mode applies', (tester) async {
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

      await secrets.write(syncWriteProofSecretKey, 'proof-1');
      final enrollGate = Completer<void>();
      opener.session.onEnroll = () async {
        await opener.session.resolveOtp!(
          EnrollmentChallenge(const {'identifier': 'user@example.com'}),
        );
        await enrollGate.future;
      };
      await _submitIdentifier(tester, 'user@example.com');
      await pumpFlowFrames(tester);
      expect(find.byKey(_otpField), findsOneWidget);

      await tester.enterText(find.byKey(_otpField), '482916');
      await tester.pump();
      await tester.tap(find.byKey(_otpSubmit));
      await pumpFlowFrames(tester);
      expect(find.textContaining('Restoring device access'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Text('flow host gone')),
          ),
        ),
      );
      await pumpFlowFrames(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SyncEnrollmentFlow()),
        ),
      );
      await pumpFlowFrames(tester);
      expect(
        find.text(
          'Finishing the previous attempt. This usually takes a few seconds.',
        ),
        findsOneWidget,
      );
      expect(find.text('Hosted sync'), findsNothing);
      expect(
        container.read(syncEnrollmentViewModelProvider).repairMode,
        isTrue,
      );

      enrollGate.complete();
      await pumpFlowFrames(tester);

      expect(opener.session.publishCalls, 1);
      expect(
        container.read(syncEnrollmentViewModelProvider).repairMode,
        isFalse,
      );
      expect(find.text('Choose sync backend'), findsOneWidget);
      expect(find.text('Hosted sync'), findsOneWidget);
    });

    testWidgets('a settling prior save never advances the new picker', (
      tester,
    ) async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final metadataStore = SyncMetadataStore(db);
      final opener = FakeSessionOpener();
      final secrets = InMemorySecretStore();
      final writer = _RecordingWriter()..gate = Completer<void>();
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
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SyncEnrollmentFlow(onEnded: () {})),
        ),
      );
      await pumpFlowFrames(tester);
      expect(find.text('Choose sync backend'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(container.read(backendPickerViewModelProvider).saving, isTrue);

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
      expect(find.byKey(_pickerBack), findsOneWidget);
      expect(find.text('Hosted sync'), findsNothing);

      writer.gate!.complete();
      await pumpFlowFrames(tester);

      expect(find.byKey(_identifierField), findsNothing);
      expect(find.text('Choose sync backend'), findsOneWidget);
      expect(endedCalls, 0);
      final pickerState = container.read(backendPickerViewModelProvider);
      expect(pickerState.selectedBackend, SyncBackendKind.supabase);
      expect(pickerState.step, isNull);
      expect(writer.calls, hasLength(1));
    });
  });

  group('fresh re-entry while a prior operation settles', () {
    testWidgets('a fresh re-entry waits behind a loading root until the '
        'prior enroll settles', (tester) async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final metadataStore = SyncMetadataStore(db);
      final opener = FakeSessionOpener();
      final secrets = InMemorySecretStore();
      final writer = _RecordingWriter();
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
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpFreshFlow(tester, container, onEnded: () {});
      expect(find.text('Choose sync backend'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await pumpFlowFrames(tester);
      expect(find.byKey(_identifierField), findsOneWidget);

      final enrollGate = Completer<void>();
      opener.session.onEnroll = () => enrollGate.future;
      await _submitIdentifier(tester, 'user@example.com');
      expect(container.read(syncEnrollmentViewModelProvider).inFlight, isTrue);

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

      expect(
        find.text(
          'Finishing the previous attempt. This usually takes a few seconds.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Hosted sync'), findsNothing);
      expect(opener.openCalls, 1);

      enrollGate.complete();
      await pumpFlowFrames(tester);

      expect(find.text('Hosted sync'), findsOneWidget);
      expect(
        find.text(
          'Finishing the previous attempt. This usually takes a few seconds.',
        ),
        findsNothing,
      );
      expect(opener.openCalls, 1);
      expect(opener.session.publishCalls, 0);
      expect(endedCalls, 0);
    });

    testWidgets('closing the loading root ends the flow and the late reset '
        'leaves the disposed flow alone', (tester) async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final metadataStore = SyncMetadataStore(db);
      final opener = FakeSessionOpener();
      final secrets = InMemorySecretStore();
      final writer = _RecordingWriter();
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
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SyncEnrollmentFlow(onEnded: () {})),
        ),
      );
      await pumpFlowFrames(tester);
      await tester.tap(find.text('Continue'));
      await pumpFlowFrames(tester);

      final enrollGate = Completer<void>();
      opener.session.onEnroll = () => enrollGate.future;
      await _submitIdentifier(tester, 'user@example.com');

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
      expect(
        find.text(
          'Finishing the previous attempt. This usually takes a few seconds.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(_pickerBack));
      await pumpFlowFrames(tester);
      expect(endedCalls, 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Text('flow host gone')),
          ),
        ),
      );
      await pumpFlowFrames(tester);

      enrollGate.complete();
      await pumpFlowFrames(tester);

      expect(endedCalls, 1);
      expect(opener.session.publishCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a late fresh entry does not reset a repair route opened '
        'while the prior enrollment was pending', (tester) async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final metadataStore = SyncMetadataStore(db);
      await metadataStore.enterBindingAuthorizationRequired();
      final opener = FakeSessionOpener();
      final secrets = InMemorySecretStore();
      final writer = _RecordingWriter();
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
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      Future<void> pumpHostGone() => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Text('flow host gone')),
          ),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SyncEnrollmentFlow(repairMode: true)),
        ),
      );
      await pumpFlowFrames(tester);
      expect(find.text('Repair Device Access'), findsOneWidget);

      final enrollGate = Completer<void>();
      opener.session.onEnroll = () => enrollGate.future;
      await _submitIdentifier(tester, 'user@example.com');
      expect(container.read(syncEnrollmentViewModelProvider).inFlight, isTrue);

      await pumpHostGone();
      await pumpFlowFrames(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SyncEnrollmentFlow(onEnded: () {})),
        ),
      );
      await pumpFlowFrames(tester);
      expect(
        find.text(
          'Finishing the previous attempt. This usually takes a few seconds.',
        ),
        findsOneWidget,
      );

      await pumpHostGone();
      await pumpFlowFrames(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SyncEnrollmentFlow(repairMode: true)),
        ),
      );
      await pumpFlowFrames(tester);
      expect(find.text('Repair Device Access'), findsOneWidget);
      expect(
        container.read(syncEnrollmentViewModelProvider).repairPhase,
        isNotNull,
      );

      enrollGate.complete();
      await pumpFlowFrames(tester);

      final state = container.read(syncEnrollmentViewModelProvider);
      expect(state.repairMode, isTrue);
      expect(state.repairPhase, isNotNull);
      expect(state.explainCodeReplacement, isTrue);
      expect(find.text('Repair Device Access'), findsOneWidget);
      expect(find.text('Choose sync backend'), findsNothing);
      expect(opener.session.publishCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a superseded fresh entry does not reset or mount the picker', (
      tester,
    ) async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final metadataStore = SyncMetadataStore(db);
      final opener = FakeSessionOpener();
      final secrets = InMemorySecretStore();
      final writer = _RecordingWriter();
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
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      Future<void> pumpHostGone() => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Text('flow host gone')),
          ),
        ),
      );

      await _pumpFreshFlow(tester, container, onEnded: () {});
      await tester.tap(find.text('Continue'));
      await pumpFlowFrames(tester);

      final enrollGate = Completer<void>();
      opener.session.onEnroll = () => enrollGate.future;
      await _submitIdentifier(tester, 'user@example.com');
      expect(container.read(syncEnrollmentViewModelProvider).inFlight, isTrue);

      await pumpHostGone();
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
      expect(
        find.text(
          'Finishing the previous attempt. This usually takes a few seconds.',
        ),
        findsOneWidget,
      );

      container
          .read(backendPickerViewModelProvider.notifier)
          .selectBackend(SyncBackendKind.custom);
      container
          .read(backendPickerViewModelProvider.notifier)
          .updateEndpoint('https://sync.example.com/sync');

      await container
          .read(syncEnrollmentViewModelProvider.notifier)
          .enterRepairMode();
      expect(
        container.read(syncEnrollmentViewModelProvider).repairMode,
        isTrue,
      );

      enrollGate.complete();
      await pumpFlowFrames(tester);

      final pickerState = container.read(backendPickerViewModelProvider);
      expect(pickerState.selectedBackend, SyncBackendKind.custom);
      expect(pickerState.endpoint, 'https://sync.example.com/sync');
      expect(find.byType(BackendPickerScreen), findsNothing);
      expect(endedCalls, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('fresh wait timeout', () {
    const retryCopy =
        'Still finishing the previous attempt. You can keep waiting or go back.';
    const retryButton = Key('syncFreshRetryWait');

    Future<
      ({
        ProviderContainer container,
        FakeSessionOpener opener,
        Completer<void> enrollGate,
      })
    >
    pumpWaitingFreshFlow(WidgetTester tester, {VoidCallback? onEnded}) async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final metadataStore = SyncMetadataStore(db);
      final opener = FakeSessionOpener();
      final secrets = InMemorySecretStore();
      final writer = _RecordingWriter();
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
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      Future<void> pumpHostGone() => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Text('flow host gone')),
          ),
        ),
      );

      await _pumpFreshFlow(tester, container, onEnded: () {});
      await tester.tap(find.text('Continue'));
      await pumpFlowFrames(tester);

      final enrollGate = Completer<void>();
      opener.session.onEnroll = () => enrollGate.future;
      await _submitIdentifier(tester, 'user@example.com');
      expect(container.read(syncEnrollmentViewModelProvider).inFlight, isTrue);

      await pumpHostGone();
      await pumpFlowFrames(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SyncEnrollmentFlow(onEnded: onEnded)),
        ),
      );
      await pumpFlowFrames(tester);
      expect(
        find.text(
          'Finishing the previous attempt. This usually takes a few seconds.',
        ),
        findsOneWidget,
      );

      return (container: container, opener: opener, enrollGate: enrollGate);
    }

    testWidgets('a stalled wait shows the retry state without resetting', (
      tester,
    ) async {
      final waiting = await pumpWaitingFreshFlow(tester);
      final container = waiting.container;
      container
          .read(backendPickerViewModelProvider.notifier)
          .selectBackend(SyncBackendKind.custom);
      container
          .read(backendPickerViewModelProvider.notifier)
          .updateEndpoint('https://sync.example.com/sync');
      final before = container.read(syncEnrollmentViewModelProvider);

      await tester.pump(const Duration(seconds: 30));
      await pumpFlowFrames(tester);

      expect(find.text(retryCopy), findsOneWidget);
      expect(find.byKey(retryButton), findsOneWidget);
      expect(find.byType(BackendPickerScreen), findsNothing);
      final stalled = container.read(syncEnrollmentViewModelProvider);
      expect(stalled.identifier, before.identifier);
      expect(stalled.inFlight, before.inFlight);
      expect(stalled.repairMode, before.repairMode);
      final pickerState = container.read(backendPickerViewModelProvider);
      expect(pickerState.selectedBackend, SyncBackendKind.custom);
      expect(pickerState.endpoint, 'https://sync.example.com/sync');

      waiting.enrollGate.complete();
      await pumpFlowFrames(tester);

      expect(waiting.opener.session.enrollCalls, 1);
      expect(waiting.opener.session.publishCalls, 0);
      expect(find.text(retryCopy), findsOneWidget);
      expect(find.byType(BackendPickerScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('try again re-waits and mounts the picker once settled', (
      tester,
    ) async {
      final waiting = await pumpWaitingFreshFlow(tester);
      final container = waiting.container;

      await tester.pump(const Duration(seconds: 30));
      await pumpFlowFrames(tester);
      expect(find.byKey(retryButton), findsOneWidget);

      await tester.tap(find.byKey(retryButton));
      await pumpFlowFrames(tester);
      expect(
        find.text(
          'Finishing the previous attempt. This usually takes a few seconds.',
        ),
        findsOneWidget,
      );

      waiting.enrollGate.complete();
      await pumpFlowFrames(tester);

      expect(find.text('Hosted sync'), findsOneWidget);
      expect(find.text(retryCopy), findsNothing);
      expect(container.read(syncEnrollmentViewModelProvider).inFlight, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('back ends the flow from the retry state', (tester) async {
      var endedCalls = 0;
      await pumpWaitingFreshFlow(tester, onEnded: () => endedCalls++);

      await tester.pump(const Duration(seconds: 30));
      await pumpFlowFrames(tester);
      expect(find.text(retryCopy), findsOneWidget);

      await tester.tap(find.byKey(_pickerBack));
      await pumpFlowFrames(tester);
      expect(endedCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the retry wait times out again when still stalled', (
      tester,
    ) async {
      final waiting = await pumpWaitingFreshFlow(tester);
      final before = waiting.container.read(syncEnrollmentViewModelProvider);

      await tester.pump(const Duration(seconds: 30));
      await pumpFlowFrames(tester);
      expect(find.byKey(retryButton), findsOneWidget);

      await tester.tap(find.byKey(retryButton));
      await pumpFlowFrames(tester);
      expect(find.byKey(retryButton), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      await pumpFlowFrames(tester);
      expect(find.byKey(retryButton), findsOneWidget);
      expect(find.text(retryCopy), findsOneWidget);
      expect(find.byType(BackendPickerScreen), findsNothing);
      final stalled = waiting.container.read(syncEnrollmentViewModelProvider);
      expect(stalled.identifier, before.identifier);
      expect(stalled.inFlight, before.inFlight);
      expect(tester.takeException(), isNull);
    });
  });
}
