import 'package:spendwise/sync/sync_metadata_store.dart';

/// Narrow persistence seam for the backend picker.
///
/// The picker controller persists only through this interface, so tests can
/// substitute a recording fake without a database. Implemented by
/// [SyncMetadataStore], whose [SyncMetadataStore.setBackendSelection]
/// signature is retained unchanged.
abstract interface class BackendSelectionWriter {
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  });
}
