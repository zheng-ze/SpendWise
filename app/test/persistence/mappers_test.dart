import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart' as rows;
import 'package:spendwise/persistence/mappers.dart';
import 'package:spendwise/persistence/version_vector.dart';

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
        subPocketIDs: {pocketID},
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

    test('the account row stores sub pocket ids as a json array', () {
      final row = accountToRow(
        Account(
          id: accountID,
          name: 'Everyday',
          type: AccountType.cash,
          subPocketIDs: {pocketID},
        ),
        version,
      );

      expect(json.decode(row.subPocketIds), [pocketID]);
    });

    test('an account with no sub pockets stores an empty array', () {
      final row = accountToRow(
        Account(id: accountID, name: 'Everyday', type: AccountType.cash),
        version,
      );

      expect(json.decode(row.subPocketIds), isEmpty);
      expect(accountFromRow(row).subPocketIDs, isEmpty);
    });

    test('a null statement day survives the round trip', () {
      final account = Account(
        id: accountID,
        name: 'Everyday',
        type: AccountType.cash,
      );

      final restored = accountFromRow(accountToRow(account, version));

      expect(restored.statementDay, isNull);
      expect(restored, account);
    });

    test('a loan account type survives the round trip', () {
      final account = Account(
        id: accountID,
        name: 'Car loan',
        type: AccountType.loan,
      );

      final row = accountToRow(account, version);

      expect(row.type, 8);
      expect(accountFromRow(row).type, AccountType.loan);
    });

    test('an overdraft account type survives the round trip', () {
      final account = Account(
        id: accountID,
        name: 'Checking overdraft',
        type: AccountType.overdraft,
      );

      final row = accountToRow(account, version);

      expect(row.type, 9);
      expect(accountFromRow(row).type, AccountType.overdraft);
    });
  });

  group('pocket', () {
    test('pocketRoundTrips', () {
      final pocket = SubPocket(
        id: pocketID,
        name: 'Groceries',
        incomingTransfersAsExpenses: true,
        lifecycle: LifecycleState.archived,
      );

      final row = pocketToRow(pocket, version);
      expect(pocketFromRow(row), pocket);
      expect(versionFromRow(row.versionData), version);
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

    test('the category row stores the kind code', () {
      expect(categoryToRow(makeCategory(), version).kind, 1);
      expect(
        categoryToRow(makeCategory(kind: CategoryKind.income), version).kind,
        0,
      );
    });

    test('a top level category stores a null parent', () {
      final row = categoryToRow(makeCategory(), version);

      expect(row.parentId, isNull);
      expect(categoryFromRow(row).parentID, isNull);
    });

    test('categoryParentIDImmutableOnUpsert', () {
      final stored = categoryToRow(
        makeCategory(parentID: parentCategoryID),
        version,
      );
      final reparented = makeCategory(parentID: entryID);

      final upserted = categoryUpsertRow(reparented, version, stored: stored);

      expect(upserted.parentId, parentCategoryID);
      expect(categoryFromRow(upserted).parentID, parentCategoryID);
    });

    test('an upsert over no stored row takes the incoming parent', () {
      final upserted = categoryUpsertRow(
        makeCategory(parentID: parentCategoryID),
        version,
        stored: null,
      );

      expect(upserted.parentId, parentCategoryID);
    });

    test('an upsert carries every field but the parent from the incoming '
        'category', () {
      final stored = categoryToRow(
        makeCategory(parentID: parentCategoryID),
        version,
      );
      final renamed = TransactionCategory(
        id: categoryID,
        name: 'Tea',
        kind: CategoryKind.expense,
        colorHex: '#00FF00',
        includeInAnalysis: false,
        parentID: null,
        symbol: 'leaf',
        lifecycle: LifecycleState.archived,
      );

      final upserted = categoryUpsertRow(renamed, version, stored: stored);

      expect(upserted.name, 'Tea');
      expect(upserted.colorHex, '#00FF00');
      expect(upserted.includeInAnalysis, isFalse);
      expect(upserted.symbol, 'leaf');
      expect(upserted.lifecycle, LifecycleState.archived.code);
      expect(upserted.parentId, parentCategoryID);
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

    test('transferEntryRoundTrips', () {
      final transfer = Entry(
        id: entryID,
        date: DateTime.utc(2026, 3, 14),
        amount: Decimal.parse('100'),
        name: 'To savings',
        sourceID: accountID,
        destinationID: pocketID,
      );

      final row = entryToRow(transfer, version);

      expect(row.destinationId, pocketID);
      expect(entryFromRow(row), transfer);
    });

    test('the entry row stores the amount as a decimal string', () {
      final row = entryToRow(
        Entry(
          id: entryID,
          date: DateTime.utc(2026, 3, 14),
          amount: Decimal.parse('-1234.5678'),
          name: 'Coffee',
          sourceID: accountID,
        ),
        version,
      );

      expect(row.amount, '-1234.5678');
    });

    test(
      'the note column stays unwritten, it is reserved but not used yet',
      () {
        final row = entryToRow(
          Entry(
            id: entryID,
            date: DateTime.utc(2026, 3, 14),
            amount: Decimal.one,
            name: 'Coffee',
            sourceID: accountID,
          ),
          version,
        );

        expect(row.note, isNull);
        expect(row.systemKind, isNull);
      },
    );

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

    test('systemKind stays null for a plain user entry', () {
      final entry = Entry(
        id: entryID,
        date: DateTime.utc(2026, 3, 14),
        amount: Decimal.one,
        name: 'Coffee',
        sourceID: accountID,
      );

      final row = entryToRow(entry, version);
      expect(row.systemKind, isNull);
      expect(entryFromRow(row).systemKind, isNull);
    });
  });

  group('plan', () {
    EntryTemplate makeTemplate({String? destinationID}) => EntryTemplate(
      amount: Decimal.parse('-15.50'),
      name: 'Gym',
      categoryID: destinationID == null ? categoryID : null,
      sourceID: accountID,
      destinationID: destinationID,
      includeInAnalysis: true,
    );

    test('planRoundTrips', () {
      final plan = RecurringPlan(
        id: planID,
        template: makeTemplate(),
        frequency: RecurrenceFrequency.quarterly,
        anchor: DateTime.utc(2026, 1, 5),
        endDate: DateTime.utc(2027, 1, 5),
        lastResolvedDate: DateTime.utc(2026, 4, 5),
      );

      final row = planToRow(plan, version);
      expect(planFromRow(row), plan);
      expect(versionFromRow(row.versionData), version);
    });

    test('transferPlanRoundTrips', () {
      final plan = RecurringPlan(
        id: planID,
        template: makeTemplate(destinationID: pocketID),
        frequency: RecurrenceFrequency.weekly,
        anchor: DateTime.utc(2026, 1, 5),
        lastResolvedDate: DateTime.utc(2026, 1, 5),
      );

      final row = planToRow(plan, version);

      expect(row.templateDestinationId, pocketID);
      expect(row.templateCategoryId, isNull);
      expect(planFromRow(row), plan);
    });

    test('a plan with no end date round trips', () {
      final plan = RecurringPlan(
        id: planID,
        template: makeTemplate(),
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 5),
        lastResolvedDate: DateTime.utc(2026, 1, 5),
      );

      final row = planToRow(plan, version);

      expect(row.endDate, isNull);
      expect(planFromRow(row), plan);
    });

    test('the plan row stores the frequency code and the template amount as a '
        'decimal string', () {
      final row = planToRow(
        RecurringPlan(
          id: planID,
          template: makeTemplate(),
          frequency: RecurrenceFrequency.yearly,
          anchor: DateTime.utc(2026, 1, 5),
          lastResolvedDate: DateTime.utc(2026, 1, 5),
        ),
        version,
      );

      expect(row.frequency, 4);
      expect(row.templateAmount, '-15.5');
    });

    test('a plan row carries the lifecycle it is given', () {
      final plan = RecurringPlan(
        id: planID,
        template: makeTemplate(),
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 5),
        lastResolvedDate: DateTime.utc(2026, 1, 5),
      );

      final row = planToRow(
        plan,
        version,
        lifecycle: LifecycleState.tombstoned,
      );

      expect(row.lifecycle, 3);
      expect(planToRow(plan, version).lifecycle, 0);
    });
  });

  group('budget', () {
    LimitEvent defaultEvent({YearMonth? from, String value = '500'}) =>
        LimitEvent(
          effectiveFromMonth: from,
          value: Decimal.parse(value),
          kind: LimitEventKind.defaultLimit,
        );

    LimitEvent overrideEvent(YearMonth from, String value) => LimitEvent(
      effectiveFromMonth: from,
      value: Decimal.parse(value),
      kind: LimitEventKind.override,
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

    test('a budget with a default event and an override round trips', () {
      final budget = Budget(
        id: budgetID,
        categoryID: categoryID,
        limitEvents: [
          defaultEvent(from: const YearMonth(2026, 1)),
          overrideEvent(const YearMonth(2026, 3), '750'),
        ],
        createdAtMonth: const YearMonth(2026, 1),
      );

      final row = budgetToRow(budget, version);
      expect(budgetFromRow(row), budget);
    });

    test('an overall budget stores a null categoryID', () {
      final budget = Budget(
        id: budgetID,
        categoryID: null,
        limitEvents: [defaultEvent()],
        createdAtMonth: const YearMonth(2026, 1),
      );

      final row = budgetToRow(budget, version);

      expect(row.categoryId, isNull);
      expect(budgetFromRow(row), budget);
    });

    test('a category budget stores the category id', () {
      final budget = Budget(
        id: budgetID,
        categoryID: categoryID,
        limitEvents: [defaultEvent()],
        createdAtMonth: const YearMonth(2026, 1),
      );

      final row = budgetToRow(budget, version);

      expect(row.categoryId, categoryID);
      expect(budgetFromRow(row), budget);
    });

    test('limitEvents is stored as a json array', () {
      final row = budgetToRow(
        Budget(
          id: budgetID,
          categoryID: null,
          limitEvents: [
            defaultEvent(from: const YearMonth(2026, 1)),
            overrideEvent(const YearMonth(2026, 3), '750'),
          ],
          createdAtMonth: const YearMonth(2026, 1),
        ),
        version,
      );

      final decoded = json.decode(row.limitEvents) as List<dynamic>;
      expect(decoded, [
        {'effectiveFromMonth': '2026-01', 'value': '500', 'kind': 0},
        {'effectiveFromMonth': '2026-03', 'value': '750', 'kind': 1},
      ]);
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

  group('lifecycleRoundTrips', () {
    test('every lifecycle state survives on every row type', () {
      for (final lifecycle in LifecycleState.values) {
        final account = Account(
          id: accountID,
          name: 'Everyday',
          type: AccountType.cash,
          lifecycle: lifecycle,
        );
        expect(
          accountFromRow(accountToRow(account, version)).lifecycle,
          lifecycle,
        );

        final pocket = SubPocket(
          id: pocketID,
          name: 'Groceries',
          lifecycle: lifecycle,
        );
        expect(
          pocketFromRow(pocketToRow(pocket, version)).lifecycle,
          lifecycle,
        );

        final category = TransactionCategory(
          id: categoryID,
          name: 'Coffee',
          kind: CategoryKind.expense,
          colorHex: '#FF8800',
          includeInAnalysis: true,
          parentID: null,
          symbol: 'cup',
          lifecycle: lifecycle,
        );
        expect(
          categoryFromRow(categoryToRow(category, version)).lifecycle,
          lifecycle,
        );

        final entry = Entry(
          id: entryID,
          date: DateTime.utc(2026, 3, 14),
          amount: Decimal.one,
          name: 'Coffee',
          sourceID: accountID,
          lifecycle: lifecycle,
        );
        expect(entryFromRow(entryToRow(entry, version)).lifecycle, lifecycle);

        expect(accountToRow(account, version).lifecycle, lifecycle.code);
      }
    });
  });

  group('decimal precision', () {
    final amounts = [
      Decimal.parse('0'),
      Decimal.parse('0.01'),
      Decimal.parse('-0.01'),
      Decimal.parse('-1234567890.123456789'),
      Decimal.parse('99999999999999999999.99999999999999999999'),
      Decimal.parse('-99999999999999999999.99999999999999999999'),
    ];

    test('an entry amount round trips exactly at every magnitude', () {
      for (final amount in amounts) {
        final entry = Entry(
          id: entryID,
          date: DateTime.utc(2026, 3, 14),
          amount: amount,
          name: 'Coffee',
          sourceID: accountID,
        );

        final row = entryToRow(entry, version);

        expect(row.amount, amount.toString());
        expect(entryFromRow(row).amount, amount);
      }
    });

    test('a plan template amount round trips exactly at every magnitude', () {
      for (final amount in amounts) {
        final plan = RecurringPlan(
          id: planID,
          template: EntryTemplate(
            amount: amount,
            name: 'Gym',
            sourceID: accountID,
          ),
          frequency: RecurrenceFrequency.monthly,
          anchor: DateTime.utc(2026, 1, 5),
          lastResolvedDate: DateTime.utc(2026, 1, 5),
        );

        final row = planToRow(plan, version);

        expect(row.templateAmount, amount.toString());
        expect(planFromRow(row).template.amount, amount);
      }
    });

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
    // Northern spring forward, southern autumn back, and the two instants a
    // zone-aware conversion would slide onto the neighbouring day.
    final dstDays = [
      DateTime.utc(2026, 3, 8),
      DateTime.utc(2026, 11, 1),
      DateTime.utc(2026, 4, 5),
      DateTime.utc(2026, 10, 4),
    ];

    test('an entry date round trips across a dst boundary', () {
      for (final day in dstDays) {
        final entry = Entry(
          id: entryID,
          date: day,
          amount: Decimal.one,
          name: 'Coffee',
          sourceID: accountID,
        );

        final row = entryToRow(entry, version);

        expect(row.date, day.millisecondsSinceEpoch);
        final restored = entryFromRow(row).date;
        expect(restored, day);
        expect(restored.isUtc, isTrue);
      }
    });

    test('the plan dates round trip across a dst boundary', () {
      for (final day in dstDays) {
        final plan = RecurringPlan(
          id: planID,
          template: EntryTemplate(
            amount: Decimal.one,
            name: 'Gym',
            sourceID: accountID,
          ),
          frequency: RecurrenceFrequency.monthly,
          anchor: day,
          endDate: day,
          lastResolvedDate: day,
        );

        final row = planToRow(plan, version);

        expect(row.anchor, day.millisecondsSinceEpoch);
        expect(row.endDate, day.millisecondsSinceEpoch);
        expect(row.lastResolvedDate, day.millisecondsSinceEpoch);

        final restored = planFromRow(row);
        expect(restored.anchor, day);
        expect(restored.endDate, day);
        expect(restored.lastResolvedDate, day);
        expect(restored.anchor.isUtc, isTrue);
      }
    });

    // Asserted on the reader rather than a mapped row, since domain
    // constructors re-normalize the date and would hide an instant-preserving read.
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

    test('the day survives a round trip through the stored millis', () {
      for (final day in dstDays) {
        expect(dayFromMillis(millisFromDay(day)), day);
      }
    });
  });

  group('id normalization', () {
    const upper = 'A1B2C3D4-1111-4111-8111-AAAAAAAAAAAA';
    const upperPocket = 'B1B2C3D4-2222-4222-8222-BBBBBBBBBBBB';
    const upperCategory = 'C1B2C3D4-3333-4333-8333-CCCCCCCCCCCC';
    const upperParent = 'D1B2C3D4-4444-4444-8444-DDDDDDDDDDDD';

    setUp(() {
      for (final id in [upper, upperPocket, upperCategory, upperParent]) {
        expect(id, matches(RegExp('[A-F]')));
      }
    });

    test('an uppercase account row loads with lowercase ids', () {
      final row = accountToRow(
        Account(id: accountID, name: 'Everyday', type: AccountType.cash),
        version,
      ).copyWith(id: upper, subPocketIds: json.encode([upperPocket]));

      final account = accountFromRow(row);

      expect(account.id, upper.toLowerCase());
      expect(account.subPocketIDs, {upperPocket.toLowerCase()});
    });

    test('an uppercase pocket row loads with a lowercase id', () {
      final row = pocketToRow(
        SubPocket(id: pocketID, name: 'Groceries'),
        version,
      ).copyWith(id: upperPocket);

      expect(pocketFromRow(row).id, upperPocket.toLowerCase());
    });

    test('an uppercase category row loads with lowercase ids', () {
      final row = categoryToRow(
        TransactionCategory(
          id: categoryID,
          name: 'Coffee',
          kind: CategoryKind.expense,
          colorHex: '#FF8800',
          includeInAnalysis: true,
          parentID: parentCategoryID,
          symbol: 'cup',
        ),
        version,
      ).copyWith(id: upperCategory, parentId: Value(upperParent));

      final category = categoryFromRow(row);

      expect(category.id, upperCategory.toLowerCase());
      expect(category.parentID, upperParent.toLowerCase());
    });

    test('an uppercase entry row loads with lowercase ids', () {
      final row =
          entryToRow(
            Entry(
              id: entryID,
              date: DateTime.utc(2026, 3, 14),
              amount: Decimal.one,
              name: 'Coffee',
              sourceID: accountID,
              destinationID: pocketID,
              categoryID: categoryID,
            ),
            version,
          ).copyWith(
            id: upper,
            sourceId: upperPocket,
            destinationId: Value(upperParent),
            categoryId: Value(upperCategory),
          );

      final entry = entryFromRow(row);

      expect(entry.id, upper.toLowerCase());
      expect(entry.sourceID, upperPocket.toLowerCase());
      expect(entry.destinationID, upperParent.toLowerCase());
      expect(entry.categoryID, upperCategory.toLowerCase());
    });

    test('an uppercase plan row loads with lowercase ids', () {
      final row =
          planToRow(
            RecurringPlan(
              id: planID,
              template: EntryTemplate(
                amount: Decimal.one,
                name: 'Gym',
                sourceID: accountID,
                categoryID: categoryID,
              ),
              frequency: RecurrenceFrequency.monthly,
              anchor: DateTime.utc(2026, 1, 5),
              lastResolvedDate: DateTime.utc(2026, 1, 5),
            ),
            version,
          ).copyWith(
            id: upper,
            templateSourceId: upperPocket,
            templateCategoryId: Value(upperCategory),
            templateDestinationId: Value(upperParent),
          );

      final plan = planFromRow(row);

      expect(plan.id, upper.toLowerCase());
      expect(plan.template.sourceID, upperPocket.toLowerCase());
      expect(plan.template.categoryID, upperCategory.toLowerCase());
      expect(plan.template.destinationID, upperParent.toLowerCase());
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

    test('a known code is not swallowed by the fallback', () {
      final row = accountToRow(
        Account(id: accountID, name: 'Everyday', type: AccountType.cash),
        version,
      ).copyWith(type: AccountType.investment.code);

      expect(accountFromRow(row).type, AccountType.investment);
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

    test('an empty blob loads as the empty vector', () {
      expect(versionFromRow(Uint8List(0)), VersionVector.empty);
    });

    test('every row type writes the vector it is given', () {
      final rowVersion = VersionVector({
        'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa': 7,
        'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb': 2,
      });

      final blobs = [
        accountToRow(
          Account(id: accountID, name: 'Everyday', type: AccountType.cash),
          rowVersion,
        ).versionData,
        pocketToRow(
          SubPocket(id: pocketID, name: 'Groceries'),
          rowVersion,
        ).versionData,
        categoryToRow(
          TransactionCategory(
            id: categoryID,
            name: 'Coffee',
            kind: CategoryKind.expense,
            colorHex: '#FF8800',
            includeInAnalysis: true,
            parentID: null,
            symbol: 'cup',
          ),
          rowVersion,
        ).versionData,
        entryToRow(
          Entry(
            id: entryID,
            date: DateTime.utc(2026, 3, 14),
            amount: Decimal.one,
            name: 'Coffee',
            sourceID: accountID,
          ),
          rowVersion,
        ).versionData,
        planToRow(
          RecurringPlan(
            id: planID,
            template: EntryTemplate(
              amount: Decimal.one,
              name: 'Gym',
              sourceID: accountID,
            ),
            frequency: RecurrenceFrequency.monthly,
            anchor: DateTime.utc(2026, 1, 5),
            lastResolvedDate: DateTime.utc(2026, 1, 5),
          ),
          rowVersion,
        ).versionData,
      ];

      for (final blob in blobs) {
        expect(versionFromRow(blob), rowVersion);
      }
    });
  });

  group('row types', () {
    test('the writers return the generated row classes', () {
      expect(
        accountToRow(
          Account(id: accountID, name: 'Everyday', type: AccountType.cash),
          version,
        ),
        isA<rows.Account>(),
      );
      expect(
        pocketToRow(SubPocket(id: pocketID, name: 'Groceries'), version),
        isA<rows.SubPocket>(),
      );
    });
  });
}
