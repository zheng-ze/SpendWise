import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';

void main() {
  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    type: AccountType.checking,
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000003',
    name: 'Piggy Bank',
    type: AccountType.savings,
  );
  final card = Account(
    id: 'a0000000-0000-0000-0000-000000000004',
    name: 'Visa',
    type: AccountType.card,
    statementDay: 10,
  );
  final purchase = Entry(
    date: DateTime.utc(2026, 5, 5),
    amount: Decimal.parse('-40'),
    name: 'groceries',
    sourceID: card.id,
  );

  Ledger buildLedger() {
    return Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          savings.id: MoneySource.account(savings),
          card.id: MoneySource.account(card),
        },
        entries: {purchase.id: purchase},
      ),
    );
  }

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    return container;
  }

  AccountRow? rowFor(AccountsProjection projection, String id) {
    final rows = [for (final section in projection.sections) ...section.rows];
    return rows.where((row) => row.id == id).firstOrNull;
  }

  Decimal? outstandingOf(AccountRow? row) =>
      (row?.amount as CardAmounts?)?.outstanding;

  test('groups active accounts into sections and computes net worth', () {
    final container = buildContainer(buildLedger());

    final projection = container.read(accountsProjectionProvider).requireValue;

    expect(rowFor(projection, checking.id), isNotNull);
    expect(rowFor(projection, savings.id), isNotNull);
    expect(projection.netWorth, Accounting.netWorth(buildLedger().state));
  });

  test('a ledger change refreshes sections and net worth', () {
    final ledger = buildLedger();
    final container = buildContainer(ledger);
    container.listen(accountsProjectionProvider, (previous, next) {});

    ledger.deleteAccount(savings.id);

    final projection = container.read(accountsProjectionProvider).requireValue;
    expect(rowFor(projection, savings.id), isNull);
    expect(projection.netWorth, Accounting.netWorth(ledger.state));
  });

  test('advancing today refreshes the statement-cut outstanding', () {
    var now = DateTime.utc(2026, 5, 9);
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(accountsProjectionProvider, (previous, next) {});
    final before = rowFor(
      container.read(accountsProjectionProvider).requireValue,
      card.id,
    );

    now = DateTime.utc(2026, 5, 11);
    container.invalidate(todayProvider);

    final after = rowFor(
      container.read(accountsProjectionProvider).requireValue,
      card.id,
    );
    expect(outstandingOf(before), Decimal.parse('40'));
    expect(outstandingOf(after), Decimal.zero);
  });
}
