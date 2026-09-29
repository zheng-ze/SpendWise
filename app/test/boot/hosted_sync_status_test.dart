import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

import '../support/recording_ledger_store.dart';

SyncMetadataSnapshot _snapshot({
  required SyncBackendKind? backend,
  required SyncDeviceBindingState binding,
  required SyncEnrollmentPhase phase,
  required bool writes,
  SyncEnrollmentPhase? resume,
}) => SyncMetadataSnapshot(
  backend: backend,
  endpoint: null,
  phase: phase,
  writeEnabled: writes,
  deviceBindingState: binding,
  reauthResumePhase: resume,
  watermarks: const {},
);

const _bindingRepairSnapshot = SyncMetadataSnapshot(
  backend: SyncBackendKind.supabase,
  endpoint: null,
  phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
  writeEnabled: false,
  deviceBindingState: SyncDeviceBindingState.authorizationRequired,
  reauthResumePhase: null,
  watermarks: {},
);

const _readySnapshot = SyncMetadataSnapshot(
  backend: SyncBackendKind.supabase,
  endpoint: null,
  phase: SyncEnrollmentPhase.gateEnabled,
  writeEnabled: true,
  deviceBindingState: SyncDeviceBindingState.bound,
  reauthResumePhase: null,
  watermarks: {},
);

AppBoot _bootWith({
  required Future<SyncMetadataSnapshot> Function() readSyncSnapshot,
}) => AppBoot(
  createStore: () async => RecordingLedgerStore(hasSeeded: true),
  seedChanges: () => const [],
  readSyncSnapshot: readSyncSnapshot,
);

