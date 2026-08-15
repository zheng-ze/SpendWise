import 'package:domain/domain.dart';

/// Caches the kind-and-bucket-filtered scan of the analysis cache's items,
/// keyed on its items revision. The window filter is the caller's job, run
/// fresh on top of the cached list on every call so a period change never
/// forces a recompute.
class AnalysisScan {
  int? _cachedRevision;
  CategoryKind? _cachedKind;
  Set<String?>? _cachedBuckets;
  List<AnalysisItem> _cachedFiltered = const [];

  List<AnalysisItem> scan({
    required List<AnalysisItem> items,
    required int itemsRevision,
    required CategoryKind kind,
    required Set<String?> buckets,
  }) {
    final isFresh =
        _cachedRevision == itemsRevision &&
        _cachedKind == kind &&
        _setEquals(_cachedBuckets, buckets);
    if (isFresh) return _cachedFiltered;

    _cachedRevision = itemsRevision;
    _cachedKind = kind;
    _cachedBuckets = buckets;
    _cachedFiltered = items.filtered(kind: kind, buckets: buckets);
    return _cachedFiltered;
  }
}

bool _setEquals(Set<String?>? a, Set<String?> b) {
  if (a == null) return false;
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
