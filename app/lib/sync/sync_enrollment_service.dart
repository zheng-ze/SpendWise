import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:spendwise/persistence/store/device_identity.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/reconciliation_snapshot_hasher.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_repair_gate.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

part 'enrollment/sync_enrollment_exception.dart';
part 'enrollment/enrollment_phase_machine.dart';
part 'enrollment/enrollment_binding_step.dart';
part 'enrollment/enrollment_snapshot_step.dart';
part 'enrollment/enrollment_session_step.dart';
part 'enrollment/enrollment_failure_routing.dart';

// MARK: - Enrollment Service

final class SyncEnrollmentService {
  SyncEnrollmentService({
    required this.authenticator,
    required this.backend,
    required this.metadataStore,
    required this.secretStore,
    required this.database,
    required this.buildBeginRequest,
    required this.buildCompleteRequest,
    required this.resolveE2EKey,
    required this.buildSnapshotHasher,
    required this.bindingAuthorizer,
    required this.bindingIdentifier,
    required this.resolveBindingOtp,
    SyncRepairGate? repairGate,
  }) : repairGate = repairGate ?? SyncRepairGate.forDatabase(database);

  final SyncAuthenticator authenticator;
  final SyncBackend backend;
  final SyncMetadataStore metadataStore;
  final SecretStore secretStore;
  final LedgerDatabase database;
  final SyncRepairGate repairGate;
  final BeginEnrollmentRequest Function() buildBeginRequest;
  final Future<CompleteEnrollmentRequest> Function(
    EnrollmentChallenge challenge,
  )
  buildCompleteRequest;
  final Future<Uint8List> Function() resolveE2EKey;

  final ReconciliationSnapshotHasher Function(SyncCredential credential)
  buildSnapshotHasher;

  final DeviceBindingAuthorizer bindingAuthorizer;
  final String bindingIdentifier;
  final Future<String> Function(EnrollmentChallenge challenge)
  resolveBindingOtp;

  static const _writeProofWireKey = 'write_proof';
  static const _deviceSecretWireKey = 'device_secret';
}
