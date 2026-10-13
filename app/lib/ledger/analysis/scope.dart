import 'package:domain/domain.dart';

// MARK: - Scope

Set<String>? normalizedScope(Set<String>? sourceIDs) {
  if (sourceIDs == null) return null;
  return sourceIDs.map(normalizedID).toSet();
}

bool inScope(HolderReferencing holder, Set<String>? scope) {
  return scope == null || holder.touches(scope);
}

// MARK: - Windows

DateRange normalizedWindow(DateRange window) {
  final start = startOfDayUtc(window.start);
  final end = startOfDayUtc(window.end);
  if (end.isBefore(start)) {
    throw ArgumentError.value(window, 'window', 'End is before start.');
  }
  return DateRange(start, end);
}
