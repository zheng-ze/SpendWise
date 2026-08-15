import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/seed_data.dart';

List<T> _rowsOf<T extends LedgerChange>(List<LedgerChange> changes) =>
    changes.whereType<T>().toList();

int _firstIndexOf<T extends LedgerChange>(List<LedgerChange> changes) =>
    changes.indexWhere((change) => change is T);

int _lastIndexOf<T extends LedgerChange>(List<LedgerChange> changes) =>
    changes.lastIndexWhere((change) => change is T);

void main() {
  test('seedChangesProducesTheWholeSampleDataset', () {
    final changes = seedChanges();

    expect(_rowsOf<UpsertAccount>(changes), hasLength(3));
    expect(_rowsOf<UpsertPocket>(changes), hasLength(2));
    expect(_rowsOf<UpsertCategory>(changes), hasLength(6));
    expect(_rowsOf<UpsertPlan>(changes), hasLength(2));
    expect(changes, hasLength(3 + 2 + 6 + 15 + 4 + 2));
  });

  test('seedChangesEmitsFifteenEntriesPlusFourOpeningBalances', () {
    final entries = _rowsOf<UpsertEntry>(
      seedChanges(),
    ).map((change) => change.entry).toList();

    expect(entries, hasLength(19));
    expect(
      entries.where((entry) => entry.name == 'Opening balance'),
      hasLength(4),
    );
  });

  test('seedChangesOrdersMoneySourcesCategoriesEntriesThenPlans', () {
    final changes = seedChanges();

    final lastSource = [
      _lastIndexOf<UpsertAccount>(changes),
      _lastIndexOf<UpsertPocket>(changes),
    ].reduce((a, b) => a > b ? a : b);

    expect(lastSource, lessThan(_firstIndexOf<UpsertCategory>(changes)));
    expect(
      _lastIndexOf<UpsertCategory>(changes),
      lessThan(_firstIndexOf<UpsertEntry>(changes)),
    );
    expect(
      _lastIndexOf<UpsertEntry>(changes),
      lessThan(_firstIndexOf<UpsertPlan>(changes)),
    );
  });

  test('seedChangesCarriesTheAccountsAndPocketsFromTheSpec', () {
    final changes = seedChanges();
    final accounts = _rowsOf<UpsertAccount>(
      changes,
    ).map((change) => change.account);
    final pockets = _rowsOf<UpsertPocket>(
      changes,
    ).map((change) => change.pocket);

    final card = accounts.singleWhere((account) => account.name == 'Amex Card');
    final savings = accounts.singleWhere(
      (account) => account.name == 'OCBC Savings',
    );

    expect(
      accounts.singleWhere((account) => account.name == 'DBS Checking').type,
      AccountType.checking,
    );
    expect(savings.type, AccountType.savings);
    expect(card.type, AccountType.card);
    expect(card.statementDay, 15);
    expect(
      pockets.map((pocket) => pocket.name),
      containsAll(<String>['Emergency Fund', 'Holiday']),
    );
    expect(savings.subPocketIDs, hasLength(2));
  });

  test('seedChangesCarriesTheCategoryTreeFromTheSpec', () {
    final categories = _rowsOf<UpsertCategory>(
      seedChanges(),
    ).map((change) => change.category).toList();

    final byName = {for (final category in categories) category.name: category};

    expect(byName['Groceries']!.kind, CategoryKind.expense);
    expect(byName['Groceries']!.colorHex, '#34C759');
    expect(byName['Groceries']!.symbol, 'shopping_cart');
    expect(byName['Groceries']!.parentID, isNull);
    expect(byName['Dining']!.colorHex, '#FF9500');
    expect(byName['Dining']!.symbol, 'restaurant');
    expect(byName['Transport']!.colorHex, '#5856D6');
    expect(byName['Transport']!.symbol, 'tram');
    expect(byName['Salary']!.kind, CategoryKind.income);
    expect(byName['Salary']!.colorHex, '#007AFF');
    expect(byName['Salary']!.symbol, 'attach_money');
    expect(byName['Supermarket']!.parentID, byName['Groceries']!.id);
    expect(byName['Supermarket']!.colorHex, '#30D158');
    expect(byName['Supermarket']!.symbol, 'shopping_bag');
    expect(byName['Fresh Market']!.parentID, byName['Groceries']!.id);
    expect(byName['Fresh Market']!.colorHex, '#63E6BE');
    expect(byName['Fresh Market']!.symbol, 'eco');
  });

  test('seedChangesCoversTheDeliberateEdgeCases', () {
    final changes = seedChanges();
    final entries = _rowsOf<UpsertEntry>(
      changes,
    ).map((change) => change.entry).toList();
    final categoryIDs = _rowsOf<UpsertCategory>(
      changes,
    ).map((change) => change.category.id).toSet();

    final transfer = entries.singleWhere((entry) => entry.name == 'To savings');
    final rent = entries.singleWhere((entry) => entry.name == 'Rent');
    final subcategoryNames = entries
        .where(
          (entry) =>
              entry.name == 'FairPrice groceries' ||
              entry.name == 'Tekka wet market',
        )
        .map((entry) => entry.categoryID);

    expect(transfer.destinationID, isNotNull);
    expect(transfer.categoryID, isNull);
    expect(transfer.amount, Decimal.fromInt(500));
    expect(rent.categoryID, isNull);
    expect(rent.amount, Decimal.fromInt(-1200));
    expect(subcategoryNames, everyElement(isIn(categoryIDs)));
  });

  test('seedChangesSpreadsEntriesAcrossPreviousCurrentAndNextMonth', () {
    final today = DateTime.utc(2026, 8, 12);
    final entries = _rowsOf<UpsertEntry>(seedChanges(today: today))
        .map((change) => change.entry)
        .where((entry) => entry.name != 'Opening balance');

    final months = entries.map((entry) => (entry.date.year, entry.date.month));

    expect(months, contains((2026, 7)));
    expect(months, contains((2026, 8)));
    expect(months, contains((2026, 9)));
  });

  test('everySeedDateIsUtcMidnight', () {
    for (final today in <DateTime>[
      DateTime.utc(2026, 1, 31),
      DateTime.utc(2026, 3, 31),
      DateTime.utc(2026, 8, 12),
      DateTime.utc(2028, 2, 29),
    ]) {
      final dates = <DateTime>[
        for (final change in seedChanges(today: today))
          if (change is UpsertEntry) change.entry.date,
        for (final change in seedChanges(today: today))
          if (change is UpsertPlan) ...[
            change.plan.anchor,
            change.plan.lastResolvedDate,
          ],
      ];

      expect(dates, isNotEmpty);
      for (final date in dates) {
        expect(date.isUtc, isTrue, reason: '$date from today=$today');
        expect(date, DateTime.utc(date.year, date.month, date.day));
      }
    }
  });

  // every day the dataset asks for fits in all twelve months, so the clamp
  // path is never exercised here.
  test('seedDatesLandOnTheRequestedDayOfTheShiftedMonth', () {
    final entries = _rowsOf<UpsertEntry>(
      seedChanges(today: DateTime.utc(2026, 3, 31)),
    ).map((change) => change.entry);

    final salary = entries.lastWhere(
      (entry) => entry.name == 'Monthly salary' && entry.date.month == 2,
    );

    expect(salary.date, DateTime.utc(2026, 2, 25));
    expect(
      entries.singleWhere((entry) => entry.name == 'Weekly groceries').date,
      DateTime.utc(2026, 2, 18),
    );
    expect(
      entries.singleWhere((entry) => entry.name == 'Rent').date,
      DateTime.utc(2026, 4, 3),
    );
  });

  test('openingBalancesAreDatedTwoMonthsBackOnTheFirst', () {
    final openings = _rowsOf<UpsertEntry>(
      seedChanges(today: DateTime.utc(2026, 3, 31)),
    ).map((change) => change.entry).where((e) => e.name == 'Opening balance');

    expect(openings, hasLength(4));
    expect(openings.map((entry) => entry.date).toSet(), <DateTime>{
      DateTime.utc(2026, 1, 1),
    });
    expect(openings.map((entry) => entry.amount).toSet(), <Decimal>{
      Decimal.fromInt(5000),
      Decimal.fromInt(1200),
      Decimal.fromInt(8000),
      Decimal.fromInt(650),
    });
  });

  test('plansDoNotBackfillOnFirstResolve', () {
    final today = DateTime.utc(2026, 3, 31);
    final plans = _rowsOf<UpsertPlan>(
      seedChanges(today: today),
    ).map((change) => change.plan).toList();

    expect(plans, hasLength(2));
    for (final plan in plans) {
      expect(plan.frequency, RecurrenceFrequency.monthly);
      expect(plan.lastResolvedDate, plan.anchor);
      expect(
        plan.occurrences(after: plan.lastResolvedDate, upTo: today),
        isEmpty,
      );
    }

    final netflix = plans.singleWhere(
      (plan) => plan.template.name == 'Netflix',
    );
    final salary = plans.singleWhere(
      (plan) => plan.template.name == 'Monthly salary',
    );

    expect(netflix.anchor, DateTime.utc(2026, 3, 20));
    expect(netflix.template.amount, Decimal.parse('-19.98'));
    expect(salary.anchor, DateTime.utc(2026, 3, 25));
    expect(salary.template.amount, Decimal.fromInt(3200));
  });

  for (final (label, mintIndex) in const <(String, int)>[
    ('account', 1),
    ('pocket', 3),
    ('category', 6),
    ('entry', 12),
    ('plan', 26),
  ]) {
    test('aRejected${label}ThrowsRatherThanThinningTheSeed', () {
      final ids = _CollidingIds(collideAt: mintIndex);

      expect(
        () => buildSeed(LedgerState(), today: _fixedToday, newID: ids.next),
        throwsA(isA<IdCollision>()),
        reason: 'the $label step swallowed its rejection',
      );
    });
  }

  test('theCollidingIdFactoryReachesEachRowTypeInTurn', () {
    // Guards the indices above: if the seed order shifts, the cases must move.
    final probe = _CollidingIds(collideAt: 1000);
    final changes = buildSeed(
      LedgerState(),
      today: _fixedToday,
      newID: probe.next,
    );

    expect(changes, isNotEmpty);
    expect(probe.minted, greaterThan(26));
  });
}

final _fixedToday = DateTime.utc(2026, 8, 12);

class _CollidingIds {
  _CollidingIds({required this.collideAt});

  final int collideAt;
  int minted = 0;
  String _last = '';

  String next() {
    final index = minted++;
    if (index == collideAt + 1 && _last.isNotEmpty) return _last;
    _last =
        '00000000-0000-4000-8000-${index.toRadixString(16).padLeft(12, '0')}';
    return _last;
  }
}
