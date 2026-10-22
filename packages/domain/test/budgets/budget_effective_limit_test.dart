import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test(
    'LimitEvent equality preserves its effective month, amount and kind',
    () {
      final event = LimitEvent(
        effectiveFromMonth: YearMonth(2026, 6),
        value: Decimal.fromInt(200),
        kind: LimitEventKind.override,
      );
      final equalEvent = LimitEvent(
        effectiveFromMonth: YearMonth(2026, 6),
        value: Decimal.fromInt(200),
        kind: LimitEventKind.override,
      );
      final otherKind = LimitEvent(
        effectiveFromMonth: YearMonth(2026, 6),
        value: Decimal.fromInt(200),
        kind: LimitEventKind.defaultLimit,
      );

      expect(event, equalEvent);
      expect(event.hashCode, equalEvent.hashCode);
      expect(event, isNot(otherKind));
      expect(event.toString(), 'LimitEvent(override, YearMonth(2026-6), 200)');
    },
  );

  test('LimitEvent codes decode known kinds and reject unknown codes', () {
    expect(LimitEventKind.defaultLimit.code, 0);
    expect(LimitEventKind.override.code, 1);
    expect(LimitEventKind.fromCode(0), LimitEventKind.defaultLimit);
    expect(LimitEventKind.fromCode(1), LimitEventKind.override);
    expect(() => LimitEventKind.fromCode(-1), throwsArgumentError);
  });

  test('Budget identifies its id and category in its string form', () {
    final budget = Budget(
      id: 'abcdefab-0000-4000-8000-000000000001',
      categoryID: 'abcdefab-0000-4000-8000-000000000002',
      limitEvents: [_defaultEvent(null, 100)],
      createdAtMonth: const YearMonth(2026, 1),
    );

    expect(
      budget.toString(),
      'Budget(abcdefab-0000-4000-8000-000000000001, '
      'abcdefab-0000-4000-8000-000000000002)',
    );
  });

  test('defaultOnlyTimelineResolvesEveryMonthToTheSingleEvent', () {
    final budget = _budgetWith([_defaultEvent(null, 100)]);

    expect(effectiveLimit(budget, const YearMonth(2026, 1)), _d(100));
    expect(effectiveLimit(budget, const YearMonth(2030, 6)), _d(100));
  });

  test('defaultChangeTakesEffectOnlyFromItsMonthForward', () {
    final budget = _budgetWith([
      _defaultEvent(null, 100),
      _defaultEvent(const YearMonth(2026, 6), 200),
    ]);

    expect(effectiveLimit(budget, const YearMonth(2026, 5)), _d(100));
    expect(effectiveLimit(budget, const YearMonth(2026, 6)), _d(200));
    expect(effectiveLimit(budget, const YearMonth(2026, 7)), _d(200));
  });

  test('overridePinsOneMonthWhileSurroundingMonthsKeepTheDefault', () {
    final budget = _budgetWith([
      _defaultEvent(null, 100),
      _overrideEvent(const YearMonth(2026, 6), 999),
    ]);

    expect(effectiveLimit(budget, const YearMonth(2026, 5)), _d(100));
    expect(effectiveLimit(budget, const YearMonth(2026, 6)), _d(999));
    expect(effectiveLimit(budget, const YearMonth(2026, 7)), _d(100));
  });

  test('laterDefaultChangeDoesNotDisturbAnOverriddenMonth', () {
    final budget = _budgetWith([
      _defaultEvent(null, 100),
      _overrideEvent(const YearMonth(2026, 6), 999),
      _defaultEvent(const YearMonth(2026, 1), 150),
    ]);

    expect(effectiveLimit(budget, const YearMonth(2026, 6)), _d(999));
    expect(effectiveLimit(budget, const YearMonth(2026, 7)), _d(150));
  });

  test('twoOverridesOnTheSameMonthTheLastAppendedWins', () {
    final budget = _budgetWith([
      _defaultEvent(null, 100),
      _overrideEvent(const YearMonth(2026, 6), 500),
      _overrideEvent(const YearMonth(2026, 6), 700),
    ]);

    expect(effectiveLimit(budget, const YearMonth(2026, 6)), _d(700));
  });

  test('twoDefaultChangesOnTheSameMonthTheLastAppendedWins', () {
    final budget = _budgetWith([
      _defaultEvent(null, 100),
      _defaultEvent(const YearMonth(2026, 6), 200),
      _defaultEvent(const YearMonth(2026, 6), 300),
    ]);

    expect(effectiveLimit(budget, const YearMonth(2026, 6)), _d(300));
  });

  test('monthBeforeEveryEventFallsBackToTheUnboundedPastFirstEvent', () {
    final budget = _budgetWith([
      _defaultEvent(null, 100),
      _defaultEvent(const YearMonth(2026, 6), 200),
    ]);

    expect(effectiveLimit(budget, const YearMonth(2000, 1)), _d(100));
  });

  test('monthBeforeEveryDefaultEventThrowsInsteadOfCrashingOnNull', () {
    final budget = _budgetWith([_defaultEvent(const YearMonth(2026, 6), 100)]);

    expect(
      () => effectiveLimit(budget, const YearMonth(2026, 1)),
      throwsA(isA<StateError>()),
    );
  });
}

Budget _budgetWith(List<LimitEvent> events) => Budget(
  categoryID: null,
  limitEvents: events,
  createdAtMonth: const YearMonth(2026, 1),
);

LimitEvent _defaultEvent(YearMonth? from, int value) => LimitEvent(
  effectiveFromMonth: from,
  value: _d(value),
  kind: LimitEventKind.defaultLimit,
);

LimitEvent _overrideEvent(YearMonth month, int value) => LimitEvent(
  effectiveFromMonth: month,
  value: _d(value),
  kind: LimitEventKind.override,
);

Decimal _d(int value) => Decimal.fromInt(value);
