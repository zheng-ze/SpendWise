import 'package:sync/sync.dart';

/// Classification of one stamped row's post-flush database readback, per the
/// verification rule: an exact match or a strictly dominating stored vector
/// passes; a missing row or an incomparable stored vector fails.
sealed class RowReadbackOutcome {
  const RowReadbackOutcome();

  /// `false` is a persistent actionable verification failure.
  bool get passed;
}

final class RowReadbackEqual extends RowReadbackOutcome {
  const RowReadbackEqual();

  @override
  bool get passed => true;
}

/// The submitted stamp is still acknowledged; the dominating stored row
/// stays eligible for push.
final class RowReadbackDominated extends RowReadbackOutcome {
  const RowReadbackDominated(this.storedVector);

  final VersionVector storedVector;

  @override
  bool get passed => true;
}

final class RowReadbackMissing extends RowReadbackOutcome {
  const RowReadbackMissing();

  @override
  bool get passed => false;
}

final class RowReadbackIncompatible extends RowReadbackOutcome {
  const RowReadbackIncompatible(this.storedVector);

  final VersionVector storedVector;

  @override
  bool get passed => false;
}
