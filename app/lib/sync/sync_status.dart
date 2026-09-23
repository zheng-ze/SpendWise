import 'package:flutter/foundation.dart';

@immutable
sealed class SyncStatus {
  const SyncStatus();
}

@immutable
final class SyncIdle extends SyncStatus {
  const SyncIdle();

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncIdle;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SyncIdle()';
}

@immutable
final class SyncRunning extends SyncStatus {
  const SyncRunning();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SyncRunning;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SyncRunning()';
}
