import 'package:flutter/foundation.dart';

/// Lifecycle status of sync coordination.
///
/// Ships exactly two variants: [SyncIdle] when no sync run is in progress and
/// [SyncRunning] while a pass is active. Future slices may add further
/// variants (conflict review, blocked) to this still-sealed hierarchy.
@immutable
sealed class SyncStatus {
  const SyncStatus();
}

/// Assembled but idle: no sync run is in progress.
///
/// Holds immediately after [SyncCoordinator.create] and whenever no pass is
/// active or queued; a trigger moves it to [SyncRunning] until the run
/// (including any chained trailing pass) settles.
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

/// A sync pass is active: at least one run is in flight or queued.
///
/// Reported while the coordinator's scheduler holds an active pass, including
/// across a chained trailing pass with no intermediate idle. Returns to
/// [SyncIdle] only once nothing is pending.
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