Future<void> _waitForReady(AppBoot boot) async {
  while (boot.phase is! Ready) {
    final phase = boot.phase;
    if (phase is Failed) throw StateError('boot failed: ${phase.error}');
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _containerWithMemoryConnection() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      databaseConnectionProvider.overrideWith((ref) async {
        return NativeDatabase.memory();
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('projection', () {
    test('customBackendProjectsToUnsupportedV2AheadOfRepairPhase', () {
      final status = projectHostedSyncStatus(
        _snapshot(
          backend: SyncBackendKind.custom,
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
          writes: false,
        ),
      );

      expect(status, const HostedSyncUnsupportedV2());
    });

    test('absentBackendProjectsToNoSelection', () {
      final status = projectHostedSyncStatus(
        _snapshot(
          backend: null,
          binding: SyncDeviceBindingState.notApplicable,
          phase: SyncEnrollmentPhase.notEnrolled,
          writes: false,
        ),
      );

      expect(status, const HostedSyncNoSelection());
    });

    test('legalBindingTupleProjectsToBindingRepair', () {
      expect(
        projectHostedSyncStatus(_bindingRepairSnapshot),
        const HostedSyncBindingRepair(),
      );
    });

    test('legalReauthTuplesProjectToSessionReauth', () {
      for (final resume in [
        SyncEnrollmentPhase.snapshotInProgress,
        SyncEnrollmentPhase.reconciliationComplete,
        SyncEnrollmentPhase.gateEnabled,
      ]) {
        expect(
          projectHostedSyncStatus(
            _snapshot(
              backend: SyncBackendKind.supabase,
              binding: SyncDeviceBindingState.bound,
              phase: SyncEnrollmentPhase.sessionReauthRequired,
              writes: false,
              resume: resume,
            ),
          ),
          const HostedSyncSessionReauth(),
          reason: 'resume=${resume.name}',
        );
      }
    });

    test('boundGateEnabledProjectsToReady', () {
      expect(projectHostedSyncStatus(_readySnapshot), const HostedSyncReady());
    });

    test('otherLegalTuplesProjectToSetupPending', () {
      final pending = [
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.notApplicable,
          phase: SyncEnrollmentPhase.notEnrolled,
          writes: false,
        ),
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.credentialAcquired,
          writes: false,
        ),
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.snapshotInProgress,
          writes: false,
        ),
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.reconciliationComplete,
          writes: false,
        ),
      ];

      for (final snapshot in pending) {
        expect(
          projectHostedSyncStatus(snapshot),
          const HostedSyncSetupPending(),
          reason:
              'binding=${snapshot.deviceBindingState.name} '
              'phase=${snapshot.phase.name}',
        );
      }
    });

    test('illegalHostedTuplesProjectToUnavailable', () {
      final illegal = [
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
          writes: false,
        ),
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.notApplicable,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
        ),
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: true,
          resume: SyncEnrollmentPhase.gateEnabled,
        ),
        _snapshot(
          backend: SyncBackendKind.supabase,
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
          writes: true,
        ),
      ];

      for (final snapshot in illegal) {
        expect(
          projectHostedSyncStatus(snapshot),
          const HostedSyncUnavailable(),
          reason:
              'binding=${snapshot.deviceBindingState.name} '
              'phase=${snapshot.phase.name} writes=${snapshot.writeEnabled} '
              'resume=${snapshot.reauthResumePhase?.name}',
        );
      }
    });

    test('unavailableAgreesWithHostedLegalityOnEveryTuple', () async {
      final database = LedgerDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncMetadataStore(database);

      const resumes = [
        null,
        SyncEnrollmentPhase.snapshotInProgress,
        SyncEnrollmentPhase.reconciliationComplete,
        SyncEnrollmentPhase.gateEnabled,
        SyncEnrollmentPhase.notEnrolled,
      ];
      for (final binding in SyncDeviceBindingState.values) {
        for (final phase in SyncEnrollmentPhase.values) {
          for (final writes in [false, true]) {
            for (final resume in resumes) {
              final snapshot = _snapshot(
                backend: SyncBackendKind.supabase,
                binding: binding,
                phase: phase,
                writes: writes,
                resume: resume,
              );
              final legal = store
                  .validateHostedOperationState(snapshot)
                  .isLegal;
              expect(
                projectHostedSyncStatus(snapshot) ==
                    const HostedSyncUnavailable(),
                !legal,
                reason:
                    'binding=${binding.name} phase=${phase.name} '
                    'writes=$writes resume=${resume?.name}',
              );
            }
          }
        }
      }
    });
  });

  group('app boot', () {
    test('seededRepairPhaseSurfacesAfterStart', () async {
      final boot = _bootWith(
        readSyncSnapshot: () async {
          return _bindingRepairSnapshot;
        },
      );

      await boot.start();

      expect(boot.phase, isA<Ready>());
      expect(boot.syncStatus, const HostedSyncBindingRepair());
    });

    test('readFailureSurfacesUnavailableWhileLedgerStaysReady', () async {
      final boot = _bootWith(
        readSyncSnapshot: () async {
          throw StateError('metadata unreadable');
        },
      );

      await boot.start();

      expect(boot.phase, isA<Ready>());
      expect(boot.syncStatus, const HostedSyncUnavailable());
    });

    test('unknownPhaseCodeSurfacesUnavailableWhileLedgerStaysReady', () async {
      final boot = _bootWith(
        readSyncSnapshot: () async {
          throw const FormatException(
            'Unknown sync enrollment phase code: 99.',
          );
        },
      );

      await boot.start();

      expect(boot.phase, isA<Ready>());
      expect(boot.syncStatus, const HostedSyncUnavailable());
    });

    test('restartClearsThePreviousStatus', () async {
      var current = _bindingRepairSnapshot;
      final boot = _bootWith(readSyncSnapshot: () async => current);

      await boot.start();
      expect(boot.syncStatus, const HostedSyncBindingRepair());

      current = _readySnapshot;
      await boot.start();

      expect(boot.phase, isA<Ready>());
      expect(boot.syncStatus, const HostedSyncReady());
    });

    test('refreshFailureSurfacesUnavailableWhileLedgerStaysReady', () async {
      var current = _readySnapshot;
      final boot = _bootWith(readSyncSnapshot: () async => current);
      await boot.start();
      expect(boot.syncStatus, const HostedSyncReady());

      current = _bindingRepairSnapshot;
      await boot.refreshSyncStatus();
      expect(boot.syncStatus, const HostedSyncBindingRepair());

      final bootAgain = _bootWith(
        readSyncSnapshot: () async {
          throw StateError('metadata unreadable');
        },
      );
      await bootAgain.start();
      await bootAgain.refreshSyncStatus();

      expect(bootAgain.phase, isA<Ready>());
      expect(bootAgain.syncStatus, const HostedSyncUnavailable());
    });

    test('staleRefreshCannotOverwriteNewerBootStatus', () async {
      var current = _bindingRepairSnapshot;
      final gate = Completer<SyncMetadataSnapshot>();
      var blockNextRead = false;
      final boot = AppBoot(
        createStore: () async => RecordingLedgerStore(hasSeeded: true),
        seedChanges: () => const [],
        readSyncSnapshot: () async {
          if (blockNextRead) {
            blockNextRead = false;
            return gate.future;
          }
          return current;
        },
      );
      await boot.start();
      expect(boot.syncStatus, const HostedSyncBindingRepair());

      blockNextRead = true;
      final staleRefresh = boot.refreshSyncStatus();
      current = _readySnapshot;
      await boot.start();
      expect(boot.syncStatus, const HostedSyncReady());

      gate.complete(_bindingRepairSnapshot);
      await staleRefresh;

      expect(boot.syncStatus, const HostedSyncReady());
    });

    test('bootWithoutAReaderStaysUnavailable', () async {
      final boot = AppBoot(
        createStore: () async => RecordingLedgerStore(hasSeeded: true),
        seedChanges: () => const [],
      );

      await boot.start();

      expect(boot.phase, isA<Ready>());
      expect(boot.syncStatus, const HostedSyncUnavailable());
    });
  });

  group('provider restart with persisted metadata', () {
    test('seededRepairPhaseSurfacesAfterRestart', () async {
      final container = _containerWithMemoryConnection();
      final metadata = container.read(syncMetadataStoreProvider);
      await metadata.setBackendSelection(
        backend: SyncBackendKind.supabase,
        endpoint: null,
      );
      await metadata.enterBindingAuthorizationRequired();

      final boot = container.read(appBootProvider);
      await _waitForReady(boot);

      expect(boot.phase, isA<Ready>());
      expect(
        container.read(hostedSyncStatusProvider),
        const HostedSyncBindingRepair(),
      );
    });

    test('seededSessionReauthSurfacesAfterRestart', () async {
      final container = _containerWithMemoryConnection();
      final metadata = container.read(syncMetadataStoreProvider);
      await metadata.setBackendSelection(
        backend: SyncBackendKind.supabase,
        endpoint: null,
      );
      await metadata.enterSnapshotInProgress();
      await metadata.enterSessionReauthRequired();

      final boot = container.read(appBootProvider);
      await _waitForReady(boot);

      expect(
        container.read(hostedSyncStatusProvider),
        const HostedSyncSessionReauth(),
      );
    });

    test('customSelectionTakesPrecedenceOverARepairPhase', () async {
      final container = _containerWithMemoryConnection();
      final metadata = container.read(syncMetadataStoreProvider);
      await metadata.setBackendSelection(
        backend: SyncBackendKind.custom,
        endpoint: 'https://sync.example.com',
      );
      await metadata.enterBindingAuthorizationRequired();

      final boot = container.read(appBootProvider);
      await _waitForReady(boot);

      expect(boot.phase, isA<Ready>());
      expect(
        container.read(hostedSyncStatusProvider),
        const HostedSyncUnsupportedV2(),
      );
    });

    test('unknownPhaseCodeSurfacesUnavailableWhileLedgerStaysReady', () async {
      final container = _containerWithMemoryConnection();
      await container.read(syncMetadataStoreProvider).snapshot();
      final database = container.read(ledgerDatabaseProvider);
      await (database.update(database.syncMeta)..where((t) => t.id.equals(0)))
          .write(const SyncMetaCompanion(enrollmentPhase: Value(99)));

      final boot = container.read(appBootProvider);
      await _waitForReady(boot);

      expect(boot.phase, isA<Ready>());
      expect(
        container.read(hostedSyncStatusProvider),
        const HostedSyncUnavailable(),
      );
    });

    test('absentMetaRowInitializesToNoSelection', () async {
      final container = _containerWithMemoryConnection();

      final boot = container.read(appBootProvider);
      await _waitForReady(boot);

      expect(boot.phase, isA<Ready>());
      expect(
        container.read(hostedSyncStatusProvider),
        const HostedSyncNoSelection(),
      );
    });

    test('refreshPicksUpRepairedMetadata', () async {
      final container = _containerWithMemoryConnection();
      final metadata = container.read(syncMetadataStoreProvider);
      await metadata.setBackendSelection(
        backend: SyncBackendKind.supabase,
        endpoint: null,
      );
      await metadata.enterBindingAuthorizationRequired();

      final boot = container.read(appBootProvider);
      await _waitForReady(boot);
      expect(
        container.read(hostedSyncStatusProvider),
        const HostedSyncBindingRepair(),
      );

      final database = container.read(ledgerDatabaseProvider);
      await (database.update(
        database.syncMeta,
      )..where((t) => t.id.equals(0))).write(
        SyncMetaCompanion(
          deviceBindingState: Value(SyncDeviceBindingState.bound.code),
          enrollmentPhase: Value(SyncEnrollmentPhase.gateEnabled.code),
          writeEnabled: const Value(true),
          reauthResumePhase: const Value<int?>(null),
        ),
      );

      await boot.refreshSyncStatus();

      expect(boot.phase, isA<Ready>());
      expect(container.read(hostedSyncStatusProvider), const HostedSyncReady());
    });
  });
}
