import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/import/money_manager/money_manager_importer.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/import_error_text.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';

import '../../support/ledger_fixtures.dart';
import '../../support/xlsx_fixture.dart';

const _invalidCurrency = 'USD';
const _invalidRowMessage = 'Row 2: Currency "USD" isn\'t supported (only SGD)';
const _importedEntries = 2;
const _pickerFailure = 'picker failed';

class _FlushProbe {
  int calls = 0;
  bool shouldThrow = false;

  Future<void> flush() async {
    calls++;
    if (shouldThrow) throw StateError('disk full');
  }
}

class _RollbackFailingLedger extends Ledger {
  int replaceCalls = 0;

  @override
  List<LedgerChange> replaceContents(LedgerState replacement) {
    replaceCalls++;
    if (replaceCalls > 1) throw StateError('rollback failed');
    return super.replaceContents(replacement);
  }
}

base class _DisposalObserver extends ProviderObserver {
  bool settingsDisposed = false;

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    if (context.provider == settingsRootViewModelProvider) {
      settingsDisposed = true;
    }
  }
}

class _Harness {
  _Harness._(this.ledger, this.flush, this.container, this.disposals) {
    subscription = container.listen(
      settingsRootViewModelProvider,
      _recordStep,
      fireImmediately: false,
    );
  }

  factory _Harness({
    Ledger? ledger,
    ImportBuildRunner runner = syncImportBuildRunner,
    bool importerAvailable = true,
  }) {
    final seeded = ledger ?? _seededLedger();
    final flush = _FlushProbe();
    final importer = importerAvailable
        ? MoneyManagerImporter(
            ledger: seeded,
            flush: flush.flush,
            runner: runner,
          )
        : null;
    final disposals = _DisposalObserver();
    final container = ProviderContainer(
      observers: [disposals],
      overrides: [moneyManagerImporterProvider.overrideWithValue(importer)],
    );
    addTearDown(container.dispose);
    return _Harness._(seeded, flush, container, disposals);
  }

  final Ledger ledger;
  final _FlushProbe flush;
  final ProviderContainer container;
  final _DisposalObserver disposals;
  final List<SettingsStep> steps = [];
  late ProviderSubscription<SettingsRootViewState> subscription;

  SettingsRootNotifier get notifier =>
      container.read(settingsRootViewModelProvider.notifier);
  SettingsRootViewState get state =>
      container.read(settingsRootViewModelProvider);

  void _recordStep(
    SettingsRootViewState? previous,
    SettingsRootViewState next,
  ) {
    final step = next.step;
    if (step == null || identical(previous?.step, step)) return;
    steps.add(step);
  }

  Future<void> confirmFile(Uint8List bytes) async {
    notifier.requestImport();
    notifier.applyPickedFile(bytes: bytes);
  }

  Future<void> importFile(Uint8List bytes) async {
    await confirmFile(bytes);
    await notifier.applyImportConfirmed(true);
  }

  Future<bool> providerExists() async {
    await container.pump();
    return !disposals.settingsDisposed;
  }
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

Uint8List _invalidFile() {
  return buildMoneyManagerXlsx(
    rows: [moneyManagerRow(currency: _invalidCurrency)],
  );
}

void _expectLedgerUnchanged(_Harness harness, int revision) {
  expect(harness.ledger.revision, revision);
  expect(harness.flush.calls, 0);
}

void main() {
  test('requestImport emits ImportFileRequested and starts picking', () {
    final harness = _Harness();

    harness.notifier.requestImport();

    expect(harness.state.importStatus, ImportStatus.picking);
    expect(harness.steps, [isA<ImportFileRequested>()]);
  });

  test('a second requestImport while picking emits nothing', () {
    final harness = _Harness();
    harness.notifier.requestImport();

    harness.notifier.requestImport();

    expect(harness.state.importStatus, ImportStatus.picking);
    expect(harness.steps, hasLength(1));
  });

  test('a cancelled pick returns to idle without a step', () {
    final harness = _Harness();
    harness.notifier.requestImport();

    harness.notifier.applyPickedFile(bytes: null);

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.steps, [isA<ImportFileRequested>()]);
    expect(harness.state.importErrors, isEmpty);
  });

  test('picked bytes request the confirmation', () async {
    final harness = _Harness();

    await harness.confirmFile(buildMoneyManagerXlsx());

    expect(harness.state.importStatus, ImportStatus.confirming);
    expect(harness.steps.last, isA<ImportConfirmationRequested>());
  });

