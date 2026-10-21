import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
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
