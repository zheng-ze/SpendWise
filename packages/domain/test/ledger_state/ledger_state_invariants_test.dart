import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  String uuid(int n) =>
      '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

  final accountID = uuid(1);
  final pocketID = uuid(2);
  final entryID = uuid(3);
  final planID = uuid(4);

  Account account({
    Set<String> subPocketIDs = const {},
    LifecycleState lifecycle = LifecycleState.active,
  }) => Account(
    id: accountID,
    name: 'Checking',
    type: AccountType.cash,
    subPocketIDs: subPocketIDs,
    lifecycle: lifecycle,
  );

  Entry entry({
    String? sourceID,
    String? destinationID,
    String? categoryID,
    Decimal? amount,
  }) => Entry(
    id: entryID,
    date: DateTime.utc(2026),
    amount: amount ?? Decimal.fromInt(-10),
    name: 'e',
    categoryID: categoryID,
    sourceID: sourceID ?? accountID,
    destinationID: destinationID,
  );

  RecurringPlan plan({String? sourceID, DateTime? endDate}) => RecurringPlan(
    id: planID,
    template: EntryTemplate(
      amount: Decimal.fromInt(-25),
      name: 'rent',
      sourceID: sourceID ?? accountID,
    ),
    frequency: RecurrenceFrequency.monthly,
    anchor: DateTime.utc(2026, 1, 15),
    endDate: endDate,
    lastResolvedDate: DateTime.utc(2026, 1, 15),
  );

  test('the raw constructor stores what it is given without validating', () {
    final state = LedgerState(plans: {planID: plan(sourceID: uuid(9))});

    expect(state.plans[planID], isNotNull);
  });

  test('an active entry referencing an archived holder violates nothing', () {
    final state = LedgerState(
      moneySources: {
        accountID: AccountSource(account(lifecycle: LifecycleState.archived)),
      },
      entries: {entryID: entry()},
    );

    expect(state.assertInvariants, returnsNormally);
  });

  test('a pocket no account links to is caught', () {
    final state = LedgerState(
      moneySources: {
        accountID: AccountSource(account()),
        pocketID: PocketSource(SubPocket(id: pocketID, name: 'Bills')),
      },
    );

    expect(
      state.assertInvariants,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('invariant 3'),
        ),
      ),
    );
  });

  test('a referenceOnly account keeping a linked pocket is legal', () {
    final state = LedgerState(
      moneySources: {
        accountID: AccountSource(
          account(
            subPocketIDs: {pocketID},
            lifecycle: LifecycleState.referenceOnly,
          ),
        ),
        pocketID: PocketSource(
          SubPocket(
            id: pocketID,
            name: 'Bills',
            lifecycle: LifecycleState.referenceOnly,
          ),
        ),
      },
      entries: {entryID: entry(sourceID: pocketID)},
    );

    expect(state.assertInvariants, returnsNormally);
  });

  test('a plan naming a holder absent from the table is caught', () {
    final state = LedgerState(
      moneySources: {accountID: AccountSource(account())},
      plans: {planID: plan(sourceID: uuid(9))},
    );

    expect(
      state.assertInvariants,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('invariant 7'), contains(uuid(9))),
        ),
      ),
    );
  });

  test('a stored plan whose cursor reached its end date is caught', () {
    final state = LedgerState(
      moneySources: {accountID: AccountSource(account())},
      plans: {planID: plan(endDate: DateTime.utc(2026, 1, 15))},
    );

    expect(
      state.assertInvariants,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('invariant 8'), contains(planID)),
        ),
      ),
    );
  });

  TransactionCategory categoryRow({
    required String id,
    String? parentID,
    LifecycleState lifecycle = LifecycleState.active,
  }) => TransactionCategory(
    id: id,
    name: 'Rent',
    kind: CategoryKind.expense,
    colorHex: '#888888',
    includeInAnalysis: true,
    parentID: parentID,
    symbol: 'tag',
    lifecycle: lifecycle,
  );

  // A parent is referenced through a pocket only when that pocket is itself
  // referenced, so a weaker recursion would wrongly clear the account instead of the pocket.
  group('a pocket is judged by its references, not its row', () {
    test('an entry-free pocket does not hold up its referenceOnly account', () {
      final state = LedgerState(
        moneySources: {
          accountID: AccountSource(
            account(
              subPocketIDs: {pocketID},
              lifecycle: LifecycleState.referenceOnly,
            ),
          ),
          pocketID: PocketSource(SubPocket(id: pocketID, name: 'Bills')),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 11'), contains(accountID)),
          ),
        ),
      );
    });

    test('an entry on the pocket does hold the account up', () {
      final state = LedgerState(
        moneySources: {
          accountID: AccountSource(
            account(
              subPocketIDs: {pocketID},
              lifecycle: LifecycleState.referenceOnly,
            ),
          ),
          pocketID: PocketSource(
            SubPocket(
              id: pocketID,
              name: 'Bills',
              lifecycle: LifecycleState.referenceOnly,
            ),
          ),
        },
        entries: {entryID: entry(sourceID: pocketID)},
      );

      expect(state.assertInvariants, returnsNormally);
    });
  });

  group('clause 15, a pocket may not outlive its account', () {
    test('an archived account holding an active pocket is caught', () {
      final state = LedgerState(
        moneySources: {
          accountID: AccountSource(
            account(
              subPocketIDs: {pocketID},
              lifecycle: LifecycleState.archived,
            ),
          ),
          pocketID: PocketSource(SubPocket(id: pocketID, name: 'Bills')),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 15'), contains(pocketID)),
          ),
        ),
      );
    });

    test('a pocket less alive than an active account is legal', () {
      final state = LedgerState(
        moneySources: {
          accountID: AccountSource(account(subPocketIDs: {pocketID})),
          pocketID: PocketSource(
            SubPocket(
              id: pocketID,
              name: 'Bills',
              lifecycle: LifecycleState.archived,
            ),
          ),
        },
      );

      expect(state.assertInvariants, returnsNormally);
    });
  });

  group('clause 5 rejects a live child under a parent that is leaving', () {
    final parentID = uuid(5);
    final childID = uuid(6);

    test('an active child under a referenceOnly parent is caught', () {
      final state = LedgerState(
        moneySources: {accountID: AccountSource(account())},
        entries: {entryID: entry()},
        categories: {
          parentID: categoryRow(
            id: parentID,
            lifecycle: LifecycleState.referenceOnly,
          ),
          childID: categoryRow(id: childID, parentID: parentID),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 5'), contains(childID)),
          ),
        ),
      );
    });

    test('an active child under an archived parent stays legal', () {
      final state = LedgerState(
        categories: {
          parentID: categoryRow(
            id: parentID,
            lifecycle: LifecycleState.archived,
          ),
          childID: categoryRow(id: childID, parentID: parentID),
        },
      );

      expect(state.assertInvariants, returnsNormally);
    });

    test('addCategory refuses a referenceOnly parent', () {
      final state = LedgerState();
      state.addAccount(account());
      state.addCategory(categoryRow(id: parentID));
      state.addEntry(
        Entry(
          id: entryID,
          date: DateTime.utc(2026),
          amount: Decimal.fromInt(-10),
          name: 'e',
          sourceID: accountID,
          categoryID: parentID,
        ),
      );
      state.deleteCategory(parentID);
      state.purgeCategory(parentID);

      expect(
        () => state.addCategory(categoryRow(id: childID, parentID: parentID)),
        throwsA(InactiveReference(parentID)),
      );
    });
  });

  group('clause 14, a plan may not reference a row that is leaving', () {
    test('a plan naming a referenceOnly holder is caught', () {
      final state = LedgerState(
        moneySources: {
          accountID: AccountSource(
            account(lifecycle: LifecycleState.referenceOnly),
          ),
        },
        entries: {entryID: entry()},
        plans: {planID: plan()},
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 14'), contains(accountID)),
          ),
        ),
      );
    });

    // Archiving freezes a plan rather than dropping it, so restore can return
    // a holder that still has one.
    test('a plan naming an archived holder is legal', () {
      final state = LedgerState(
        moneySources: {
          accountID: AccountSource(account(lifecycle: LifecycleState.archived)),
        },
        plans: {planID: plan()},
      );

      expect(state.assertInvariants, returnsNormally);
    });
  });

  group('clause 1, map keys match row ids', () {
    test('a money source filed under someone else\'s id is caught', () {
      final state = LedgerState(
        moneySources: {uuid(9): AccountSource(account())},
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 1'), contains(uuid(9))),
          ),
        ),
      );
    });

    test('an entry filed under someone else\'s id is caught', () {
      final state = LedgerState(
        moneySources: {accountID: AccountSource(account())},
        entries: {uuid(9): entry()},
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 1'), contains(uuid(9))),
          ),
        ),
      );
    });

    test('a category filed under someone else\'s id is caught', () {
      final state = LedgerState(
        categories: {
          uuid(9): TransactionCategory(
            id: uuid(5),
            name: 'Rent',
            kind: CategoryKind.expense,
            colorHex: '#FF0000',
            includeInAnalysis: true,
            parentID: null,
            symbol: 'house',
          ),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 1'), contains(uuid(9))),
          ),
        ),
      );
    });
  });

  group('clause 4, entries resolve their holders', () {
    test('an entry naming a source absent from the table is caught', () {
      final state = LedgerState(entries: {entryID: entry()});

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 4'), contains(accountID)),
          ),
        ),
      );
    });

    test('a transfer naming a destination absent from the table is caught', () {
      final state = LedgerState(
        moneySources: {accountID: AccountSource(account())},
        entries: {
          entryID: entry(amount: Decimal.fromInt(50), destinationID: uuid(9)),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 4'), contains(uuid(9))),
          ),
        ),
      );
    });
  });

  group('clause 6, entry and category kinds cohere', () {
    final categoryID = uuid(5);

    TransactionCategory expenseCategory() => TransactionCategory(
      id: categoryID,
      name: 'Rent',
      kind: CategoryKind.expense,
      colorHex: '#FF0000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'house',
    );

    // A transfer has no expected kind at all, so any category it names is
    // incoherent regardless of that category's own kind.
    test('a seeded transfer carrying a category is caught', () {
      final state = LedgerState(
        moneySources: {
          accountID: AccountSource(account()),
          uuid(6): AccountSource(
            Account(id: uuid(6), name: 'Savings', type: AccountType.savings),
          ),
        },
        categories: {categoryID: expenseCategory()},
        entries: {
          entryID: entry(
            amount: Decimal.fromInt(50),
            destinationID: uuid(6),
            categoryID: categoryID,
          ),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 6'), contains('carries a category')),
          ),
        ),
      );
    });

    test('a seeded income entry under an expense category is caught', () {
      final state = LedgerState(
        moneySources: {accountID: AccountSource(account())},
        categories: {categoryID: expenseCategory()},
        entries: {
          entryID: entry(amount: Decimal.fromInt(50), categoryID: categoryID),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 6'), contains('kind differs')),
          ),
        ),
      );
    });
  });

  group('clause 13, statement day', () {
    Account card({int? statementDay}) => Account(
      id: accountID,
      name: 'Visa',
      type: AccountType.card,
      statementDay: statementDay,
    );

    test('a seeded card beyond the 28th is caught', () {
      final state = LedgerState(
        moneySources: {accountID: AccountSource(card(statementDay: 31))},
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('invariant 13'), contains('31')),
          ),
        ),
      );
    });

    test('a seeded non-card carrying a statement day is caught', () {
      final state = LedgerState(
        moneySources: {
          accountID: AccountSource(
            Account(
              id: accountID,
              name: 'Savings',
              type: AccountType.savings,
              statementDay: 15,
            ),
          ),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('invariant 13'),
          ),
        ),
      );
    });

    test('a card inside the range and a bare non-card are legal', () {
      final state = LedgerState(
        moneySources: {accountID: AccountSource(card(statementDay: 28))},
      );

      expect(state.assertInvariants, returnsNormally);
    });
  });

  group('clause 12, lifecycle monotonicity', () {
    TransactionCategory category({
      LifecycleState lifecycle = LifecycleState.active,
    }) => TransactionCategory(
      id: uuid(5),
      name: 'Rent',
      kind: CategoryKind.expense,
      colorHex: '#FF0000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'house',
      lifecycle: lifecycle,
    );

    // Drives an account to referenceOnly, since purging a row that entries
    // still name keeps it as a reference rather than deleting it.
    LedgerState stateWithReferenceOnlyAccount() {
      final state = LedgerState();
      state.addAccount(account());
      state.addEntry(entry());
      state.deleteAccount(accountID);
      state.purgeAccount(accountID);
      return state;
    }

    test('purging a referenced account leaves it referenceOnly', () {
      final state = stateWithReferenceOnlyAccount();

      expect(
        state.moneySources[accountID]!.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('updateAccount may not resurrect a referenceOnly account', () {
      final state = stateWithReferenceOnlyAccount();

      // The edit carries the default `active`, but the stored lifecycle wins.
      state.updateAccount(account(lifecycle: LifecycleState.active));

      expect(
        state.moneySources[accountID]!.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('updateAccount still applies the rest of an edit to a kept row', () {
      final state = stateWithReferenceOnlyAccount();

      state.updateAccount(
        Account(id: accountID, name: 'Renamed', type: AccountType.cash),
      );

      expect(state.moneySources[accountID]!.asAccount!.name, 'Renamed');
    });

    test('an edit may not write the persistence-only tombstoned state', () {
      final state = LedgerState();
      state.addAccount(account());

      state.updateAccount(account(lifecycle: LifecycleState.tombstoned));

      expect(state.moneySources[accountID]!.lifecycle, LifecycleState.active);
    });

    test('an edit cannot move an active, unreferenced account to '
        'referenceOnly', () {
      final state = LedgerState();
      state.addAccount(account());

      state.updateAccount(account(lifecycle: LifecycleState.referenceOnly));

      expect(state.moneySources[accountID]!.lifecycle, LifecycleState.active);
    });

    test('an edit cannot move an active pocket to referenceOnly', () {
      final state = LedgerState();
      state.addAccount(account());
      state.addPocket(SubPocket(id: pocketID, name: 'Bills'), accountID);

      state.updatePocket(
        SubPocket(
          id: pocketID,
          name: 'Bills',
          lifecycle: LifecycleState.referenceOnly,
        ),
      );

      expect(state.moneySources[pocketID]!.lifecycle, LifecycleState.active);
    });

    test('an edit cannot move an active category to referenceOnly', () {
      final state = LedgerState();
      state.addCategory(category());

      state.updateCategory(category(lifecycle: LifecycleState.referenceOnly));

      expect(state.categories[uuid(5)]!.lifecycle, LifecycleState.active);
    });

    test('an edit cannot archive an active account', () {
      final state = LedgerState();
      state.addAccount(account());

      state.updateAccount(account(lifecycle: LifecycleState.archived));

      expect(state.moneySources[accountID]!.lifecycle, LifecycleState.active);
    });

    test('updateCategory may not resurrect a referenceOnly category', () {
      final state = LedgerState();
      state.addAccount(account());
      state.addCategory(category());
      state.addEntry(
        Entry(
          id: entryID,
          date: DateTime.utc(2026),
          amount: Decimal.fromInt(-10),
          name: 'e',
          sourceID: accountID,
          categoryID: uuid(5),
        ),
      );
      state.deleteCategory(uuid(5));
      state.purgeCategory(uuid(5));

      expect(
        state.categories[uuid(5)]!.lifecycle,
        LifecycleState.referenceOnly,
      );

      state.updateCategory(category(lifecycle: LifecycleState.active));

      expect(
        state.categories[uuid(5)]!.lifecycle,
        LifecycleState.referenceOnly,
      );
    });

    test('restoreAccount may still bring an archived account back', () {
      final state = LedgerState();
      state.addAccount(account());
      state.deleteAccount(accountID);

      expect(() => state.restoreAccount(accountID), returnsNormally);
      expect(state.moneySources[accountID]!.lifecycle, LifecycleState.active);
    });

    test('restoreCategory may still bring an archived category back', () {
      final state = LedgerState();
      state.addCategory(category());
      state.deleteCategory(uuid(5));

      expect(() => state.restoreCategory(uuid(5)), returnsNormally);
      expect(state.categories[uuid(5)]!.lifecycle, LifecycleState.active);
    });

    test('a freshly added row is not treated as a transition', () {
      final state = LedgerState();
      state.addAccount(account());

      expect(() => state.addCategory(category()), returnsNormally);
    });
  });
}
