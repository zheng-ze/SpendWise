import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_logic.dart';

void main() {
  test('pocketable parents exclude cards', () {
    final cash = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Wallet',
      type: AccountType.cash,
    );
    final card = Account(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Visa',
      type: AccountType.card,
      statementDay: 15,
    );
    final state = LedgerState(
      moneySources: {
        cash.id: MoneySource.account(cash),
        card.id: MoneySource.account(card),
      },
    );

    final parents = pocketableParents(state);

    expect(parents.map((a) => a.id), [cash.id]);
  });

  test('pocketable parents exclude archived accounts', () {
    final active = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Active',
      type: AccountType.cash,
    );
    final archived = Account(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Archived',
      type: AccountType.cash,
      lifecycle: LifecycleState.archived,
    );
    final state = LedgerState(
      moneySources: {
        active.id: MoneySource.account(active),
        archived.id: MoneySource.account(archived),
      },
    );

    final parents = pocketableParents(state);

    expect(parents.map((a) => a.id), [active.id]);
  });

  test('pocketable parents sorted by name', () {
    final zebra = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Zebra',
      type: AccountType.cash,
    );
    final alpha = Account(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Alpha',
      type: AccountType.cash,
    );
    final state = LedgerState(
      moneySources: {
        zebra.id: MoneySource.account(zebra),
        alpha.id: MoneySource.account(alpha),
      },
    );

    final parents = pocketableParents(state);

    expect(parents.map((a) => a.name), ['Alpha', 'Zebra']);
  });

  test('canSave requires a non-blank name', () {
    expect(
      canSaveAccountForm(
        kind: AccountFormKind.account,
        name: '   ',
        parentId: null,
      ),
      isFalse,
    );
    expect(
      canSaveAccountForm(
        kind: AccountFormKind.account,
        name: 'Wallet',
        parentId: null,
      ),
      isTrue,
    );
  });

  test('canSave for a subpocket also requires a parent', () {
    expect(
      canSaveAccountForm(
        kind: AccountFormKind.subpocket,
        name: 'Vacation',
        parentId: null,
      ),
      isFalse,
    );
    expect(
      canSaveAccountForm(
        kind: AccountFormKind.subpocket,
        name: 'Vacation',
        parentId: 'a0000000-0000-0000-0000-000000000001',
      ),
      isTrue,
    );
  });
}
