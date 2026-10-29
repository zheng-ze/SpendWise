import 'package:flutter/foundation.dart';

// MARK: - State

enum AnalysisQueryState { ready, loading, failed }

// MARK: - Result

@immutable
class AnalysisQueryResult<T> {
  const AnalysisQueryResult({
    required this.value,
    required this.state,
    required this.sourceRevision,
    this.failure,
  });

  final T? value;

  final AnalysisQueryState state;

  final int? sourceRevision;

  final Object? failure;

  @override
  bool operator ==(Object other) {
    return other is AnalysisQueryResult<T> &&
        other.value == value &&
        other.state == state &&
        other.sourceRevision == sourceRevision &&
        other.failure == failure;
  }

  @override
  int get hashCode => Object.hash(value, state, sourceRevision, failure);
}
