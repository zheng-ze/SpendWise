part of '../sync_coordinator.dart';

// MARK: - Push Collection Results

sealed class PushCollectionResult {
  const PushCollectionResult();
}

final class PushNoop extends PushCollectionResult {
  const PushNoop();
}

final class PushDeferred extends PushCollectionResult {
  const PushDeferred();
}

final class PushFullyAcknowledged extends PushCollectionResult {
  PushFullyAcknowledged(Set<SyncRowID> acknowledged)
    : acknowledged = Set.unmodifiable(acknowledged);

  final Set<SyncRowID> acknowledged;
}

final class PushUnresolvedRows extends PushCollectionResult {
  PushUnresolvedRows(Set<SyncRowID> unresolved)
    : unresolved = Set.unmodifiable(unresolved);

  final Set<SyncRowID> unresolved;
}
