import 'package:drift/drift.dart';

// Native builds cannot import the web opener and web builds cannot import the
// native one, because each pulls libraries the other platform has no compiler
// support for. This conditional import picks one at build time.
import 'package:spendwise/persistence/database_connection_native.dart'
    if (dart.library.js_interop) 'package:spendwise/persistence/database_connection_web.dart'
    as platform;

/// Set when the browser could not give us durable storage, so the app can tell
/// the user their data lives only until the tab closes. Always false on native.
bool storageIsDurable = true;

Future<QueryExecutor> openLedgerConnection({String name = 'spendwise'}) async {
  final opened = await platform.openConnection(name);
  storageIsDurable = opened.isDurable;
  return opened.executor;
}

/// What [openLedgerConnection] needs back from whichever platform file the
/// conditional import selected.
class OpenedConnection {
  OpenedConnection(this.executor, {required this.isDurable});

  final QueryExecutor executor;
  final bool isDurable;
}
