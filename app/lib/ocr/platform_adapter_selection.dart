T? selectPlatformAdapter<T>(List<T? Function()> candidates) {
  for (final candidate in candidates) {
    final value = candidate();
    if (value != null) return value;
  }
  return null;
}
