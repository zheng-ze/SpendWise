import 'package:drift/native.dart';
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
        gate.admit(
          _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.snapshotInProgress,
            writes: false,
          ),
        ),
        isNotNull,
      );
      final BoundRpcLease? lease = gate.admit(
        _snapshot(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
      );
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
        gate.admit(
          _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.sessionReauthRequired,
            writes: false,
            resume: SyncEnrollmentPhase.gateEnabled,
          ),
        ),
        isNull,
      );
      expect(gate.isOpen, isFalse);
      expect(
        gate.admit(
          _snapshot(
            binding: SyncDeviceBindingState.authorizationRequired,
            phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
            writes: false,
          ),
        ),
        isNull,
      );
    });

    test('a non-bound snapshot refuses admission', () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final gate = SyncRepairGate.forDatabase(db);

      expect(
        gate.admit(
          _snapshot(
            binding: SyncDeviceBindingState.notApplicable,
            phase: SyncEnrollmentPhase.notEnrolled,
            writes: false,
          ),
        ),
        isNull,
      );
    });

    test(
      'reseed closes on repair-durable state and opens on bound state',
      () async {
        final db = LedgerDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final gate = SyncRepairGate.forDatabase(db);

        gate.reseed(
          _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.sessionReauthRequired,
            writes: false,
            resume: SyncEnrollmentPhase.gateEnabled,
          ),
        );
        expect(gate.isOpen, isFalse);

        gate.reseed(
          _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.gateEnabled,
            writes: true,
          ),
        );
        expect(gate.isOpen, isTrue);
      },
    );

    test(
      'a latched gate refuses even a bound snapshot until release',
      () async {
        final db = LedgerDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final gate = SyncRepairGate.forDatabase(db);
        final BoundRpcLease? before = gate.admit(
          _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.gateEnabled,
            writes: true,
          ),
        );
        if (before == null) {
          fail('Expected admission before the latch.');
        }

        gate.latch();
        expect(gate.isOpen, isFalse);
        expect(gate.isCurrent(before), isFalse);
        expect(
          gate.admit(
            _snapshot(
              binding: SyncDeviceBindingState.bound,
              phase: SyncEnrollmentPhase.snapshotInProgress,
              writes: false,
            ),
          ),
          isNull,
        );
        expect(gate.isOpen, isFalse);

        gate.release();
        expect(gate.isOpen, isTrue);
        final BoundRpcLease? after = gate.admit(
          _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.snapshotInProgress,
            writes: false,
          ),
        );
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
      final BoundRpcLease? lease = gate.admit(
        _snapshot(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
      );
      if (lease == null) {
        fail('Expected admission.');
      }

      gate.release();

      expect(gate.isOpen, isTrue);
      expect(gate.isCurrent(lease), isTrue);
    });

    test(
      'observing repair-durable state while open latches and retires',
      () async {
        final db = LedgerDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final gate = SyncRepairGate.forDatabase(db);
        final BoundRpcLease? lease = gate.admit(
          _snapshot(
            binding: SyncDeviceBindingState.bound,
            phase: SyncEnrollmentPhase.gateEnabled,
            writes: true,
          ),
        );
        if (lease == null) {
          fail('Expected admission.');
        }

        expect(
          gate.admit(
            _snapshot(
              binding: SyncDeviceBindingState.bound,
              phase: SyncEnrollmentPhase.sessionReauthRequired,
              writes: false,
              resume: SyncEnrollmentPhase.gateEnabled,
            ),
          ),
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
}
