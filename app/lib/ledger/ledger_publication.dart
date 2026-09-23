import 'package:domain/domain.dart';
import 'package:sync/sync.dart';

final class LedgerPublication {
  const LedgerPublication({required this.changes, this.stamps});

  final List<LedgerChange> changes;

  final Map<SyncRowID, VersionVector>? stamps;

  bool get hasStamps => stamps != null && stamps!.isNotEmpty;
}
