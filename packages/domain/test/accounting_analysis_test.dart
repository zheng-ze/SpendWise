import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

Decimal money(int value) => Decimal.fromInt(value);

List<AnalysisItem> itemsOfKind(LedgerState ledger, CategoryKind kind) =>
    Accounting.analysisItems(ledger).where((i) => i.kind == kind).toList();

List<AnalysisItem> expenseItems(LedgerState ledger) =>
    itemsOfKind(ledger, CategoryKind.expense);

void main() {
  final a = uuid(1);
  final b = uuid(2);
  final cat = uuid(3);
  final parent = uuid(4);
  final child = uuid(5);
  final inc = uuid(6);

  group('analysisItems gates', () {
    test('a normal expense produces an item with an absolute amount', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(cat));
      ledger.addEntry(entry(amount: money(-50), categoryID: cat, sourceID: a));

      final items = expenseItems(ledger);

      expect(items, hasLength(1));
      expect(items.first.amount, money(50));
      expect(items.first.bucketID, cat);
    });

    test('income produces no expense item', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(entry(amount: money(1000), sourceID: a));

      expect(expenseItems(ledger), isEmpty);
    });

    test('a plain transfer produces no expense item', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addAccount(account(b));
      ledger.addEntry(entry(amount: money(200), sourceID: a, destinationID: b));

      expect(expenseItems(ledger), isEmpty);
    });

    test('a transfer into a treat-as-expense holder produces expense', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addAccount(account(b, incomingTransfersAsExpenses: true));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: b));

      final items = expenseItems(ledger);

      expect(items, hasLength(1));
      expect(items.first.amount, money(300));
      expect(items.first.bucketID, isNull);
    });

    test('a transfer out of a treat-as-expense holder produces income', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a, incomingTransfersAsExpenses: true));
      ledger.addAccount(account(b));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: b));

      final items = Accounting.analysisItems(ledger);

      expect(items, hasLength(1));
      expect(items.single.kind, CategoryKind.income);
      expect(items.single.amount, money(300));
      expect(items.single.bucketID, isNull);
    });

    test('a transfer between two treat-as-expense holders produces both', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a, incomingTransfersAsExpenses: true));
      ledger.addAccount(account(b, incomingTransfersAsExpenses: true));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: b));

      final items = Accounting.analysisItems(ledger);

      expect(items, hasLength(2));
      expect(expenseItems(ledger).single.amount, money(300));
      expect(
        itemsOfKind(ledger, CategoryKind.income).single.amount,
        money(300),
      );
    });

    test('a transfer between two unflagged holders produces nothing', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addAccount(account(b));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: b));

      expect(Accounting.analysisItems(ledger), isEmpty);
    });

    test('a self transfer on a flagged holder nets to zero', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a, incomingTransfersAsExpenses: true));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: a));

      final items = Accounting.analysisItems(ledger);

      expect(items, hasLength(2));
      expect(items.total(kind: CategoryKind.expense), money(300));
      expect(items.total(kind: CategoryKind.income), money(300));
      expect(
        items.total(kind: CategoryKind.expense) -
            items.total(kind: CategoryKind.income),
        Decimal.zero,
      );
    });

    test('an entry excluded from analysis produces no item', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(
        entry(amount: money(-100), sourceID: a, includeInAnalysis: false),
      );

      expect(Accounting.analysisItems(ledger), isEmpty);
    });

    test('an entry whose holder is gone produces no item', () {
      final ledger = LedgerState(
        moneySources: {},
        entries: {
          for (final e in [entry(amount: money(-100), sourceID: a)]) e.id: e,
        },
      );

      expect(Accounting.analysisItems(ledger), isEmpty);
    });
  });

  group('archived holders keep their analysis history', () {
    test('an archived source keeps its expense item', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(cat));
      ledger.addEntry(entry(amount: money(-80), categoryID: cat, sourceID: a));
      ledger.deleteAccount(a);

      final items = expenseItems(ledger);

      expect(items, hasLength(1));
      expect(items.single.amount, money(80));
      expect(items.single.bucketID, cat);
    });

    test('an archived source keeps its income item', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(entry(amount: money(900), sourceID: a));
      ledger.deleteAccount(a);

      final items = itemsOfKind(ledger, CategoryKind.income);

      expect(items, hasLength(1));
      expect(items.single.amount, money(900));
    });

    test('an archived transfer destination keeps its expense item', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addAccount(account(b, incomingTransfersAsExpenses: true));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: b));

      expect(expenseItems(ledger).single.amount, money(300));

      ledger.deleteAccount(b);

      final items = expenseItems(ledger);

      expect(items, hasLength(1));
      expect(items.single.amount, money(300));
      expect(items.single.bucketID, isNull);
    });

    test('an archived transfer source keeps the survivor income item', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a, incomingTransfersAsExpenses: true));
      ledger.addAccount(account(b));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: b));
      ledger.deleteAccount(a);

      final items = Accounting.analysisItems(ledger);

      expect(items, hasLength(1));
      expect(items.single.kind, CategoryKind.income);
      expect(items.single.amount, money(300));
    });

    test('a reference-only holder keeps its items', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(entry(amount: money(-80), sourceID: a));
      ledger.deleteAccount(a);
      ledger.purgeAccount(a);

      expect(ledger.moneySources[a]?.lifecycle, LifecycleState.referenceOnly);
      expect(expenseItems(ledger).single.amount, money(80));
    });
  });

  group('an item carries its own entry date', () {
    final may = DateTime.utc(2026, 5);
    final june = DateTime.utc(2026, 6);
    final april = DateTime.utc(2026, 4);

    test('an expense item dates to its entry', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(
        entry(amount: money(-50), sourceID: a, date: DateTime(2026, 5, 15)),
      );

      final items = expenseItems(ledger);

      expect(items.single.date, DateTime.utc(2026, 5, 15));
      expect(items.total(interval: DateRange(may, june)), money(50));
      expect(items.total(interval: DateRange(april, may)), Decimal.zero);
    });

    test('an income item dates to its entry', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(
        entry(amount: money(700), sourceID: a, date: DateTime(2026, 5, 15)),
      );

      final items = itemsOfKind(ledger, CategoryKind.income);

      expect(items.single.date, DateTime.utc(2026, 5, 15));
      expect(items.total(interval: DateRange(may, june)), money(700));
      expect(items.total(interval: DateRange(april, may)), Decimal.zero);
    });

    test('a treat-as-expense transfer item dates to its entry', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addAccount(account(b, incomingTransfersAsExpenses: true));
      ledger.addEntry(
        entry(
          amount: money(300),
          sourceID: a,
          destinationID: b,
          date: DateTime(2026, 5, 15),
        ),
      );

      final items = expenseItems(ledger);

      expect(items.single.date, DateTime.utc(2026, 5, 15));
      expect(items.total(interval: DateRange(may, june)), money(300));
      expect(items.total(interval: DateRange(april, may)), Decimal.zero);
    });

    test('the income leg of a transfer dates to its entry', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a, incomingTransfersAsExpenses: true));
      ledger.addAccount(account(b));
      ledger.addEntry(
        entry(
          amount: money(300),
          sourceID: a,
          destinationID: b,
          date: DateTime(2026, 5, 15),
        ),
      );

      final items = itemsOfKind(ledger, CategoryKind.income);

      expect(items.single.date, DateTime.utc(2026, 5, 15));
      expect(items.total(interval: DateRange(may, june)), money(300));
      expect(items.total(interval: DateRange(april, may)), Decimal.zero);
    });

    test('two entries in adjacent months land in their own windows', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(
        entry(amount: money(-50), sourceID: a, date: DateTime(2026, 5, 15)),
      );
      ledger.addEntry(
        entry(amount: money(-20), sourceID: a, date: DateTime(2026, 4, 15)),
      );

      final items = expenseItems(ledger);

      expect(items.total(interval: DateRange(may, june)), money(50));
      expect(items.total(interval: DateRange(april, may)), money(20));
      expect(items.map((i) => i.date).toSet(), hasLength(2));
    });
  });

  group('category resolution', () {
    test('a category excluded from analysis hides its expenses', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(cat, includeInAnalysis: false));
      ledger.addEntry(entry(amount: money(-100), categoryID: cat, sourceID: a));

      expect(expenseItems(ledger), isEmpty);
    });

    test('a parent excluded from analysis hides its child expenses', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(parent, includeInAnalysis: false));
      ledger.addCategory(category(child, parent: parent));
      ledger.addEntry(
        entry(amount: money(-100), categoryID: child, sourceID: a),
      );

      expect(expenseItems(ledger), isEmpty);
    });

    test('an uncategorized expense is included', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(entry(amount: money(-40), sourceID: a));

      final items = expenseItems(ledger);

      expect(items, hasLength(1));
      expect(items.first.bucketID, isNull);
      expect(items.first.amount, money(40));
    });

    test('an archived category still buckets under its id', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(cat));
      ledger.addEntry(entry(amount: money(-70), categoryID: cat, sourceID: a));
      ledger.deleteCategory(cat);

      final items = expenseItems(ledger);

      expect(items, hasLength(1));
      expect(items.first.bucketID, cat);
      expect(items.first.amount, money(70));
    });

    test('an unresolvable category renders as uncategorized', () {
      // A category swept out of the map while an entry still names it. The
      // mutators cannot reach this state, so it is built directly.
      final dangling = entry(amount: money(-70), categoryID: cat, sourceID: a);
      final ledger = LedgerState(
        moneySources: {a: MoneySource.account(account(a))},
        entries: {dangling.id: dangling},
      );

      final items = expenseItems(ledger);

      expect(items, hasLength(1));
      expect(items.first.bucketID, isNull);
      expect(items.first.amount, money(70));
    });

    test('resolveCategory reports each outcome as its own case', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(cat));
      ledger.addCategory(category(parent, includeInAnalysis: false));
      ledger.addCategory(category(child, parent: parent));

      expect(
        Accounting.resolveCategory(entry(sourceID: a), ledger),
        isA<Uncategorized>(),
      );
      expect(
        Accounting.resolveCategory(
          entry(sourceID: a, categoryID: uuid(9)),
          ledger,
        ),
        isA<Uncategorized>(),
      );
      expect(
        Accounting.resolveCategory(
          entry(sourceID: a, categoryID: parent),
          ledger,
        ),
        isA<Excluded>(),
      );
      expect(
        Accounting.resolveCategory(
          entry(sourceID: a, categoryID: child),
          ledger,
        ),
        isA<Excluded>(),
      );
      expect(
        Accounting.resolveCategory(entry(sourceID: a, categoryID: cat), ledger),
        InCategory(cat),
      );
    });
  });

  group('kind tagging', () {
    test('analysis items tag expense and income separately', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(cat));
      ledger.addCategory(category(inc, kind: CategoryKind.income));
      ledger.addEntry(entry(amount: money(-60), categoryID: cat, sourceID: a));
      ledger.addEntry(entry(amount: money(900), categoryID: inc, sourceID: a));

      final expense = expenseItems(ledger).single;
      final income = itemsOfKind(ledger, CategoryKind.income).single;

      expect(expense.amount, money(60));
      expect(expense.bucketID, cat);
      expect(income.amount, money(900));
      expect(income.bucketID, inc);
    });

    test('income honors the analysis exclusion', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(
        category(inc, kind: CategoryKind.income, includeInAnalysis: false),
      );
      ledger.addEntry(entry(amount: money(500), categoryID: inc, sourceID: a));

      expect(itemsOfKind(ledger, CategoryKind.income), isEmpty);
    });

    test('an uncategorized income keeps the income kind', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(entry(amount: money(500), sourceID: a));

      final items = Accounting.analysisItems(ledger);

      expect(items, hasLength(1));
      expect(items.single.kind, CategoryKind.income);
      expect(items.single.amount, money(500));
    });
  });

  group('income totals', () {
    test('income sums positive non-transfer entries', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(entry(amount: money(1000), sourceID: a));
      ledger.addEntry(entry(amount: money(500), sourceID: a));
      ledger.addEntry(entry(amount: money(-200), sourceID: a));

      expect(
        Accounting.analysisItems(ledger).total(kind: CategoryKind.income),
        money(1500),
      );
    });

    test('income ignores transfers and excluded entries', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addAccount(account(b));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: b));
      ledger.addEntry(
        entry(amount: money(999), sourceID: a, includeInAnalysis: false),
      );

      expect(
        Accounting.analysisItems(ledger).total(kind: CategoryKind.income),
        Decimal.zero,
      );
    });

    test('a total with nothing surviving its filters is zero', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(entry(amount: money(-40), sourceID: a));

      expect(
        Accounting.analysisItems(ledger).total(buckets: {cat}),
        Decimal.zero,
      );
    });

    test('the null bucket selects uncategorized items', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(cat));
      ledger.addEntry(entry(amount: money(-40), sourceID: a));
      ledger.addEntry(entry(amount: money(-25), categoryID: cat, sourceID: a));

      expect(
        Accounting.analysisItems(ledger).total(buckets: {null}),
        money(40),
      );
    });
  });

  group('roll-up', () {
    test('roll-up folds subcategories into their parent', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(parent));
      ledger.addCategory(category(child, parent: parent));
      ledger.addEntry(
        entry(amount: money(-30), categoryID: parent, sourceID: a),
      );
      ledger.addEntry(
        entry(amount: money(-70), categoryID: child, sourceID: a),
      );

      final sums = Accounting.rollUp(
        Accounting.analysisItems(ledger).filtered(kind: CategoryKind.expense),
        ledger,
      );

      expect(sums, {parent: money(100)});
    });

    test('bucket totals separate each child from the parent direct', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(parent));
      ledger.addCategory(category(child, parent: parent));
      ledger.addEntry(
        entry(amount: money(-30), categoryID: parent, sourceID: a),
      );
      ledger.addEntry(
        entry(amount: money(-70), categoryID: child, sourceID: a),
      );

      final items = Accounting.analysisItems(
        ledger,
      ).filtered(kind: CategoryKind.expense);
      final mainTotal = items.total(buckets: {parent, child});
      final childTotal = items.total(buckets: {child});

      expect(mainTotal, money(100));
      expect(childTotal, money(70));
      expect(mainTotal - childTotal, money(30));
    });

    test('uncategorized items form their own bucket', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(entry(amount: money(-45), sourceID: a));

      final sums = Accounting.rollUp(
        Accounting.analysisItems(ledger).filtered(kind: CategoryKind.expense),
        ledger,
      );

      expect(sums, {null: money(45)});
    });

    test('a bucket naming a category absent from the ledger stays null', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));

      expect(Accounting.mainBucketID(cat, ledger), isNull);
      expect(Accounting.mainBucketID(null, ledger), isNull);
    });
  });

  group('normalized ids at the Accounting boundary', () {
    // uuid() emits digits only, so uppercasing it is identity and would prove
    // nothing. These carry hex letters.
    const hexParent = 'a1b2c3d4-0000-4000-8000-00000000000a';
    const hexChild = 'b2c3d4e5-0000-4000-8000-00000000000b';
    const hexSource = 'c3d4e5f6-0000-4000-8000-00000000000c';

    test(
      'the mixed-case fixtures really differ from their normalized form',
      () {
        expect(hexParent.toUpperCase(), isNot(hexParent));
        expect(hexChild.toUpperCase(), isNot(hexChild));
        expect(hexSource.toUpperCase(), isNot(hexSource));
      },
    );

    test('mainBucketID resolves a mixed-case leaf to its parent', () {
      final ledger = LedgerState();
      ledger.addAccount(account(hexSource));
      ledger.addCategory(category(hexParent));
      ledger.addCategory(category(hexChild, parent: hexParent));

      expect(
        Accounting.mainBucketID(hexChild.toUpperCase(), ledger),
        hexParent,
      );
    });

    test('mainBucketID returns a normalized id for a mixed-case main', () {
      final ledger = LedgerState();
      ledger.addCategory(category(hexParent));

      expect(
        Accounting.mainBucketID(hexParent.toUpperCase(), ledger),
        hexParent,
      );
    });

    test('rollUp files a mixed-case bucket under its parent', () {
      final ledger = LedgerState();
      ledger.addAccount(account(hexSource));
      ledger.addCategory(category(hexParent));
      ledger.addCategory(category(hexChild, parent: hexParent));

      final items = [
        AnalysisItem(
          bucketID: hexChild.toUpperCase(),
          amount: money(80),
          date: DateTime.utc(2026),
          kind: CategoryKind.expense,
        ),
      ];

      expect(Accounting.rollUp(items, ledger), {hexParent: money(80)});
    });

    test('balance accepts a mixed-case holder id', () {
      final entries = [
        entry(amount: money(1000), sourceID: hexSource),
        entry(amount: money(-250), sourceID: hexSource),
      ];

      expect(
        Accounting.balance(
          of: hexSource.toUpperCase(),
          entries: entries,
          sourceIDs: {hexSource},
        ),
        money(750),
      );
    });

    test('balance accepts a mixed-case holder id on a transfer leg', () {
      final entries = [
        entry(
          amount: money(300),
          sourceID: hexSource,
          destinationID: hexParent,
        ),
      ];

      expect(
        Accounting.balance(
          of: hexParent.toUpperCase(),
          entries: entries,
          sourceIDs: {hexSource, hexParent},
        ),
        money(300),
      );
      expect(
        Accounting.balance(
          of: hexSource.toUpperCase(),
          entries: entries,
          sourceIDs: {hexSource, hexParent},
        ),
        money(-300),
      );
    });

    test('filtered and total accept a mixed-case bucket', () {
      final ledger = LedgerState();
      ledger.addAccount(account(hexSource));
      ledger.addCategory(category(hexChild));
      ledger.addEntry(
        entry(amount: money(-60), categoryID: hexChild, sourceID: hexSource),
      );
      ledger.addEntry(entry(amount: money(-15), sourceID: hexSource));

      final items = Accounting.analysisItems(
        ledger,
      ).filtered(kind: CategoryKind.expense);

      expect(items.filtered(buckets: {hexChild.toUpperCase()}), hasLength(1));
      expect(items.total(buckets: {hexChild.toUpperCase()}), money(60));
    });

    test('a mixed-case bucket set keeps matching the null bucket', () {
      final ledger = LedgerState();
      ledger.addAccount(account(hexSource));
      ledger.addCategory(category(hexChild));
      ledger.addEntry(
        entry(amount: money(-60), categoryID: hexChild, sourceID: hexSource),
      );
      ledger.addEntry(entry(amount: money(-15), sourceID: hexSource));

      final items = Accounting.analysisItems(
        ledger,
      ).filtered(kind: CategoryKind.expense);

      expect(items.total(buckets: {hexChild.toUpperCase(), null}), money(75));
    });
  });

  group('fraction', () {
    test('divides the amount by the total', () {
      expect(Accounting.fraction(money(25), money(100)), 0.25);
    });

    test('a zero or negative total yields zero rather than dividing', () {
      expect(Accounting.fraction(money(25), Decimal.zero), 0.0);
      expect(Accounting.fraction(money(25), money(-100)), 0.0);
    });

    test('a ratio that overflows double stays finite', () {
      final huge = Decimal.parse('1${'0' * 400}');

      expect(Accounting.fraction(huge, Decimal.one), 1.0);
      expect(Accounting.fraction(-huge, Decimal.one), -1.0);
    });

    test('a ratio that underflows double stays finite', () {
      final huge = Decimal.parse('1${'0' * 400}');

      expect(Accounting.fraction(Decimal.one, huge), 0.0);
    });
  });

  group('half-open window filtering', () {
    // The boundary instant belongs to the later window only. A closed interval
    // would count it in both.
    final march = DateTime.utc(2026, 3);
    final april = DateTime.utc(2026, 4);
    final may = DateTime.utc(2026, 5);

    final onBoundary = AnalysisItem(
      bucketID: null,
      amount: money(100),
      date: april,
      kind: CategoryKind.expense,
    );
    final items = [onBoundary];

    test(
      'an item on the shared instant is excluded from the earlier window',
      () {
        expect(items.filtered(interval: DateRange(march, april)), isEmpty);
        expect(items.total(interval: DateRange(march, april)), Decimal.zero);
      },
    );

    test('an item on the shared instant is included in the later window', () {
      expect(items.filtered(interval: DateRange(april, may)), [onBoundary]);
      expect(items.total(interval: DateRange(april, may)), money(100));
    });

    test('adjacent windows never double-count the boundary item', () {
      final earlier = items.total(interval: DateRange(march, april));
      final later = items.total(interval: DateRange(april, may));

      expect(earlier + later, money(100));
    });

    test('an item strictly inside the window is included', () {
      final inside = AnalysisItem(
        bucketID: null,
        amount: money(7),
        date: DateTime.utc(2026, 4, 15),
        kind: CategoryKind.expense,
      );

      expect([inside].total(interval: DateRange(april, may)), money(7));
    });
  });

  group('AnalysisItem value equality', () {
    final when = DateTime.utc(2026, 3, 4);

    test('holds by field', () {
      expect(
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ),
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ),
      );
      expect(
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ).hashCode,
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ).hashCode,
      );
      expect(
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ),
        isNot(
          AnalysisItem(
            bucketID: cat,
            amount: money(10),
            date: when,
            kind: CategoryKind.income,
          ),
        ),
      );
      expect(
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ),
        isNot(
          AnalysisItem(
            bucketID: null,
            amount: money(10),
            date: when,
            kind: CategoryKind.expense,
          ),
        ),
      );
      expect(
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ),
        isNot(
          AnalysisItem(
            bucketID: cat,
            amount: money(11),
            date: when,
            kind: CategoryKind.expense,
          ),
        ),
      );
      expect(
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ),
        isNot(
          AnalysisItem(
            bucketID: cat,
            amount: money(10),
            date: DateTime.utc(2026, 3, 5),
            kind: CategoryKind.expense,
          ),
        ),
      );
    });

    test('hashCode separates items differing in only amount or only date', () {
      expect(
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ).hashCode,
        isNot(
          AnalysisItem(
            bucketID: cat,
            amount: money(11),
            date: when,
            kind: CategoryKind.expense,
          ).hashCode,
        ),
      );
      expect(
        AnalysisItem(
          bucketID: cat,
          amount: money(10),
          date: when,
          kind: CategoryKind.expense,
        ).hashCode,
        isNot(
          AnalysisItem(
            bucketID: cat,
            amount: money(10),
            date: DateTime.utc(2026, 3, 5),
            kind: CategoryKind.expense,
          ).hashCode,
        ),
      );
    });
  });

  group('CategoryResolution value equality', () {
    test('holds by case and id', () {
      expect(const Uncategorized(), const Uncategorized());
      expect(const Excluded(), const Excluded());
      expect(const Excluded(), isNot(const Uncategorized()));
      expect(InCategory(cat), InCategory(cat));
      expect(InCategory(cat), isNot(InCategory(parent)));
      expect(InCategory(cat).hashCode, InCategory(cat).hashCode);
    });

    // Dart dispatches == on the left operand, so each case needs its own
    // inequality asserted from the left to exercise its own operator.
    test('each case rejects the others from the left', () {
      expect(const Excluded(), isNot(const Uncategorized()));
      expect(const Excluded(), isNot(InCategory(cat)));
      expect(const Uncategorized(), isNot(const Excluded()));
      expect(const Uncategorized(), isNot(InCategory(cat)));
      expect(InCategory(cat), isNot(const Excluded()));
      expect(InCategory(cat), isNot(const Uncategorized()));
    });

    test('InCategory hashCode separates different ids', () {
      expect(InCategory(cat).hashCode, isNot(InCategory(parent).hashCode));
    });

    test('InCategory normalizes its id', () {
      const upper = '6F1A2B3C-4D5E-6F70-8192-A3B4C5D6E7F8';
      const lower = '6f1a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8';

      expect(InCategory(upper).id, lower);
      expect(InCategory(upper), InCategory(lower));
    });
  });

  group('returned collections are unmodifiable', () {
    LedgerState seeded() {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addCategory(category(parent));
      ledger.addCategory(category(child, parent: parent));
      ledger.addEntry(
        entry(amount: money(-30), categoryID: parent, sourceID: a),
      );
      ledger.addEntry(
        entry(amount: money(-70), categoryID: child, sourceID: a),
      );
      return ledger;
    }

    final spare = AnalysisItem(
      bucketID: null,
      amount: money(1),
      date: DateTime.utc(2026, 4),
      kind: CategoryKind.expense,
    );

    test('analysisItems rejects add, remove, sort and clear', () {
      final items = Accounting.analysisItems(seeded());

      expect(() => items.add(spare), throwsUnsupportedError);
      expect(() => items.removeAt(0), throwsUnsupportedError);
      expect(() => items[0] = spare, throwsUnsupportedError);
      expect(() => items.sort((x, y) => 0), throwsUnsupportedError);
      expect(items.clear, throwsUnsupportedError);
    });

    test('filtered rejects mutation', () {
      final items = Accounting.analysisItems(
        seeded(),
      ).filtered(kind: CategoryKind.expense);

      expect(() => items.add(spare), throwsUnsupportedError);
      expect(() => items[0] = spare, throwsUnsupportedError);
      expect(items.clear, throwsUnsupportedError);
    });

    test('rollUp rejects mutation', () {
      final ledger = seeded();
      final sums = Accounting.rollUp(
        Accounting.analysisItems(ledger).filtered(kind: CategoryKind.expense),
        ledger,
      );

      expect(() => sums[parent] = money(1), throwsUnsupportedError);
      expect(() => sums.remove(parent), throwsUnsupportedError);
      expect(sums.clear, throwsUnsupportedError);
    });

    test('a filtered result still filters and totals', () {
      final ledger = seeded();
      final items = Accounting.analysisItems(
        ledger,
      ).filtered(kind: CategoryKind.expense);

      expect(items.filtered(buckets: {child}), hasLength(1));
      expect(items.filtered(buckets: {child}).total(), money(70));
      expect(items.total(buckets: {parent, child}), money(100));
      expect(Accounting.rollUp(items.filtered(buckets: {child}), ledger), {
        parent: money(70),
      });
    });

    test('a rollUp result is independent of the list it was built from', () {
      final ledger = seeded();
      final items = Accounting.analysisItems(ledger).toList();
      final sums = Accounting.rollUp(items, ledger);

      items.clear();

      expect(sums, {parent: money(100)});
    });
  });
}
