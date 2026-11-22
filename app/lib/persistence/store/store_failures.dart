part of 'drift_ledger_store.dart';

// MARK: - Errors

final class PersistenceBarrierFailure implements Exception {
  const PersistenceBarrierFailure(this.message, {this.cause, this.stackTrace});

  final String message;

  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() => 'PersistenceBarrierFailure: $message';
}
