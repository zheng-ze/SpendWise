import 'dart:async';

import 'package:domain/domain.dart';
import 'package:spendwise/persistence/ledger_store.dart';

/// Ingest is queued in arrival order and applied only by [flushNow], standing
/// in for the real store's debounce window. That makes a missing flush visible
/// to a test rather than hidden by an eager apply.
class InMemoryLedgerStore implements LedgerStore {
  InMemoryLedgerStore({LedgerState? state, bool hasSeeded = false})
    : _state = state ?? LedgerState(),
      _seeded = hasSeeded;

  LedgerState _state;

  bool _seeded;

  LedgerState get state => _state;

  bool get hasSeeded => _seeded;

  final List<List<LedgerChange>> _pending = [];

  final List<List<LedgerChange>> _enqueued = [];

  bool _started = false;

  bool get isStarted => _started;

  SaveErrorHandler? errorHandler;

  /// Batch boundaries stay intact, so a test can tell what the processor
  /// forwarded apart from what the store ended up holding.
  List<List<LedgerChange>> get enqueuedBatches =>
      List.unmodifiable(_enqueued.map(List<LedgerChange>.unmodifiable));

  @override
  Future<LedgerState> load() async => _state;

  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) async {
    if (_seeded) return;

    // Set before enqueueing, so a crash mid-seed leaves a partial seed rather
    // than seeding twice on the next launch.
    _seeded = true;
    enqueue(changes);
    await flushNow();
  }

  @override
  Future<void> start() async {
    _started = true;
  }

  @override
  void enqueue(List<LedgerChange> changes) {
    if (changes.isEmpty) return;
    _enqueued.add(List<LedgerChange>.of(changes));
    _pending.add(List<LedgerChange>.of(changes));
  }

  @override
  Future<void> flushNow() async {
    await start();
    _drain();
  }

  @override
  Future<void> setErrorHandler(SaveErrorHandler handler) async {
    errorHandler = handler;
  }

  void _drain() {
    if (_pending.isEmpty) return;

    final sources = Map<String, MoneySource>.of(_state.moneySources);
    final entries = Map<String, Entry>.of(_state.entries);
    final categories = Map<String, TransactionCategory>.of(_state.categories);
    final plans = Map<String, RecurringPlan>.of(_state.plans);

    for (final batch in _pending) {
      for (final change in batch) {
        _apply(change, sources, entries, categories, plans);
      }
    }
    _pending.clear();

    _state = LedgerState(
      moneySources: sources,
      entries: entries,
      categories: categories,
      plans: plans,
    );
  }

  /// Mirrors the replay a real store performs when rebuilding state from the
  /// change log. The domain has no replay of its own to call.
  void _apply(
    LedgerChange change,
    Map<String, MoneySource> sources,
    Map<String, Entry> entries,
    Map<String, TransactionCategory> categories,
    Map<String, RecurringPlan> plans,
  ) {
    switch (change) {
      case UpsertAccount(:final account):
        sources[account.id] = MoneySource.account(account);
      case UpsertPocket(:final pocket):
        sources[pocket.id] = MoneySource.pocket(pocket);
      case UpsertCategory(:final category):
        categories[category.id] = category;
      case UpsertEntry(:final entry):
        entries[entry.id] = entry;
      case UpsertPlan(:final plan):
        plans[plan.id] = plan;
      case DeleteMoneySource(:final id):
        sources.remove(id);
      case DeleteCategory(:final id):
        categories.remove(id);
      case DeleteEntry(:final id):
        entries.remove(id);
      case DeletePlan(:final id):
        plans.remove(id);
    }
  }
}
