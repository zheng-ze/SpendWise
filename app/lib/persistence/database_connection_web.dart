import 'package:drift/wasm.dart';

import 'package:spendwise/persistence/database_connection.dart';

// Both files are served from `web/`, so the app's own base href resolves them.
final _sqlite3Uri = Uri.parse('sqlite3.wasm');
final _workerUri = Uri.parse('drift_worker.js');

Future<OpenedConnection> openConnection(String name) async {
  final result = await WasmDatabase.open(
    databaseName: name,
    sqlite3Uri: _sqlite3Uri,
    driftWorkerUri: _workerUri,
  );

  return OpenedConnection(
    result.resolvedExecutor,
    isDurable: isDurableStorage(result.chosenImplementation),
  );
}

/// `inMemory` is drift's fallback when the browser supports no storage API at
/// all, and `unsafeIndexedDb` cannot stop two tabs corrupting each other's
/// writes. Everything else persists safely.
bool isDurableStorage(WasmStorageImplementation implementation) {
  return switch (implementation) {
    WasmStorageImplementation.inMemory ||
    WasmStorageImplementation.unsafeIndexedDb => false,
    WasmStorageImplementation.opfsShared ||
    WasmStorageImplementation.opfsLocks ||
    WasmStorageImplementation.sharedIndexedDb => true,
  };
}
