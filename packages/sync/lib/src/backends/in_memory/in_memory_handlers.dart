part of '../../../sync.dart';

// MARK: - In-Memory Handler Seams

typedef PushHandler = Future<SyncOutcome<PushResponse>> Function(
  SyncCredential credential,
  PushRequest request,
);
typedef PullHandler = Future<SyncOutcome<PullResponse>> Function(
  SyncCredential credential,
  PullRequest request,
);
typedef ReconcileHandler = Future<SyncOutcome<ReconcileResponse>> Function(
  SyncCredential credential,
  ReconcileRequest request,
);
typedef AcknowledgeHandler = Future<SyncOutcome<AcknowledgeResponse>> Function(
  SyncCredential credential,
  AcknowledgeRequest request,
);
