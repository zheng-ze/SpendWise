import 'package:drift/drift.dart';

import 'package:spendwise/persistence/database_connection_native.dart'
    as platform;

/// Whether the opened connection gives us durable storage, so the app can tell
/// the user when their data is not being persisted. Always true on the native
/// platforms this app ships to.
bool storageIsDurable = true;

Future<QueryExecutor> openLedgerConnection({String name = 'spendwise'}) async {
  final opened = await platform.openConnection(name);
  storageIsDurable = opened.isDurable;
  return opened.executor;
}

/// What [openLedgerConnection] needs back from the platform opener.
class OpenedConnection {
  OpenedConnection(this.executor, {required this.isDurable});

  final QueryExecutor executor;
  final bool isDurable;
}
