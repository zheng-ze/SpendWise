part of '../sync_metadata_store.dart';

// MARK: - Phase Transitions

extension SyncMetadataStoreTransitions on SyncMetadataStore {
  Future<void> enterBindingAuthorizationRequired() => _db.transaction(() async {
    await _ensureMetaRow();
    // Binding repair unconditionally overrides a prior session reauth, so the
    // stale resume target is cleared here rather than preserved.
    await _writeMeta(
      SyncMetaCompanion(
        deviceBindingState: Value(
          SyncDeviceBindingState.authorizationRequired.code,
        ),
        enrollmentPhase: Value(
          SyncEnrollmentPhase.bindingAuthorizationRequired.code,
        ),
        writeEnabled: const Value(false),
        reauthResumePhase: const Value<int?>(null),
      ),
    );
  });

  Future<void> enterSnapshotInProgress() => _db.transaction(() async {
    await _ensureMetaRow();
    await _writeMeta(
      SyncMetaCompanion(
        deviceBindingState: Value(SyncDeviceBindingState.bound.code),
        enrollmentPhase: Value(SyncEnrollmentPhase.snapshotInProgress.code),
        writeEnabled: const Value(false),
        reauthResumePhase: const Value<int?>(null),
      ),
    );
  });

  Future<void> enterReconciliationComplete() => _db.transaction(() async {
    await _ensureMetaRow();
    await _writeMeta(
      SyncMetaCompanion(
        deviceBindingState: Value(SyncDeviceBindingState.bound.code),
        enrollmentPhase: Value(SyncEnrollmentPhase.reconciliationComplete.code),
        writeEnabled: const Value(false),
        reauthResumePhase: const Value<int?>(null),
      ),
    );
  });

  Future<void> enterGateEnabled() => _db.transaction(() async {
    await _ensureMetaRow();
    final meta = await _metaRow();
    final binding = SyncDeviceBindingState.fromCode(meta.deviceBindingState);
    final phase = SyncEnrollmentPhase.fromCode(meta.enrollmentPhase);
    final resume = switch (meta.reauthResumePhase) {
      null => null,
      final code => SyncEnrollmentPhase.fromCode(code),
    };
    if (binding != SyncDeviceBindingState.bound ||
        phase != SyncEnrollmentPhase.reconciliationComplete ||
        meta.writeEnabled ||
        resume != null) {
      throw SyncWriteGateException(
        'Cannot enter ${SyncEnrollmentPhase.gateEnabled.name} from '
        'binding=${binding.name}, phase=${phase.name}, '
        'writes=${meta.writeEnabled}, resume=${resume?.name}; '
        'reconciliation must complete first.',
      );
    }
    await _writeMeta(
      SyncMetaCompanion(
        deviceBindingState: Value(SyncDeviceBindingState.bound.code),
        enrollmentPhase: Value(SyncEnrollmentPhase.gateEnabled.code),
        writeEnabled: const Value(true),
        reauthResumePhase: const Value<int?>(null),
      ),
    );
  });

  // MARK: - Session Reauth

  Future<SessionReauthEntry> enterSessionReauthRequired() => _db.transaction(
    () async {
      final meta = await _metaRow();
      final phase = SyncEnrollmentPhase.fromCode(meta.enrollmentPhase);
      final binding = SyncDeviceBindingState.fromCode(meta.deviceBindingState);
      final resume = switch (meta.reauthResumePhase) {
        null => null,
        final code => SyncEnrollmentPhase.fromCode(code),
      };
      if (phase == SyncEnrollmentPhase.sessionReauthRequired) {
        final isLegalReauth =
            binding == SyncDeviceBindingState.bound &&
            !meta.writeEnabled &&
            (resume == SyncEnrollmentPhase.snapshotInProgress ||
                resume == SyncEnrollmentPhase.reconciliationComplete ||
                resume == SyncEnrollmentPhase.gateEnabled);
        return isLegalReauth
            ? SessionReauthEntry.alreadyInProgress
            : SessionReauthEntry.rejectedIllegalState;
      }
      // One transaction: a concurrent second caller observes the already
      // written sessionReauthRequired above and no-ops instead of clobbering
      // the recorded resume phase. Binding repair always wins over a
      // session-reauth attempt, never the reverse.
      switch ((binding, phase)) {
        case (
          SyncDeviceBindingState.bound,
          SyncEnrollmentPhase.snapshotInProgress,
        ):
        case (
          SyncDeviceBindingState.bound,
          SyncEnrollmentPhase.reconciliationComplete,
        ):
          // These phases are only legal with writes disabled and no
          // pending resume target; anything else is an illegal row.
          if (meta.writeEnabled || resume != null) {
            return SessionReauthEntry.rejectedIllegalState;
          }
        case (SyncDeviceBindingState.bound, SyncEnrollmentPhase.gateEnabled):
          // gateEnabled is only legal with writes enabled and no pending
          // resume target; anything else is an illegal row.
          if (!meta.writeEnabled || resume != null) {
            return SessionReauthEntry.rejectedIllegalState;
          }
        default:
          return SessionReauthEntry.rejectedIllegalState;
      }
      await _writeMeta(
        SyncMetaCompanion(
          enrollmentPhase: Value(
            SyncEnrollmentPhase.sessionReauthRequired.code,
          ),
          writeEnabled: const Value(false),
          reauthResumePhase: Value(phase.code),
        ),
      );
      return SessionReauthEntry.applied;
    },
  );

  Future<SyncEnrollmentPhase> restoreFromSessionReauth() => _db.transaction(
    () async {
      final meta = await _metaRow();
      final binding = SyncDeviceBindingState.fromCode(meta.deviceBindingState);
      final phase = SyncEnrollmentPhase.fromCode(meta.enrollmentPhase);
      final resume = switch (meta.reauthResumePhase) {
        null => null,
        final code => SyncEnrollmentPhase.fromCode(code),
      };
      final canRestore =
          binding == SyncDeviceBindingState.bound &&
          phase == SyncEnrollmentPhase.sessionReauthRequired &&
          !meta.writeEnabled &&
          (resume == SyncEnrollmentPhase.snapshotInProgress ||
              resume == SyncEnrollmentPhase.reconciliationComplete ||
              resume == SyncEnrollmentPhase.gateEnabled);
      if (!canRestore || resume == null) {
        throw SyncRepairTransitionException(
          'Cannot restore from session reauth: binding=${binding.name}, '
          'phase=${phase.name}, resume=${resume?.name}.',
        );
      }
      // Rows seeded outside enterSessionReauthRequired may carry an illegal
      // writes-enabled sessionReauthRequired tuple, so writes must be checked
      // here rather than trusted from entry.
      await _writeMeta(
        SyncMetaCompanion(
          enrollmentPhase: Value(resume.code),
          writeEnabled: Value(resume == SyncEnrollmentPhase.gateEnabled),
          reauthResumePhase: const Value<int?>(null),
        ),
      );
      return resume;
    },
  );
}
