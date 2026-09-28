import 'package:drift/native.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_repair_gate.dart';
import 'package:sync/sync.dart';

SyncMetadataSnapshot _snapshot({
  required SyncDeviceBindingState binding,
  required SyncEnrollmentPhase phase,
  required bool writes,
  SyncEnrollmentPhase? resume,
}) => SyncMetadataSnapshot(
  backend: SyncBackendKind.supabase,
  endpoint: null,
  phase: phase,
  writeEnabled: writes,
  deviceBindingState: binding,
  reauthResumePhase: resume,
  watermarks: {
    for (final collection in SyncCollection.values) collection: null,
  },
);

void main() {
  group('SyncRepairGate registry', () {
    test('one gate per database, shared across lookups', () async {
      final first = LedgerDatabase(NativeDatabase.memory());
      final second = LedgerDatabase(NativeDatabase.memory());
      addTearDown(first.close);
      addTearDown(second.close);

      expect(
        identical(
          SyncRepairGate.forDatabase(first),
          SyncRepairGate.forDatabase(first),
        ),
        isTrue,
      );
      expect(
        identical(
          SyncRepairGate.forDatabase(first),
          SyncRepairGate.forDatabase(second),
        ),
        isFalse,
      );
    });
  });

  group('SyncRepairGate admission', () {
    test('a fresh gate admits bound phases with writes as enrolled', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);

      expect(gate.isOpen, isTrue);
      expect(
        (await gate.admit(
          () async => _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.snapshotInProgress,
            writes: false,
          ),
        )).lease,
        isNotNull,
      );
      final BoundRpcLease? lease = (await gate.admit(
        () async => _snapshot(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
      )).lease;
      if (lease == null) {
        fail('Expected admission for bound/gateEnabled.');
      }
      expect(gate.isCurrent(lease), isTrue);
    });

    test('a legal repair snapshot refuses and latches the gate', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);

      expect(
        (await gate.admit(
          () async => _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.sessionReauthRequired,
            writes: false,
            resume: SyncEnrollmentPhase.gateEnabled,
          ),
        )).lease,
        isNull,
      );
      expect(gate.isOpen, isFalse);
      expect(
        (await gate.admit(
          () async => _snapshot(
            binding: SyncDeviceBindingState.authorizationRequired,
            phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
            writes: false,
          ),
        )).lease,
        isNull,
      );
    });

    test('a non-bound snapshot refuses admission', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);

      expect(
        (await gate.admit(
          () async => _snapshot(
            binding: SyncDeviceBindingState.notApplicable,
            phase: SyncEnrollmentPhase.notEnrolled,
            writes: false,
          ),
        )).lease,
        isNull,
      );
    });

    test('reseed applies only once for the shared gate', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);

      await gate.reseed(
        _snapshot(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
          resume: SyncEnrollmentPhase.gateEnabled,
        ),
      );
      expect(gate.isOpen, isFalse);

      await gate.reseed(
        _snapshot(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
      );
      expect(gate.isOpen, isFalse);
    });

    test(
      'a latched gate refuses even a bound snapshot until release',
      () async {
        final db = LedgerDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final gate = SyncRepairGate.forDatabase(db);
        final BoundRpcLease? before = (await gate.admit(
          () async => _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.gateEnabled,
            writes: true,
          ),
        )).lease;
        if (before == null) {
          fail('Expected admission before the latch.');
        }

        await gate.latch();
        expect(gate.isOpen, isFalse);
        expect(gate.isCurrent(before), isFalse);
        expect(
          (await gate.admit(
            () async => _snapshot(
              binding: SyncDeviceBindingState.bound,
              phase: SyncEnrollmentPhase.snapshotInProgress,
              writes: false,
            ),
          )).lease,
          isNull,
        );
        expect(gate.isOpen, isFalse);

        await gate.release(await gate.repairEpisode());
        expect(gate.isOpen, isTrue);
        final BoundRpcLease? after = (await gate.admit(
          () async => _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.snapshotInProgress,
            writes: false,
          ),
        )).lease;
        if (after == null) {
          fail('Expected admission after release.');
        }
        expect(gate.isCurrent(after), isTrue);
        expect(gate.isCurrent(before), isFalse);
      },
    );

    test('release while open retires nothing', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);
      final BoundRpcLease? lease = (await gate.admit(
        () async => _snapshot(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
      )).lease;
      if (lease == null) {
        fail('Expected admission.');
      }

      await gate.release(await gate.repairEpisode());

      expect(gate.isOpen, isTrue);
      expect(gate.isCurrent(lease), isTrue);
    });

    test(
      'observing repair-durable state while open latches and retires',
      () async {
        final db = LedgerDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final gate = SyncRepairGate.forDatabase(db);
        final BoundRpcLease? lease = (await gate.admit(
          () async => _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.gateEnabled,
            writes: true,
          ),
        )).lease;
        if (lease == null) {
          fail('Expected admission.');
        }

        expect(
          (await gate.admit(
            () async => _snapshot(
              binding: SyncDeviceBindingState.bound,
              phase: SyncEnrollmentPhase.sessionReauthRequired,
              writes: false,
              resume: SyncEnrollmentPhase.gateEnabled,
            ),
          )).lease,
          isNull,
        );

        expect(gate.isOpen, isFalse);
        expect(gate.isCurrent(lease), isFalse);
      },
    );
  });

  group('SyncRepairGate secret mutation lock', () {
    test('concurrent mutations run one at a time in arrival order', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);
      final events = <String>[];

      Future<void> mutate(String name) => gate.withSecretMutationLock(() async {
        events.add('start:$name');
        await Future<void>.delayed(Duration.zero);
        events.add('end:$name');
      });

      await Future.wait([mutate('a'), mutate('b')]);

      expect(events, ['start:a', 'end:a', 'start:b', 'end:b']);
    });
  });

  group('SyncRepairGate repair races', () {
    test('admission reads the current snapshot after a repair exit', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);
      final stale = _snapshot(
        binding: SyncDeviceBindingState.bound,
        phase: SyncEnrollmentPhase.sessionReauthRequired,
        writes: false,
      );
      var current = stale;
      final episode = await gate.latch();
      final releaseQueue = Completer<void>();
      final enteredQueue = Completer<void>();
      final held = gate.withSecretMutationLock(() async {
        enteredQueue.complete();
        await releaseQueue.future;
      });
      await enteredQueue.future;
      final release = gate.release(episode);
      current = _snapshot(
        binding: SyncDeviceBindingState.bound,
        phase: SyncEnrollmentPhase.gateEnabled,
        writes: true,
      );
      final pendingAdmission = gate.admit(() async => current);
      releaseQueue.complete();
      await held;
      await release;
      final admission = await pendingAdmission;
      expect(stale.phase, SyncEnrollmentPhase.sessionReauthRequired);
      expect(admission.snapshot.phase, SyncEnrollmentPhase.gateEnabled);
      expect(admission.lease, isNotNull);
      expect(gate.isOpen, isTrue);
    });

    test('an earlier repair cannot release a sibling latch', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);
      final earlier = await gate.latch();
      final releaseQueue = Completer<void>();
      final enteredQueue = Completer<void>();
      final held = gate.withSecretMutationLock(() async {
        enteredQueue.complete();
        await releaseQueue.future;
      });
      await enteredQueue.future;
      final siblingLatch = gate.latch();
      final earlierRelease = gate.release(earlier);
      releaseQueue.complete();
      await held;
      final later = await siblingLatch;
      await earlierRelease;
      expect(gate.isOpen, isFalse);
      await gate.release(later);
      expect(gate.isOpen, isTrue);
    });

    test('a second reseed preserves a latch and retires old leases', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);
      final bound = _snapshot(
        binding: SyncDeviceBindingState.bound,
        phase: SyncEnrollmentPhase.gateEnabled,
        writes: true,
      );
      await gate.reseed(bound);
      final lease = (await gate.admit(() async => bound)).lease!;
      await gate.latch();
      await gate.reseed(bound);

      expect(gate.isOpen, isFalse);
      expect(gate.isCurrent(lease), isFalse);
    });

    test('a queued latch retires a lease before its durable write', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);
      final lease = (await gate.admit(
        () async => _snapshot(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
      )).lease!;
      final releaseQueue = Completer<void>();
      final enteredQueue = Completer<void>();
      final held = gate.withSecretMutationLock(() async {
        enteredQueue.complete();
        await releaseQueue.future;
      });
      await enteredQueue.future;
      final latch = gate.latch();
      var wrote = false;
      final write = gate.withCurrentLease(lease, () async {
        wrote = true;
      });
      releaseQueue.complete();
      await held;
      await latch;
      await expectLater(write, throwsStateError);
      expect(wrote, isFalse);
    });
  });
}
