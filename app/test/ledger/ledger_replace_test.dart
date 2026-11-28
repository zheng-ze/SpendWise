import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';

import '../support/ledger_fixtures.dart';

const _missingHolderID = '4f2c1b90-3e5d-4a18-9c7b-6d0e2a1f8b43';

class _Probe {
  _Probe(Ledger ledger) {
    ledger.bus.subscribe().listen(batches.add);
    ledger.addListener(() => notifications++);
  }

  final batches = <List<LedgerChange>>[];
  int notifications = 0;
}

LedgerState _validReplacement() {
  final account = testAccount();
  return LedgerState(moneySources: {account.id: MoneySource.account(account)});
}

LedgerState _invalidReplacement() {
  final entry = testEntry(sourceID: _missingHolderID);
  return LedgerState(entries: {entry.id: entry});
}

void main() {
  test('replaceContentsAdvancesRevisionOnce', () {
    final ledger = Ledger();
    ledger.addAccount(testAccount());
    final before = ledger.revision;

    ledger.replaceContents(_validReplacement());

    expect(ledger.revision, before + 1);
  });

  test('replaceContentsPublishesOneBatchAndNotifiesOnce', () {
    final ledger = Ledger();
    ledger.addAccount(testAccount());
    final probe = _Probe(ledger);

    final changes = ledger.replaceContents(_validReplacement());

    expect(probe.batches, [changes]);
    expect(probe.notifications, 1);
  });

  test('replaceContentsSwapsTheLedgerContents', () {
    final ledger = Ledger();
    ledger.addAccount(testAccount());
    final replacement = _validReplacement();

    ledger.replaceContents(replacement);

    expect(ledger.state.moneySources, replacement.moneySources);
  });

  test('emptyReplacementOfEmptyLedgerPublishesNothing', () {
    final ledger = Ledger();
    final probe = _Probe(ledger);

    final changes = ledger.replaceContents(LedgerState());

    expect(changes, isEmpty);
    expect(ledger.revision, 0);
    expect(probe.batches, isEmpty);
    expect(probe.notifications, 0);
  });

  test('invalidReplacementLeavesRevisionAndPublishesNothing', () {
    final ledger = Ledger();
    ledger.addAccount(testAccount());
    final probe = _Probe(ledger);

    expect(
      () => ledger.replaceContents(_invalidReplacement()),
      throwsA(isA<StateError>()),
    );

    expect(ledger.revision, 1);
    expect(probe.batches, isEmpty);
    expect(probe.notifications, 0);
  });
}
