import 'package:drift/drift.dart';

import 'package:spendwise/persistence/database_connection_native.dart'
    as platform;

Future<QueryExecutor> openLedgerConnection({String name = 'spendwise'}) async {
  return platform.openConnection(name);
}
