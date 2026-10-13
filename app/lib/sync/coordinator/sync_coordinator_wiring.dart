part of '../sync_coordinator.dart';

// MARK: - Wiring Exception

final class SyncCoordinatorWiringException implements Exception {
  const SyncCoordinatorWiringException();

  @override
  String toString() =>
      'SyncCoordinatorWiringException: the ledger and the persistence '
      'processor must share one event bus; their bus instances differ.';
}

// MARK: - Pass Failure Handler

typedef PassFailureHandler = void Function(Object error);
