import 'package:drift/drift.dart';
import 'package:spendwise/persistence/tables.dart';

part 'ledger_database.g.dart';

@DriftDatabase(
  tables: [Accounts, SubPockets, Categories, Entries, Plans, StoreMeta],
)
class LedgerDatabase extends _$LedgerDatabase {
  LedgerDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
