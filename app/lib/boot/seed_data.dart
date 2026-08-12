import 'package:domain/domain.dart';

typedef IdFactory = String Function();

List<LedgerChange> seedChanges({DateTime? today, IdFactory? newID}) =>
    buildSeed(LedgerState(), today: today, newID: newID);

List<LedgerChange> buildSeed(
  LedgerState state, {
  DateTime? today,
  IdFactory? newID,
}) {
  final builder = _SeedBuilder(
    state: state,
    today: startOfDayUtc(today ?? DateTime.now()),
    newID: newID ?? _uniqueID,
  );
  builder.build();
  return _serialize(state);
}

/// Reads the final state rather than collecting the mutator returns, so a
/// cascade that rewrote an earlier row is serialized as its settled version.
List<LedgerChange> _serialize(LedgerState state) => <LedgerChange>[
  ...state.moneySources.values.map(LedgerChange.upsertSource),
  ...state.categories.values.map(UpsertCategory.new),
  ...state.entries.values.map(UpsertEntry.new),
  ...state.plans.values.map(UpsertPlan.new),
];

String _uniqueID() => newID();

class _SeedBuilder {
  _SeedBuilder({required this.state, required this.today, required this.newID});

  final LedgerState state;
  final DateTime today;
  final IdFactory newID;

  DateTime _day(int offset) => startOfDayUtc(today.add(Duration(days: offset)));

  DateTime _month(int offset, {required int day}) =>
      shiftMonthThenClampDayUtc(today, offset, day: day);

  void build() {
    final checking = _account('DBS Checking', AccountType.checking);
    final savings = _account('OCBC Savings', AccountType.savings);
    final card = _account('Amex Card', AccountType.card, statementDay: 15);

    final emergency = _pocket('Emergency Fund', savings);
    final holiday = _pocket('Holiday', savings);

    final openingDate = _month(-2, day: 1);
    _opening(5000, checking, openingDate);
    _opening(1200, savings, openingDate);
    _opening(8000, emergency, openingDate);
    _opening(650, holiday, openingDate);

    final groceries = _category('Groceries', '#34C759', 'cart');
    final dining = _category('Dining', '#FF9500', 'fork.knife');
    final transport = _category('Transport', '#5856D6', 'tram.fill');
    final salary = _category(
      'Salary',
      '#007AFF',
      'dollarsign.circle',
      kind: CategoryKind.income,
    );
    final supermarket = _category(
      'Supermarket',
      '#30D158',
      'cart.fill',
      parentID: groceries,
    );
    final freshMarket = _category(
      'Fresh Market',
      '#63E6BE',
      'carrot.fill',
      parentID: groceries,
    );

    _entry(_day(0), '3200', 'Monthly salary', salary, checking);
    _entry(_day(0), '-42.50', 'FairPrice groceries', supermarket, card);
    _entry(_day(0), '-3.20', 'MRT to work', transport, card);
    _entry(_day(0), '500', 'To savings', null, checking, destination: savings);
    _entry(_day(-1), '-28.90', 'Dinner with friends', dining, card);
    _entry(_day(-1), '-18.60', 'Tekka wet market', freshMarket, checking);
    _entry(_day(-1), '-12.40', 'Cold Storage', groceries, checking);
    _entry(_day(-2), '-6.80', 'Grab home', transport, card);
    _entry(_day(-2), '-55.00', 'Lunch at Maxwell', dining, card);

    _entry(_month(-1, day: 25), '3200', 'Monthly salary', salary, checking);
    _entry(_month(-1, day: 18), '-74.20', 'Weekly groceries', groceries, card);
    _entry(_month(-1, day: 12), '-18.00', 'Grab to airport', transport, card);
    _entry(_month(-1, day: 5), '-96.50', 'Birthday dinner', dining, card);

    _entry(_month(1, day: 3), '-1200', 'Rent', null, checking);
    _entry(_month(1, day: 8), '-33.40', 'Cold Storage', groceries, card);

    _plan('-19.98', 'Netflix', dining, card, _month(0, day: 20));
    _plan('3200', 'Monthly salary', salary, checking, _month(0, day: 25));
  }

  String _account(String name, AccountType type, {int? statementDay}) {
    final account = Account(
      id: newID(),
      name: name,
      type: type,
      statementDay: statementDay,
    );
    state.addAccount(account);
    return account.id;
  }

  String _pocket(String name, String accountID) {
    final pocket = SubPocket(id: newID(), name: name);
    state.addPocket(pocket, accountID);
    return pocket.id;
  }

  void _opening(int amount, String holderID, DateTime date) {
    state.setOpeningBalance(Decimal.fromInt(amount), holderID, date: date);
  }

  String _category(
    String name,
    String colorHex,
    String symbol, {
    CategoryKind kind = CategoryKind.expense,
    String? parentID,
  }) {
    final category = TransactionCategory(
      id: newID(),
      name: name,
      kind: kind,
      colorHex: colorHex,
      includeInAnalysis: true,
      parentID: parentID,
      symbol: symbol,
    );
    state.addCategory(category);
    return category.id;
  }

  void _entry(
    DateTime date,
    String amount,
    String name,
    String? categoryID,
    String sourceID, {
    String? destination,
  }) {
    state.addEntry(
      Entry(
        id: newID(),
        date: date,
        amount: Decimal.parse(amount),
        name: name,
        categoryID: categoryID,
        sourceID: sourceID,
        destinationID: destination,
      ),
    );
  }

  /// `lastResolvedDate` sits on the anchor so the first resolve after boot has
  /// nothing to backfill.
  void _plan(
    String amount,
    String name,
    String categoryID,
    String sourceID,
    DateTime anchor,
  ) {
    state.addPlan(
      RecurringPlan(
        id: newID(),
        template: EntryTemplate(
          amount: Decimal.parse(amount),
          name: name,
          categoryID: categoryID,
          sourceID: sourceID,
        ),
        frequency: RecurrenceFrequency.monthly,
        anchor: anchor,
        lastResolvedDate: anchor,
      ),
    );
  }
}
