import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/mappers/mappers.dart';
import 'package:sync/sync.dart';

void main() {
  final version = VersionVector({'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa': 3});
  const accountID = 'a1b2c3d4-1111-4111-8111-aaaaaaaaaaaa';
  const pocketID = 'b1b2c3d4-2222-4222-8222-bbbbbbbbbbbb';
  const categoryID = 'c1b2c3d4-3333-4333-8333-cccccccccccc';
  const parentCategoryID = 'd1b2c3d4-4444-4444-8444-dddddddddddd';
  const entryID = 'e1b2c3d4-5555-4555-8555-eeeeeeeeeeee';
  const planID = 'f1b2c3d4-6666-4666-8666-ffffffffffff';
  const budgetID = 'a2b2c3d4-7777-4777-8777-aaaaaaaaaaab';

  group('account', () {
    test('accountRoundTrips', () {
      final account = Account(
        id: accountID,
        name: 'Everyday',
        type: AccountType.card,
        subPocketIDs: {'b1b2c3d4-2222-4222-8222-bbbbbbbbbbbb'},
        incomingTransfersAsExpenses: true,
        includeInNetWorth: false,
        statementDay: 12,
        lifecycle: LifecycleState.archived,
      );

      final row = accountToRow(account, version);
      expect(accountFromRow(row), account);
      expect(versionFromRow(row.versionData), version);
    });

    test('the account row stores the type code and the lifecycle code', () {
      final row = accountToRow(
        Account(
          id: accountID,
          name: 'Everyday',
          type: AccountType.insurance,
          lifecycle: LifecycleState.referenceOnly,
        ),
        version,
      );

      expect(row.type, 6);
      expect(row.lifecycle, 2);
    });
  });

  group('category', () {
    TransactionCategory makeCategory({
      String? parentID,
      CategoryKind kind = CategoryKind.expense,
      LifecycleState lifecycle = LifecycleState.active,
    }) => TransactionCategory(
      id: categoryID,
      name: 'Coffee',
      kind: kind,
      colorHex: '#FF8800',
      includeInAnalysis: true,
      parentID: parentID,
      symbol: 'local_cafe',
      lifecycle: lifecycle,
    );

    test('categoryRoundTrips', () {
      final category = makeCategory(
        parentID: parentCategoryID,
        kind: CategoryKind.income,
        lifecycle: LifecycleState.referenceOnly,
      );

      final row = categoryToRow(category, version);
      expect(categoryFromRow(row), category);
      expect(versionFromRow(row.versionData), version);
    });
  });

  group('entry', () {
    test('entryRoundTrips', () {
      final entry = Entry(
        id: entryID,
        date: DateTime.utc(2026, 3, 14),
        amount: Decimal.parse('-42.75'),
        name: 'Coffee',
        categoryID: categoryID,
        sourceID: accountID,
        includeInAnalysis: false,
        lifecycle: LifecycleState.archived,
      );

      final row = entryToRow(entry, version);
      expect(entryFromRow(row), entry);
      expect(versionFromRow(row.versionData), version);
    });

    test('systemKind round-trips for an opening balance entry', () {
      final entry = Entry(
        id: entryID,
        date: DateTime.utc(2026, 3, 14),
        amount: Decimal.parse('250'),
        name: 'Opening balance',
        sourceID: accountID,
        includeInAnalysis: false,
        systemKind: SystemEntryKind.openingBalance,
      );

      final row = entryToRow(entry, version);
      expect(row.systemKind, 0);
      expect(entryFromRow(row), entry);
      expect(entryFromRow(row).systemKind, SystemEntryKind.openingBalance);
    });

    test('systemKind round-trips for a balance adjustment entry', () {
      final entry = Entry(
        id: entryID,
        date: DateTime.utc(2026, 3, 14),
        amount: Decimal.parse('-10'),
        name: 'Balance adjustment',
        sourceID: accountID,
        includeInAnalysis: false,
        systemKind: SystemEntryKind.balanceAdjustment,
      );

      final row = entryToRow(entry, version);
      expect(row.systemKind, 1);
      expect(entryFromRow(row), entry);
      expect(entryFromRow(row).systemKind, SystemEntryKind.balanceAdjustment);
    });
  });

  group('plan', () {
    test('planRoundTrips', () {
      final plan = RecurringPlan(
        id: planID,
        template: EntryTemplate(
          amount: Decimal.parse('-15.50'),
          name: 'Gym',
          categoryID: categoryID,
          sourceID: accountID,
          includeInAnalysis: true,
        ),
        frequency: RecurrenceFrequency.quarterly,
        anchor: DateTime.utc(2026, 1, 5),
        endDate: DateTime.utc(2027, 1, 5),
        lastResolvedDate: DateTime.utc(2026, 4, 5),
      );

      final row = planToRow(plan, version);
      expect(planFromRow(row), plan);
      expect(versionFromRow(row.versionData), version);
    });
  });

  group('budget', () {
    LimitEvent defaultEvent({YearMonth? from, String value = '500'}) =>
        LimitEvent(
          effectiveFromMonth: from,
          value: Decimal.parse(value),
          kind: LimitEventKind.defaultLimit,
        );

    test('a budget with one default event round trips', () {
      final budget = Budget(
        id: budgetID,
        categoryID: categoryID,
        limitEvents: [defaultEvent(from: const YearMonth(2026, 1))],
        createdAtMonth: const YearMonth(2026, 1),
      );

      final row = budgetToRow(budget, version);
      expect(budgetFromRow(row), budget);
      expect(versionFromRow(row.versionData), version);
    });

    test('malformed json in limitEvents raises rather than defaulting', () {
      final row = budgetToRow(
        Budget(
          id: budgetID,
          categoryID: null,
          limitEvents: [defaultEvent()],
          createdAtMonth: const YearMonth(2026, 1),
        ),
        version,
      ).copyWith(limitEvents: 'not json');

      expect(() => budgetFromRow(row), throwsFormatException);
    });

    test('limitEvents json missing a required key raises', () {
      final row = budgetToRow(
        Budget(
          id: budgetID,
          categoryID: null,
          limitEvents: [defaultEvent()],
          createdAtMonth: const YearMonth(2026, 1),
        ),
        version,
      ).copyWith(limitEvents: json.encode([<String, dynamic>{}]));

      expect(() => budgetFromRow(row), throwsA(isA<TypeError>()));
    });
  });

  group('decimal precision', () {
    test('a value a double would round survives the round trip', () {
      final amount = Decimal.parse('0.1') + Decimal.parse('0.2');

      final row = entryToRow(
        Entry(
          id: entryID,
          date: DateTime.utc(2026, 3, 14),
          amount: amount,
          name: 'Coffee',
          sourceID: accountID,
        ),
        version,
      );

      expect(row.amount, '0.3');
      expect(entryFromRow(row).amount, Decimal.parse('0.3'));
    });
  });

  group('dates', () {
    test('a stored instant off midnight reads as the day it names', () {
      for (final stored in [
        DateTime.utc(2026, 3, 14, 23, 59),
        DateTime.utc(2026, 3, 14, 0, 1),
        DateTime.utc(2026, 3, 14, 12),
      ]) {
        expect(
          dayFromMillis(stored.millisecondsSinceEpoch),
          DateTime.utc(2026, 3, 14),
        );
      }
    });
  });

  group('id normalization', () {
    const upper = 'A1B2C3D4-1111-4111-8111-AAAAAAAAAAAA';
    const upperPocket = 'B1B2C3D4-2222-4222-8222-BBBBBBBBBBBB';

    test('an uppercase account row loads with lowercase ids', () {
      final row = accountToRow(
        Account(id: accountID, name: 'Everyday', type: AccountType.cash),
        version,
      ).copyWith(id: upper, subPocketIds: json.encode([upperPocket]));

      final account = accountFromRow(row);

      expect(account.id, upper.toLowerCase());
      expect(account.subPocketIDs, {upperPocket.toLowerCase()});
    });

    test('the row writers lowercase an uppercase id on the way out', () {
      final row = accountToRow(
        Account(
          id: upper,
          name: 'Everyday',
          type: AccountType.cash,
          subPocketIDs: {upperPocket},
        ),
        version,
      );

      expect(row.id, upper.toLowerCase());
      expect(json.decode(row.subPocketIds), [upperPocket.toLowerCase()]);
    });
  });

  group('unknown enum codes', () {
    test('an unknown account type falls back to other', () {
      final row = accountToRow(
        Account(id: accountID, name: 'Everyday', type: AccountType.cash),
        version,
      ).copyWith(type: 99);

      expect(accountFromRow(row).type, AccountType.other);
    });

    test('an unknown category kind falls back to expense', () {
      final row = categoryToRow(
        TransactionCategory(
          id: categoryID,
          name: 'Coffee',
          kind: CategoryKind.income,
          colorHex: '#FF8800',
          includeInAnalysis: true,
          parentID: null,
          symbol: 'cup',
        ),
        version,
      ).copyWith(kind: 42);

      expect(categoryFromRow(row).kind, CategoryKind.expense);
    });

    test('an unknown lifecycle falls back to active on every row type', () {
      final account = accountToRow(
        Account(
          id: accountID,
          name: 'Everyday',
          type: AccountType.cash,
          lifecycle: LifecycleState.archived,
        ),
        version,
      ).copyWith(lifecycle: 77);
      expect(accountFromRow(account).lifecycle, LifecycleState.active);

      final pocket = pocketToRow(
        SubPocket(id: pocketID, name: 'Groceries'),
        version,
      ).copyWith(lifecycle: -1);
      expect(pocketFromRow(pocket).lifecycle, LifecycleState.active);

      final category = categoryToRow(
        TransactionCategory(
          id: categoryID,
          name: 'Coffee',
          kind: CategoryKind.expense,
          colorHex: '#FF8800',
          includeInAnalysis: true,
          parentID: null,
          symbol: 'cup',
        ),
        version,
      ).copyWith(lifecycle: 77);
      expect(categoryFromRow(category).lifecycle, LifecycleState.active);

      final entry = entryToRow(
        Entry(
          id: entryID,
          date: DateTime.utc(2026, 3, 14),
          amount: Decimal.one,
          name: 'Coffee',
          sourceID: accountID,
        ),
        version,
      ).copyWith(lifecycle: 77);
      expect(entryFromRow(entry).lifecycle, LifecycleState.active);
    });

    test('an unknown frequency falls back to monthly', () {
      final row = planToRow(
        RecurringPlan(
          id: planID,
          template: EntryTemplate(
            amount: Decimal.one,
            name: 'Gym',
            sourceID: accountID,
          ),
          frequency: RecurrenceFrequency.yearly,
          anchor: DateTime.utc(2026, 1, 5),
          lastResolvedDate: DateTime.utc(2026, 1, 5),
        ),
        version,
      ).copyWith(frequency: 99);

      expect(planFromRow(row).frequency, RecurrenceFrequency.monthly);
    });
  });

  group('version vector', () {
    test('a corrupt vector raises rather than loading as empty', () {
      final row = accountToRow(
        Account(id: accountID, name: 'Everyday', type: AccountType.cash),
        version,
      ).copyWith(versionData: Uint8List.fromList(utf8.encode('not json')));

      expect(
        () => versionFromRow(row.versionData),
        throwsA(isA<VersionVectorDecodeError>()),
      );
    });

    test('a vector of the wrong shape raises', () {
      expect(
        () => versionFromRow(Uint8List.fromList(utf8.encode('"a string"'))),
        throwsA(isA<VersionVectorDecodeError>()),
      );
    });
  });
}
