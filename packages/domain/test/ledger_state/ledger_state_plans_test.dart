import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  String uuid(int n) =>
      '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

  final accountID = uuid(1);
  final otherAccountID = uuid(2);
  final pocketID = uuid(3);
  final expenseCategoryID = uuid(4);
  final incomeCategoryID = uuid(5);
  final planID = uuid(6);

  LedgerState seeded() {
    final state = LedgerState();
    state.addAccount(
      Account(id: accountID, name: 'Checking', type: AccountType.cash),
    );
    state.addAccount(
      Account(id: otherAccountID, name: 'Savings', type: AccountType.savings),
    );
    state.addPocket(SubPocket(id: pocketID, name: 'Bills'), accountID);
    state.addCategory(
      TransactionCategory(
        id: expenseCategoryID,
        name: 'Rent',
        kind: CategoryKind.expense,
        colorHex: '#888888',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'tag',
      ),
    );
    state.addCategory(
      TransactionCategory(
        id: incomeCategoryID,
        name: 'Salary',
        kind: CategoryKind.income,
        colorHex: '#888888',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'tag',
      ),
    );
    return state;
  }

  EntryTemplate template({
    Decimal? amount,
    String? sourceID,
    String? destinationID,
    String? categoryID,
  }) => EntryTemplate(
    amount: amount ?? Decimal.fromInt(-25),
    name: 'rent',
    sourceID: sourceID ?? accountID,
    destinationID: destinationID,
    categoryID: categoryID,
  );

  RecurringPlan plan({
    String? id,
    EntryTemplate? entryTemplate,
    DateTime? endDate,
    DateTime? lastResolvedDate,
  }) => RecurringPlan(
    id: id ?? planID,
    template: entryTemplate ?? template(),
    frequency: RecurrenceFrequency.monthly,
    anchor: DateTime.utc(2026, 1, 15),
    endDate: endDate,
    lastResolvedDate: lastResolvedDate ?? DateTime.utc(2026, 1, 15),
  );

  group('addPlan validation', () {
    test('rejects a duplicate id', () {
      final state = seeded();
      state.addPlan(plan());

      expect(() => state.addPlan(plan()), throwsA(IdCollision(planID)));
      expect(state.plans, hasLength(1));
    });

    test('an unknown source throws unknownHolder', () {
      final state = seeded();

      expect(
        () => state.addPlan(plan(entryTemplate: template(sourceID: uuid(9)))),
        throwsA(UnknownHolder(uuid(9))),
      );
      expect(state.plans, isEmpty);
    });

    test('an archived source throws inactiveReference', () {
      final state = seeded();
      state.deleteAccount(accountID);

      expect(
        () => state.addPlan(plan()),
        throwsA(InactiveReference(accountID)),
      );
      expect(state.plans, isEmpty);
    });

    test('an unknown destination throws unknownHolder', () {
      final state = seeded();

      expect(
        () => state.addPlan(
          plan(
            entryTemplate: template(
              amount: Decimal.fromInt(25),
              destinationID: uuid(9),
            ),
          ),
        ),
        throwsA(UnknownHolder(uuid(9))),
      );
      expect(state.plans, isEmpty);
    });

    test('an archived destination throws inactiveReference', () {
      final state = seeded();
      state.deleteAccount(otherAccountID);

      expect(
        () => state.addPlan(
          plan(
            entryTemplate: template(
              amount: Decimal.fromInt(25),
              destinationID: otherAccountID,
            ),
          ),
        ),
        throwsA(InactiveReference(otherAccountID)),
      );
      expect(state.plans, isEmpty);
    });

    test('an unknown category throws unknownCategory', () {
      final state = seeded();

      expect(
        () => state.addPlan(plan(entryTemplate: template(categoryID: uuid(9)))),
        throwsA(UnknownCategory(uuid(9))),
      );
      expect(state.plans, isEmpty);
    });

    test('an archived category throws inactiveReference', () {
      final state = seeded();
      state.deleteCategory(expenseCategoryID);

      expect(
        () => state.addPlan(
          plan(entryTemplate: template(categoryID: expenseCategoryID)),
        ),
        throwsA(InactiveReference(expenseCategoryID)),
      );
      expect(state.plans, isEmpty);
    });

    test('an expense naming an income category is a kind mismatch', () {
      final state = seeded();

      expect(
        () => state.addPlan(
          plan(entryTemplate: template(categoryID: incomeCategoryID)),
        ),
        throwsA(const CategoryKindMismatch()),
      );
      expect(state.plans, isEmpty);
    });

    test('a categorised transfer is a kind mismatch', () {
      final state = seeded();

      expect(
        () => state.addPlan(
          plan(
            entryTemplate: template(
              amount: Decimal.fromInt(25),
              destinationID: otherAccountID,
              categoryID: expenseCategoryID,
            ),
          ),
        ),
        throwsA(const CategoryKindMismatch()),
      );
      expect(state.plans, isEmpty);
    });

    test('a plan already past its end date throws exhaustedPlan', () {
      final state = seeded();

      expect(
        () => state.addPlan(
          plan(
            endDate: DateTime.utc(2026, 3, 15),
            lastResolvedDate: DateTime.utc(2026, 3, 15),
          ),
        ),
        throwsA(ExhaustedPlan(planID)),
      );
      expect(state.plans, isEmpty);
    });

    test('an end date before the anchor throws exhaustedPlan', () {
      final state = seeded();

      expect(
        () => state.addPlan(
          RecurringPlan(
            id: planID,
            template: template(),
            frequency: RecurrenceFrequency.monthly,
            anchor: DateTime.utc(2026, 1, 15),
            endDate: DateTime.utc(2026, 1, 10),
            lastResolvedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
        throwsA(ExhaustedPlan(planID)),
      );
      expect(state.plans, isEmpty);
    });
  });

  group('updatePlan', () {
    test('overwrites the stored plan', () {
      final state = seeded();
      state.addPlan(plan());

      final revised = plan(
        entryTemplate: template(amount: Decimal.fromInt(-99)),
      );
      final changes = state.updatePlan(revised);

      expect(state.plans[planID], revised);
      expect(changes, [UpsertPlan(revised)]);
    });

    test('an unknown id throws unknownPlan', () {
      final state = seeded();

      expect(() => state.updatePlan(plan()), throwsA(UnknownPlan(planID)));
      expect(state.plans, isEmpty);
    });

    test('revalidates and leaves the stored plan untouched', () {
      final state = seeded();
      final stored = plan();
      state.addPlan(stored);

      expect(
        () =>
            state.updatePlan(plan(entryTemplate: template(sourceID: uuid(9)))),
        throwsA(UnknownHolder(uuid(9))),
      );
      expect(state.plans[planID], stored);
    });

    test('a plan with anchor shifted after resolution is rejected '
        'rather than re-minting occurrences under the new schedule', () {
      final state = seeded();
      final original = plan(lastResolvedDate: DateTime.utc(2026, 1, 15));
      state.addPlan(original);
      state.resolvePlans(DateTime.utc(2026, 3, 20));
      expect(state.entries, hasLength(2));

      final shifted = RecurringPlan(
        id: planID,
        template: template(),
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 20),
        lastResolvedDate: DateTime.utc(2026, 1, 15),
      );

      expect(
        () => state.updatePlan(shifted),
        throwsA(StaleResolutionCursor(planID)),
      );
      state.resolvePlans(DateTime.utc(2026, 3, 20));

      expect(state.entries, hasLength(2));
    });

    test('an anchor shift before any resolution has happened is accepted', () {
      final state = seeded();
      final original = plan(lastResolvedDate: DateTime.utc(2026, 1, 15));
      state.addPlan(original);

      final shifted = RecurringPlan(
        id: planID,
        template: template(),
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 20),
        lastResolvedDate: DateTime.utc(2026, 1, 20),
      );

      state.updatePlan(shifted);

      expect(state.plans[planID], shifted);
    });

    test('an anchor shift after resolution throws even when the incoming '
        'cursor is rewound to the new anchor', () {
      final state = seeded();
      final original = plan(lastResolvedDate: DateTime.utc(2026, 1, 15));
      state.addPlan(original);
      state.resolvePlans(DateTime.utc(2026, 3, 20));

      final shifted = RecurringPlan(
        id: planID,
        template: template(),
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 20),
        lastResolvedDate: DateTime.utc(2026, 3, 20),
      );

      expect(
        () => state.updatePlan(shifted),
        throwsA(StaleResolutionCursor(planID)),
      );
      expect(state.plans[planID], isNot(shifted));
    });
  });

  group('deletePlan', () {
    test('hard removes the plan rather than archiving it', () {
      final state = seeded();
      state.addPlan(plan());

      final changes = state.deletePlan(planID);

      expect(state.plans, isEmpty);
      expect(changes, [DeletePlan(planID)]);
    });

    test('a missing id is a no-op', () {
      final state = seeded();
      state.addPlan(plan());

      expect(state.deletePlan(uuid(9)), isEmpty);
      expect(state.plans, hasLength(1));
    });

    test('resolves an uppercase id', () {
      final state = seeded();
      state.addPlan(plan());

      final changes = state.deletePlan(planID.toUpperCase());

      expect(changes, [DeletePlan(planID)]);
      expect(state.plans, isEmpty);
    });
  });

  group('resolvePlans failures', () {
    LedgerState withFrozenPocket() {
      final state = seeded();
      state.addPlan(plan(entryTemplate: template(sourceID: pocketID)));
      state.deletePocket(pocketID);
      return state;
    }

    test('records a failure instead of materializing the entry', () {
      final state = withFrozenPocket();

      final result = state.resolvePlans(DateTime.utc(2026, 2, 20));

      expect(result.failures, hasLength(1));
      expect(state.entries, isEmpty);
    });

    test('the failure carries the plan id, occurrence and error', () {
      final state = withFrozenPocket();

      final failure = state
          .resolvePlans(DateTime.utc(2026, 2, 20))
          .failures
          .single;

      expect(failure.planID, planID);
      expect(failure.occurrence, DateTime.utc(2026, 2, 15));
      expect(failure.error, InactiveReference(pocketID));
    });

    test('a failing occurrence does not abort the remaining sweep', () {
      final state = withFrozenPocket();

      final result = state.resolvePlans(DateTime.utc(2026, 4, 20));

      expect(result.failures.map((failure) => failure.occurrence), [
        DateTime.utc(2026, 2, 15),
        DateTime.utc(2026, 3, 15),
        DateTime.utc(2026, 4, 15),
      ]);
      expect(state.plans[planID], isNotNull);
    });

    test('a healthy plan still materializes alongside a failing one', () {
      final state = withFrozenPocket();
      state.addPlan(plan(id: uuid(7)));

      final result = state.resolvePlans(DateTime.utc(2026, 2, 20));

      expect(result.failures.single.planID, planID);
      expect(state.entries.keys, [
        OccurrenceID.make(uuid(7), DateTime.utc(2026, 2, 15)),
      ]);
    });

    test('a failed occurrence is regenerated once the holder is restored '
        'instead of being permanently skipped', () {
      final state = withFrozenPocket();

      final firstSweep = state.resolvePlans(DateTime.utc(2026, 3, 20));
      expect(firstSweep.failures.map((failure) => failure.occurrence), [
        DateTime.utc(2026, 2, 15),
        DateTime.utc(2026, 3, 15),
      ]);
      expect(state.entries, isEmpty);

      state.restorePocket(pocketID);
      final secondSweep = state.resolvePlans(DateTime.utc(2026, 3, 20));

      expect(secondSweep.failures, isEmpty);
      expect(state.entries.keys, [
        OccurrenceID.make(planID, DateTime.utc(2026, 2, 15)),
        OccurrenceID.make(planID, DateTime.utc(2026, 3, 15)),
      ]);
    });

    test('a plan with only successful occurrences advances its cursor all the '
        'way to now, not just to the last occurrence date', () {
      final state = seeded();
      state.addPlan(plan());

      state.resolvePlans(DateTime.utc(2026, 3, 20));

      expect(state.plans[planID]!.lastResolvedDate, DateTime.utc(2026, 3, 20));

      final secondSweep = state.resolvePlans(DateTime.utc(2026, 3, 20));
      expect(secondSweep.changes, isEmpty);
      expect(secondSweep.failures, isEmpty);
    });
  });

  group('deleteAccount plan cascade', () {
    test('removes a plan whose template names the account', () {
      final state = seeded();
      state.addPlan(plan());

      final changes = state.deleteAccount(accountID);

      expect(state.plans, isEmpty);
      expect(changes, contains(DeletePlan(planID)));
    });

    test('removes a plan whose template names one of its pockets', () {
      final state = seeded();
      state.addPlan(plan(entryTemplate: template(sourceID: pocketID)));

      final changes = state.deleteAccount(accountID);

      expect(state.plans, isEmpty);
      expect(changes, contains(DeletePlan(planID)));
    });

    test('leaves a plan naming an unrelated account alone', () {
      final state = seeded();
      final survivor = plan(entryTemplate: template(sourceID: otherAccountID));
      state.addPlan(survivor);

      final changes = state.deleteAccount(accountID);

      expect(state.plans[planID], survivor);
      expect(changes.whereType<DeletePlan>(), isEmpty);
    });

    test('archives the holders and drops the plan without deleting rows', () {
      final state = seeded();
      state.addPlan(plan());

      final changes = state.deleteAccount(accountID);

      final archivedAccount = state.moneySources[accountID]!.asAccount!;
      final archivedPocket = state.moneySources[pocketID]!.asPocket!;
      expect(
        changes,
        containsAllInOrder([
          UpsertAccount(archivedAccount),
          DeletePlan(planID),
        ]),
      );
      expect(changes, contains(UpsertPocket(archivedPocket)));
      expect(changes.whereType<DeleteMoneySource>(), isEmpty);
      expect(archivedAccount.lifecycle, LifecycleState.archived);
      expect(archivedPocket.lifecycle, LifecycleState.archived);
    });
  });

  group('the dereference sweep drops plans naming the row it removes', () {
    final entryID = uuid(7);

    LedgerState seededWith({
      required MoneySource pocket,
      required Entry entry,
      required RecurringPlan storedPlan,
      TransactionCategory? category,
    }) => LedgerState(
      moneySources: {
        accountID: AccountSource(
          Account(
            id: accountID,
            name: 'Checking',
            type: AccountType.cash,
            subPocketIDs: {pocketID},
          ),
        ),
        pocketID: pocket,
      },
      entries: {entry.id: entry},
      categories: {?category?.id: ?category},
      plans: {storedPlan.id: storedPlan},
    );

    test('deleting the last entry removes a plan naming the pocket', () {
      final state = seededWith(
        pocket: PocketSource(
          SubPocket(
            id: pocketID,
            name: 'Bills',
            lifecycle: LifecycleState.referenceOnly,
          ),
        ),
        entry: Entry(
          id: entryID,
          amount: Decimal.fromInt(-10),
          name: 'e',
          sourceID: pocketID,
        ),
        storedPlan: plan(entryTemplate: template(sourceID: pocketID)),
      );

      final changes = state.deleteEntry(entryID);

      expect(state.moneySources.containsKey(pocketID), isFalse);
      expect(state.plans, isEmpty);
      expect(changes, contains(DeletePlan(planID)));
    });

    test('deleting the last entry removes a plan naming the category', () {
      final category = TransactionCategory(
        id: expenseCategoryID,
        name: 'Rent',
        kind: CategoryKind.expense,
        colorHex: '#888888',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'tag',
        lifecycle: LifecycleState.referenceOnly,
      );
      final state = seededWith(
        pocket: PocketSource(SubPocket(id: pocketID, name: 'Bills')),
        entry: Entry(
          id: entryID,
          amount: Decimal.fromInt(-10),
          name: 'e',
          sourceID: accountID,
          categoryID: expenseCategoryID,
        ),
        storedPlan: plan(
          entryTemplate: template(categoryID: expenseCategoryID),
        ),
        category: category,
      );

      final changes = state.deleteEntry(entryID);

      expect(state.categories.containsKey(expenseCategoryID), isFalse);
      expect(state.plans, isEmpty);
      expect(changes, contains(DeletePlan(planID)));
    });
  });
}
