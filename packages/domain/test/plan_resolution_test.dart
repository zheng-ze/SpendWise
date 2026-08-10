import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const accountID = '00000000-0000-4000-8000-000000000001';
  const planID = '00000000-0000-4000-8000-0000000000a1';

  LedgerChange change() => UpsertEntry(
    Entry(
      id: '00000000-0000-4000-8000-0000000000b1',
      date: DateTime.utc(2026, 2, 15),
      amount: Decimal.fromInt(-25),
      name: 'rent',
      sourceID: accountID,
    ),
  );

  PlanFailure failure() => PlanFailure(
    planID: planID,
    occurrence: DateTime.utc(2026, 3, 15),
    error: const UnknownAccount(accountID),
  );

  test('equal field values compare equal and hash equal', () {
    final a = PlanResolution(changes: [change()], failures: [failure()]);
    final b = PlanResolution(changes: [change()], failures: [failure()]);

    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('differing changes compare unequal', () {
    final a = PlanResolution(changes: [change()], failures: const []);
    final b = PlanResolution(changes: const [], failures: const []);

    expect(a, isNot(equals(b)));
  });

  test('differing failures compare unequal', () {
    final a = PlanResolution(changes: const [], failures: [failure()]);
    final b = PlanResolution(changes: const [], failures: const []);

    expect(a, isNot(equals(b)));
  });

  test('separately built equal values collapse to one Set entry', () {
    final a = PlanResolution(changes: [change()], failures: [failure()]);
    final b = PlanResolution(changes: [change()], failures: [failure()]);

    expect({a, b}, hasLength(1));
    expect({a: 1}..[b] = 2, {a: 2});
  });
}
