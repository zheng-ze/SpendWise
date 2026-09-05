/// Returns the first non-null result from [candidates], evaluated in order and
/// short-circuiting after the first hit.
///
/// The selector is platform-agnostic: it only encodes "first non-null candidate
/// wins, in order." Domain helpers keep their own web/gate rules and pass an
/// ordered list of already-gated candidate builders.
T? selectPlatformAdapter<T>(List<T? Function()> candidates) {
  for (final candidate in candidates) {
    final value = candidate();
    if (value != null) return value;
  }
  return null;
}
