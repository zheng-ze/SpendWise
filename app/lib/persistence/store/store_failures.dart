part of 'drift_ledger_store.dart';

// MARK: - Errors

class PermanentSaveError implements Exception {
  const PermanentSaveError(this.reason);

  final String reason;

  @override
  String toString() => 'PermanentSaveError($reason)';
}

final class PersistenceBarrierFailure implements Exception {
  const PersistenceBarrierFailure(this.message, {this.cause, this.stackTrace});

  final String message;

  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() => 'PersistenceBarrierFailure: $message';
}