  test('a picker error shows the open-failed message', () {
    final harness = _Harness();
    harness.notifier.requestImport();

    harness.notifier.applyPickedFile(pickerError: _pickerFailure);

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.state.importErrors, [importFileOpenFailedMessage]);
    expect(harness.steps.last, isA<ImportErrorsRequested>());
  });

  test('declining the confirmation changes nothing', () async {
    final harness = _Harness();
    final revision = harness.ledger.revision;
    await harness.confirmFile(buildMoneyManagerXlsx());

    await harness.notifier.applyImportConfirmed(false);

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.state.importErrors, isEmpty);
    _expectLedgerUnchanged(harness, revision);
  });

  test('confirming replaces the ledger and ends idle without errors', () async {
    final harness = _Harness();

    await harness.importFile(buildMoneyManagerXlsx());

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.state.importErrors, isEmpty);
    expect(harness.ledger.state.entries, hasLength(_importedEntries));
    expect(harness.flush.calls, 1);
  });

  test('an invalid file shows row messages and keeps the ledger', () async {
    final harness = _Harness();
    final revision = harness.ledger.revision;

    await harness.importFile(_invalidFile());

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.state.importErrors, [_invalidRowMessage]);
    expect(harness.steps.last, isA<ImportErrorsRequested>());
    _expectLedgerUnchanged(harness, revision);
  });

  test('a save failure shows its message', () async {
    final harness = _Harness();
    harness.flush.shouldThrow = true;

    await harness.importFile(buildMoneyManagerXlsx());

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.state.importErrors, [importSaveFailedMessage]);
    expect(harness.steps.last, isA<ImportErrorsRequested>());
  });

  test('an importer that throws shows the unexpected message', () async {
    final harness = _Harness(ledger: _RollbackFailingLedger());
    harness.flush.shouldThrow = true;

    await harness.importFile(buildMoneyManagerXlsx());

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.state.importErrors, [importUnexpectedMessage]);
    expect(harness.steps.last, isA<ImportErrorsRequested>());
  });

  test('a missing importer shows the unexpected message', () async {
    final harness = _Harness(importerAvailable: false);

    await harness.importFile(buildMoneyManagerXlsx());

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.state.importErrors, [importUnexpectedMessage]);
    expect(harness.steps.last, isA<ImportErrorsRequested>());
  });

  test('the error outcome survives losing the only listener', () async {
    final gate = Completer<void>();
    final bytes = buildMoneyManagerXlsx();
    final harness = _Harness(
      runner: (bytes) async {
        await gate.future;
        return readAndBuildMoneyManagerLedger(bytes);
      },
    );
    harness.flush.shouldThrow = true;
    await harness.confirmFile(bytes);
    final running = harness.notifier.applyImportConfirmed(true);
    expect(harness.state.importStatus, ImportStatus.running);

    harness.subscription.close();
    gate.complete();
    await running;

    expect(await harness.providerExists(), isTrue);
    expect(harness.state.importErrors, [importSaveFailedMessage]);
    expect(harness.state.step, isA<ImportErrorsRequested>());
  });

  test('dismissing the errors releases the kept-alive provider', () async {
    final harness = _Harness();
    harness.flush.shouldThrow = true;
    await harness.importFile(buildMoneyManagerXlsx());
    harness.subscription.close();
    expect(await harness.providerExists(), isTrue);

    harness.notifier.dismissImportErrors();

    expect(await harness.providerExists(), isFalse);
  });

  test('dismissImportErrors clears errors from the picker path', () {
    final harness = _Harness();
    harness.notifier.requestImport();
    harness.notifier.applyPickedFile(pickerError: _pickerFailure);

    harness.notifier.dismissImportErrors();

    expect(harness.state.importErrors, isEmpty);
  });

  test('applyPickedFile after the container is disposed is a no-op', () {
    final harness = _Harness();
    final notifier = harness.notifier;
    notifier.requestImport();
    harness.subscription.close();
    harness.container.dispose();

    expect(
      () => notifier.applyPickedFile(bytes: buildMoneyManagerXlsx()),
      returnsNormally,
    );
  });

  test('applyPickedFile outside picking is ignored', () {
    final harness = _Harness();

    harness.notifier.applyPickedFile(bytes: buildMoneyManagerXlsx());

    expect(harness.state.importStatus, ImportStatus.idle);
    expect(harness.steps, isEmpty);
  });

  test('applyImportConfirmed outside confirming is ignored', () async {
    final harness = _Harness();
    final revision = harness.ledger.revision;

    await harness.notifier.applyImportConfirmed(true);

    expect(harness.state.importStatus, ImportStatus.idle);
    _expectLedgerUnchanged(harness, revision);
  });
}
