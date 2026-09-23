import 'package:sync/sync.dart';

sealed class RowReadbackOutcome {
  const RowReadbackOutcome();

  bool get passed;
}

final class RowReadbackEqual extends RowReadbackOutcome {
  const RowReadbackEqual();

  @override
  bool get passed => true;
}

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
