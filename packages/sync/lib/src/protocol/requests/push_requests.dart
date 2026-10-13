part of '../../../sync.dart';

// MARK: - Push Request

final class PushRequest {
  PushRequest({required Iterable<SyncEnvelope> envelopes, this.writeProof})
      : envelopes = List.unmodifiable(envelopes);

  final List<SyncEnvelope> envelopes;
  final String? writeProof;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'envelopes': <Object?>[for (final item in envelopes) item.toWireJson()],
        if (writeProof != null) 'write_proof': writeProof,
      };
}

// MARK: - Push Row Outcomes

sealed class PushRowOutcome {
  const PushRowOutcome({required this.siblingID});

  final String siblingID;
}

final class PushApplied extends PushRowOutcome {
  const PushApplied({
    required super.siblingID,
    required this.resultingFrontier,
  });

  final VersionVector resultingFrontier;
}

final class PushAlreadyPresent extends PushRowOutcome {
  const PushAlreadyPresent({
    required super.siblingID,
    required this.resultingFrontier,
  });

  final VersionVector resultingFrontier;
}

final class PushRejected extends PushRowOutcome {
  const PushRejected({required super.siblingID});
}

// MARK: - Push Response

final class PushResponse extends _OpaqueWireResponse {
  PushResponse(super.wire);

  Map<SyncRowID, PushRowOutcome> get rowOutcomes {
    final raw = wire['rows'];
    if (raw is! List<Object?>) {
      throw const FormatException(
        'Push response rows must be a list.',
      );
    }
    final decoded = <SyncRowID, PushRowOutcome>{};
    for (var index = 0; index < raw.length; index++) {
      final element = raw[index];
      if (element is! Map<Object?, Object?>) {
        throw FormatException(
          'Push response rows[$index] must be an object.',
        );
      }
      final fields = element.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      try {
        final entry = _decodePushRow(fields);
        decoded[entry.key] = entry.value;
      } on FormatException catch (error) {
        throw FormatException(
          'Push response rows[$index] is malformed: ${error.message}',
        );
      }
    }
    return Map.unmodifiable(decoded);
  }
}

// MARK: - Push Row Decoding

MapEntry<SyncRowID, PushRowOutcome> _decodePushRow(
    Map<String, Object?> fields) {
  final row = SyncRowID.of(
    SyncCollection.fromWireName(_expectString(fields, 'collection')),
    _expectString(fields, 'row_id'),
  );
  final siblingID = _expectString(fields, 'sibling_id');
  final status = _expectString(fields, 'status');
  switch (status) {
    case 'applied':
      return MapEntry(
        row,
        PushApplied(
          siblingID: siblingID,
          resultingFrontier: _expectPushFrontier(fields),
        ),
      );
    case 'already_present':
      return MapEntry(
        row,
        PushAlreadyPresent(
          siblingID: siblingID,
          resultingFrontier: _expectPushFrontier(fields),
        ),
      );
    case 'rejected':
      return MapEntry(row, PushRejected(siblingID: siblingID));
    default:
      throw FormatException('Unknown push status: $status');
  }
}

VersionVector _expectPushFrontier(Map<String, Object?> fields) {
  final raw = fields['version_vector'];
  if (raw is! Map<Object?, Object?>) {
    throw const FormatException(
      'Push response version_vector must be an object.',
    );
  }
  return VersionVector.fromWireCounters(
    raw.map<String, Object?>((key, value) => MapEntry(key.toString(), value)),
  );
}
