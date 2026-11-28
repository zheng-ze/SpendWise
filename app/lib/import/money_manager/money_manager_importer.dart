import 'dart:isolate';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:spendwise/import/money_manager/money_manager_ledger_builder.dart';
import 'package:spendwise/import/money_manager/money_manager_records.dart';
import 'package:spendwise/import/xlsx/xlsx_reader.dart';
import 'package:spendwise/import/xlsx/xlsx_sheet.dart';
import 'package:spendwise/ledger/ledger.dart';

typedef ImportCounts = ({int entries, int accounts, int categories});

sealed class ImportOutcome {
  const ImportOutcome();
}

final class ImportSucceeded extends ImportOutcome {
  const ImportSucceeded(this.counts);

  final ImportCounts counts;
}

final class ImportRejected extends ImportOutcome {
  const ImportRejected(this.errors);

  final List<MoneyManagerImportError> errors;
}

final class ImportSaveFailed extends ImportOutcome {
  const ImportSaveFailed();
}

final class ImportFailedUnexpectedly extends ImportOutcome {
  const ImportFailedUnexpectedly();
}

sealed class ImportBuildResult {
  const ImportBuildResult();
}

final class ImportBuilt extends ImportBuildResult {
  const ImportBuilt(this.state);

  final LedgerState state;
}

final class ImportBuildRejected extends ImportBuildResult {
  const ImportBuildRejected(this.errors);

  final List<MoneyManagerImportError> errors;
}

typedef ImportBuildRunner = Future<ImportBuildResult> Function(Uint8List bytes);

Future<ImportBuildResult> syncImportBuildRunner(Uint8List bytes) async {
  return readAndBuildMoneyManagerLedger(bytes);
}

Future<ImportBuildResult> isolateImportBuildRunner(Uint8List bytes) {
  // Must not capture the calling instance; it would not send.
  return Isolate.run(() => readAndBuildMoneyManagerLedger(bytes));
}

ImportBuildResult readAndBuildMoneyManagerLedger(Uint8List bytes) {
  final XlsxSheet sheet;
  try {
    sheet = const XlsxReader().read(bytes);
  } on XlsxReadFailure {
    return const ImportBuildRejected([UnreadableFile()]);
  }
  final parsed = parseMoneyManagerSheet(sheet);
  return switch (parsed) {
    MoneyManagerRecordsFailed(:final errors) => ImportBuildRejected(errors),
    MoneyManagerRecords(:final rows) => ImportBuilt(
      buildMoneyManagerLedger(rows),
    ),
  };
}

final class MoneyManagerImporter {
  MoneyManagerImporter({
    required this.ledger,
    required this.flush,
    ImportBuildRunner? runner,
  }) : _runner = runner ?? isolateImportBuildRunner;

  final Ledger ledger;
  final Future<void> Function() flush;
  final ImportBuildRunner _runner;

  Future<ImportOutcome> run(Uint8List bytes) async {
    final LedgerState imported;
    final LedgerState snapshot;
    try {
      final built = await _runner(bytes);
      switch (built) {
        case ImportBuildRejected(:final errors):
          return ImportRejected(errors);
        case ImportBuilt(:final state):
          imported = state;
      }
      // No await between the snapshot and the replace, so nothing can change
      // the ledger in between.
      snapshot = _snapshot(ledger.state);
      ledger.replaceContents(imported);
    } catch (_) {
      // Any failure before the ledger is committed (isolate, reader, builder,
      // invariant check) must become ImportFailedUnexpectedly, revision unchanged.
      return const ImportFailedUnexpectedly();
    }
    return _save(snapshot, imported);
  }

  Future<ImportOutcome> _save(
    LedgerState snapshot,
    LedgerState imported,
  ) async {
    try {
      await flush();
    } catch (_) {
      // Any flush failure must roll the ledger back to the snapshot.
      ledger.replaceContents(snapshot);
      return const ImportSaveFailed();
    }
    return ImportSucceeded((
      entries: imported.entries.length,
      accounts: imported.moneySources.length,
      categories: imported.categories.length,
    ));
  }
}

LedgerState _snapshot(LedgerState state) => LedgerState(
  moneySources: state.moneySources,
  entries: state.entries,
  binnedEntries: state.binnedEntries,
  categories: state.categories,
  plans: state.plans,
  budgets: state.budgets,
);
