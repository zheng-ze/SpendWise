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

    test('a transfer into a treat-as-expense holder produces an item', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addAccount(account(b, incomingTransfersAsExpenses: true));
      ledger.addEntry(entry(amount: money(300), sourceID: a, destinationID: b));

      final items = expenseItems(ledger);

      expect(items, hasLength(1));
      expect(items.first.amount, money(300));
      expect(items.first.bucketID, isNull);
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

  group('fraction', () {
    test('divides the amount by the total', () {
      expect(Accounting.fraction(money(25), money(100)), 0.25);
    });

    test('a zero or negative total yields zero rather than dividing', () {
      expect(Accounting.fraction(money(25), Decimal.zero), 0.0);
      expect(Accounting.fraction(money(25), money(-100)), 0.0);
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

    test('InCategory canonicalizes its id', () {
      expect(InCategory(cat.toUpperCase()).id, cat);
    });
  });
}
