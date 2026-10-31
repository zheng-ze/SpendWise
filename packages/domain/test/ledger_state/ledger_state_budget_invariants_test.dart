import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  String uuid(int n) =>
      '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

  final budgetID = uuid(1);

  LedgerState stateWith(Budget budget) =>
      LedgerState(budgets: {budget.id: budget});

  Matcher violationOf(int clause) => throwsA(
    isA<StateError>().having(
      (error) => error.message,
      'message',
      contains('invariant $clause'),
    ),
  );

  test('a budget with a zero limit violates invariant 17', () {
    final state = stateWith(
      Budget(id: budgetID, categoryID: null, limit: Decimal.zero),
    );

    expect(
      state.assertInvariants,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('invariant 17'),
            contains('budget $budgetID has a nonpositive limit'),
          ),
        ),
      ),
    );
  });

  test('a budget with a negative limit violates invariant 17', () {
    final state = stateWith(
      Budget(id: budgetID, categoryID: null, limit: Decimal.fromInt(-1)),
    );

    expect(state.assertInvariants, violationOf(17));
  });

  test('a budget with a positive limit passes', () {
    final state = stateWith(
      Budget(id: budgetID, categoryID: null, limit: Decimal.parse('0.01')),
    );

    expect(state.assertInvariants, returnsNormally);
  });

  test('a budget referencing an unknown category is caught', () {
    final state = stateWith(
      Budget(id: budgetID, categoryID: uuid(9), limit: Decimal.fromInt(100)),
    );

    expect(state.assertInvariants, violationOf(16));
  });
}
