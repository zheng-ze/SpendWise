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

  Entry entry({String? sourceID}) => Entry(
    id: entryID,
    date: DateTime.utc(2026),
    amount: Decimal.fromInt(-10),
    name: 'e',
    sourceID: sourceID ?? accountID,
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
}
