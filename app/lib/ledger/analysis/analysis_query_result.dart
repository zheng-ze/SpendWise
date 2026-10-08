import 'package:flutter/foundation.dart';

enum AnalysisQueryState { ready, loading, failed }

@immutable
class AnalysisQueryResult<T> {
  const AnalysisQueryResult({
    required this.value,
    required this.state,
    required this.sourceRevision,
  });

  final T? value;

  final AnalysisQueryState state;

  final int? sourceRevision;

  @override
  bool operator ==(Object other) {
    return other is AnalysisQueryResult<T> &&
        other.value == value &&
        other.state == state &&
        other.sourceRevision == sourceRevision;
  }

  @override
  int get hashCode => Object.hash(value, state, sourceRevision);
}
