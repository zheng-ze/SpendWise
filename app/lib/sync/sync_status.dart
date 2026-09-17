import 'package:flutter/foundation.dart';

/// Lifecycle status of sync coordination.
///
/// The create slice ships exactly one variant, [SyncIdle]. Run, scheduling,
/// and progress states belong to a later slice, which will add variants here.
@immutable
sealed class SyncStatus {
  const SyncStatus();
}

/// Assembled but idle: no sync run is in progress.
///
/// The coordinator reports this from a field nothing in the create slice
/// mutates, so it holds immediately after [SyncCoordinator.create] and stays
/// until a later slice introduces transitions.
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
