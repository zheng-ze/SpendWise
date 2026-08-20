import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  String uuid(int n) =>
      '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

  final budgetID = uuid(1);

  test('a budget referencing an unknown category is caught', () {
    final state = LedgerState(
      budgets: {
        budgetID: Budget(
          id: budgetID,
          categoryID: uuid(9),
          limitEvents: [
            LimitEvent(
              effectiveFromMonth: null,
              value: Decimal.fromInt(100),
              kind: LimitEventKind.defaultLimit,
            ),
          ],
          rolloverMode: RolloverMode.none,
          carryCap: null,
          createdAtMonth: const YearMonth(2026, 1),
        ),
      },
    );

    expect(
      state.assertInvariants,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('invariant 16'),
        ),
      ),
    );
  });

  test(
    'a budget with a non-null effectiveFromMonth on its first event is caught',
    () {
      final state = LedgerState(
        budgets: {
          budgetID: Budget(
            id: budgetID,
            categoryID: null,
            limitEvents: [
              LimitEvent(
                effectiveFromMonth: const YearMonth(2026, 1),
                value: Decimal.fromInt(100),
                kind: LimitEventKind.defaultLimit,
              ),
            ],
            rolloverMode: RolloverMode.none,
            carryCap: null,
            createdAtMonth: const YearMonth(2026, 1),
          ),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('invariant 17'),
          ),
        ),
      );
    },
  );

  test('a budget with a later event carrying a null month is caught', () {
    final state = LedgerState(
      budgets: {
        budgetID: Budget(
          id: budgetID,
          categoryID: null,
          limitEvents: [
            LimitEvent(
              effectiveFromMonth: null,
              value: Decimal.fromInt(100),
              kind: LimitEventKind.defaultLimit,
            ),
            LimitEvent(
              effectiveFromMonth: null,
              value: Decimal.fromInt(200),
              kind: LimitEventKind.defaultLimit,
            ),
          ],
          rolloverMode: RolloverMode.none,
          carryCap: null,
          createdAtMonth: const YearMonth(2026, 1),
        ),
      },
    );

    expect(
      state.assertInvariants,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('invariant 17'),
        ),
      ),
    );
  });
}
