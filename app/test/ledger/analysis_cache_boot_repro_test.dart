import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';

LedgerState _realisticState() {
  final state = LedgerState();

  final account = Account(name: 'wallet', type: AccountType.savings);
  state.addAccount(account);

  final pocket = SubPocket(name: 'sub');
  state.addPocket(pocket, account.id);

  final expenseCategory = TransactionCategory(
    name: 'food',
    kind: CategoryKind.expense,
    colorHex: '#00FF00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
  );
  state.addCategory(expenseCategory);

  final incomeCategory = TransactionCategory(
    name: 'salary',
    kind: CategoryKind.income,
    colorHex: '#0000FF',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
  );
  state.addCategory(incomeCategory);

  for (var i = 0; i < 20; i++) {
    final isExpense = i.isEven;
    state.addEntry(
      Entry(
        amount: Decimal.parse(isExpense ? '-12.50' : '30.00'),
        name: 'entry $i',
        sourceID: account.id,
        categoryID: isExpense ? expenseCategory.id : incomeCategory.id,
        date: DateTime.utc(2026, (i % 12) + 1, 15),
      ),
    );
  }

  return state;
}

void main() {
  test(
    'cacheProducesItemsAfterBootLikeSequenceWithRealIsolateRunner',
    () async {
      final bus = EventBus();
      final state = _realisticState();
      final ledger = Ledger(state: state, bus: bus);

      final cache = AnalysisCache();
      cache.start(bus);

      // Mirrors AppBoot.start: resolvePlans runs right after Ready, with no
      // plans due it publishes nothing, so this should be a no-op on revision.
      ledger.resolvePlans(DateTime.now().toUtc());

      // Mirrors StatsScreen.build calling refresh() on the first frame, then
      // again on a follow-up rebuild before the isolate compute has settled.
      cache.refresh(ledger.state);
      cache.refresh(ledger.state);

      await Future<void>.delayed(const Duration(seconds: 2));

      cache.refresh(ledger.state);

      await Future<void>.delayed(const Duration(seconds: 2));

      expect(cache.items, isNotEmpty);
      expect(cache.itemsRevision, greaterThan(0));
    },
  );
}
