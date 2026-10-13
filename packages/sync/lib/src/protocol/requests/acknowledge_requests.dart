part of '../../../sync.dart';

// MARK: - Acknowledge Request

final class AcknowledgeRequest {
  const AcknowledgeRequest({
    required this.collection,
    required this.checkpoint,
  });

  final SyncCollection collection;
  final String checkpoint;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'collection': collection.wireName,
        'checkpoint': checkpoint,
      };
}

// MARK: - Acknowledge Response

final class AcknowledgeResponse extends _OpaqueWireResponse {
  AcknowledgeResponse(super.wire);
}
