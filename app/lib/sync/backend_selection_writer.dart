import 'package:spendwise/sync/sync_metadata_store.dart';

abstract interface class BackendSelectionWriter {
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  });
}
