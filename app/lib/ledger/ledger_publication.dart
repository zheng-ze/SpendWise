import 'package:domain/domain.dart';
import 'package:sync/sync.dart';

/// Composite batch flowing on the [EventBus].
///
/// [changes] is the persistence and analysis payload. [stamps] carries the
/// optional per-row sync version vectors supplied by the sync engine; it is
/// null for ordinary local mutations, which keep the existing store bump
/// path.
///
/// Immutability is provided by the publisher: [EventBus.publish] wraps both
/// collections in unmodifiable views under its existing debug-only assertion
/// discipline.
final class LedgerPublication {
  const LedgerPublication({required this.changes, this.stamps});

  final List<LedgerChange> changes;

  final Map<SyncRowID, VersionVector>? stamps;

  /// Whether this publication carries stamps for the persistence layer.
  /// An empty map counts as unstamped, so the processor keeps the old bump
  /// path for it.
  bool get hasStamps => stamps != null && stamps!.isNotEmpty;
}
