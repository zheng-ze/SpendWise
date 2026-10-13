import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:spendwise/persistence/database/ledger_database.dart';
import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:sync/sync.dart';

part 'metadata/sync_enrollment_phase.dart';
part 'metadata/sync_device_binding_state.dart';
part 'metadata/sync_backend_kind.dart';
part 'metadata/sync_store_exceptions.dart';
part 'metadata/hosted_operation_legality.dart';
part 'metadata/session_reauth_entry.dart';
part 'metadata/sync_metadata_snapshot.dart';
part 'metadata/metadata_store_meta.dart';
part 'metadata/metadata_store_validation.dart';
part 'metadata/metadata_store_transitions.dart';
part 'metadata/metadata_store_acknowledgements.dart';

// MARK: - Metadata Store

final class SyncMetadataStore implements BackendSelectionWriter {
  SyncMetadataStore(this._db);

  final LedgerDatabase _db;

  @visibleForTesting
  LedgerDatabase get database => _db;

  // MARK: - Backend Selection

  @override
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) => _updateMeta(
    SyncMetaCompanion(backend: Value(backend.code), endpoint: Value(endpoint)),
  );
}
