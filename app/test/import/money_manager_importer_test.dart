import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/import/money_manager/money_manager_importer.dart';
import 'package:spendwise/import/money_manager/money_manager_records.dart';
import 'package:spendwise/ledger/ledger.dart';

import '../support/ledger_fixtures.dart';
import '../support/xlsx_fixture.dart';

const _missingHolderID = '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43';
const _importedEntries = 2;
const _importedAccounts = 2;
const _notAnXlsx = [1, 2, 3, 4];
const _invalidCurrency = 'USD';

class _FlushProbe {
  int calls = 0;
  bool shouldThrow = false;

  Future<void> flush() async {
    calls++;
    if (shouldThrow) throw StateError('disk full');
  }
}

class _Snapshot {
  _Snapshot(LedgerState state)
    : moneySources = Map.of(state.moneySources),
      entries = Map.of(state.entries),
      binnedEntries = Map.of(state.binnedEntries),
      categories = Map.of(state.categories),
      plans = Map.of(state.plans),
      budgets = Map.of(state.budgets);

  final Map<String, MoneySource> moneySources;
  final Map<String, Entry> entries;
  final Map<String, Entry> binnedEntries;
  final Map<String, TransactionCategory> categories;
  final Map<String, RecurringPlan> plans;
  final Map<String, Budget> budgets;
}

Ledger _seededLedger() {
  final ledger = Ledger();
  final account = testAccount(name: 'Pre-import');
  final category = testCategory(name: 'Pre-import category');
  ledger.addAccount(account);
  ledger.addCategory(category);
  ledger.addEntry(testEntry(sourceID: account.id, categoryID: category.id));
  return ledger;
}

void _expectSameContents(Ledger ledger, _Snapshot before) {
  final after = ledger.state;
  expect(after.moneySources, before.moneySources);
  expect(after.entries, before.entries);
  expect(after.binnedEntries, before.binnedEntries);
  expect(after.categories, before.categories);
  expect(after.plans, before.plans);
  expect(after.budgets, before.budgets);
}

LedgerState _invalidState() {
  final entry = testEntry(sourceID: _missingHolderID);
  return LedgerState(entries: {entry.id: entry});
}

ImportBuildRunner _runnerReturning(ImportBuildResult result) {
  return (bytes) async => result;
}

ImportBuildRunner _runnerThrowing(Object error) {
  return (bytes) async => throw error;
}

MoneyManagerImporter _importer(
  Ledger ledger,
  _FlushProbe flush, {
  ImportBuildRunner runner = syncImportBuildRunner,
}) {
  return MoneyManagerImporter(
    ledger: ledger,
    flush: flush.flush,
    runner: runner,
  );
}

void main() {
  late Ledger ledger;
  late _FlushProbe flush;
  late _Snapshot before;
  late int revisionBefore;

  setUp(() {
    ledger = _seededLedger();
    flush = _FlushProbe();
    before = _Snapshot(ledger.state);
    revisionBefore = ledger.revision;
  });

  void expectUntouched() {
    expect(ledger.revision, revisionBefore);
    expect(flush.calls, 0);
    _expectSameContents(ledger, before);
  }

  test('successReplacesLedgerAndFlushesOnce', () async {
    final outcome = await _importer(ledger, flush).run(buildMoneyManagerXlsx());

    expect(outcome, isA<ImportSucceeded>());
    expect(ledger.state.entries, hasLength(_importedEntries));
    expect(ledger.state.moneySources, hasLength(_importedAccounts));
    expect(ledger.state.categories, isNotEmpty);
    expect(ledger.revision, revisionBefore + 1);
    expect(flush.calls, 1);
  });

  test('invalidRowRejectsAndLeavesLedgerUntouched', () async {
    final bytes = buildMoneyManagerXlsx(
      rows: [moneyManagerRow(currency: _invalidCurrency)],
    );

    final outcome = await _importer(ledger, flush).run(bytes);

    expect(outcome, isA<ImportRejected>());
    expect((outcome as ImportRejected).errors, isNotEmpty);
    expectUntouched();
  });

  test('notAnXlsxIsRejectedAsUnreadable', () async {
    final bytes = Uint8List.fromList(_notAnXlsx);

    final outcome = await _importer(ledger, flush).run(bytes);

    expect(outcome, isA<ImportRejected>());
    final errors = (outcome as ImportRejected).errors;
    expect(errors.single, isA<UnreadableFile>());
    expectUntouched();
  });

  test('missingPartIsRejectedAsUnreadable', () async {
    final bytes = buildMoneyManagerXlsx(removedParts: {workbookPart});

    final outcome = await _importer(ledger, flush).run(bytes);

    expect(outcome, isA<ImportRejected>());
    expect((outcome as ImportRejected).errors, contains(isA<UnreadableFile>()));
    expectUntouched();
  });

  test('builderStateErrorFailsUnexpectedly', () async {
    final runner = _runnerThrowing(StateError('builder'));

    final outcome = await _importer(
      ledger,
      flush,
      runner: runner,
    ).run(Uint8List(0));

    expect(outcome, isA<ImportFailedUnexpectedly>());
    expectUntouched();
  });

  test('runnerFailureFailsUnexpectedly', () async {
    Future<ImportBuildResult> runner(Uint8List bytes) {
      throw StateError('isolate lost');
    }

    final outcome = await _importer(
      ledger,
      flush,
      runner: runner,
    ).run(Uint8List(0));

    expect(outcome, isA<ImportFailedUnexpectedly>());
    expectUntouched();
  });

  test('invalidReplacementFailsUnexpectedly', () async {
    final runner = _runnerReturning(ImportBuilt(_invalidState()));

    final outcome = await _importer(
      ledger,
      flush,
      runner: runner,
    ).run(Uint8List(0));

    expect(outcome, isA<ImportFailedUnexpectedly>());
    expectUntouched();
  });

  test('flushFailureRestoresSnapshotAndReportsSaveFailed', () async {
    flush.shouldThrow = true;

    final outcome = await _importer(ledger, flush).run(buildMoneyManagerXlsx());

    expect(outcome, isA<ImportSaveFailed>());
    expect(flush.calls, 1);
    _expectSameContents(ledger, before);
  });

  test('defaultRunnerImportsThroughTheIsolate', () async {
    final importer = MoneyManagerImporter(ledger: ledger, flush: flush.flush);

    final outcome = await importer.run(buildMoneyManagerXlsx());

    expect(outcome, isA<ImportSucceeded>());
    expect(flush.calls, 1);
  });

  test('isolateRunnerBuildsLedgerAcrossIsolateBoundary', () async {
    final result = await isolateImportBuildRunner(buildMoneyManagerXlsx());

    expect(result, isA<ImportBuilt>());
    final state = (result as ImportBuilt).state;
    expect(state.entries, hasLength(_importedEntries));
    expect(state.moneySources, hasLength(_importedAccounts));
  });
}
