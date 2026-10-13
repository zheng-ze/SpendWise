part of '../sync_metadata_store.dart';

// MARK: - Store Exceptions

final class SyncWriteGateException implements Exception {
  const SyncWriteGateException(this.message);

  final String message;

  @override
  String toString() => 'SyncWriteGateException: $message';
}

final class SyncRepairTransitionException implements Exception {
  const SyncRepairTransitionException(this.message);

  final String message;

  @override
  String toString() => 'SyncRepairTransitionException: $message';
}
